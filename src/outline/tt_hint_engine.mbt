// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// TrueType bytecode interpreter (work-in-progress port).
///
/// This is being incrementally ported from `fontations/skrifa`:
/// `src/outline/glyf/hint/engine/*` (Apache-2.0 OR MIT).

///|
/// Maximum number of executed instructions in a single run.
const TT_MAX_RUN_INSTRUCTIONS : Int = 1_000_000

///|
/// Maximum number of bytes in a function/instruction definition.
///
/// This matches upstream's `u16::MAX` limit, and is only enforced in pedantic
/// mode.
const TT_MAX_DEFINITION_SIZE : Int = 0xFFFF

///|
/// Tracks budgets for loops to limit execution time.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/engine/mod.rs`.
priv struct TtLoopBudget {
  limit : Int
  mut backward_jumps : Int
  mut loop_calls : Int
}

///|
fn TtLoopBudget::new(cvt_len : Int, point_count : Int?) -> TtLoopBudget {
  // Compute limits for loop calls and backward jumps.
  // See FreeType's ttinterp.c "neg_jump_counter_max/loopcall_counter_max".
  let limit = match point_count {
    Some(n) =>
      // (point_count * 10).max(50) + (cvt_len / 10).max(50)
      (n * 10).max(50) + (cvt_len / 10).max(50)
    None =>
      // 300 + 22 * cvt_len
      300 + 22 * cvt_len
  }
  TtLoopBudget::{ limit, backward_jumps: 0, loop_calls: 0 }
}

///|
fn TtLoopBudget::reset(self : TtLoopBudget) -> Unit {
  self.backward_jumps = 0
  self.loop_calls = 0
}

///|
fn TtLoopBudget::doing_backward_jump(
  self : TtLoopBudget,
) -> Result[Unit, HintError] {
  self.backward_jumps = self.backward_jumps + 1
  if self.backward_jumps > self.limit {
    Err(HintError::ExceededExecutionBudget)
  } else {
    Ok(())
  }
}

///|
fn TtLoopBudget::doing_loop_call(
  self : TtLoopBudget,
  count : Int,
) -> Result[Unit, HintError] {
  self.loop_calls = self.loop_calls + count
  if self.loop_calls > self.limit {
    Err(HintError::ExceededExecutionBudget)
  } else {
    Ok(())
  }
}

///|
priv struct TtEngine {
  program : TtProgramState
  value_stack : TtValueStack
  mut functions : TtDefinitionSet
  mut instructions : TtDefinitionSet
  graphics : TtGraphicsState
  cvt : Array[Int]
  storage : Array[Int]
  loop_budget : TtLoopBudget
  axis_count : Int
  coords : ArrayView[@moon_skrifa.NormalizedCoord]
}

///|
fn TtEngine::new(
  font_code : BytesView,
  prep_code : BytesView,
  glyph_code : BytesView,
  retained : TtRetainedGraphicsState,
  cvt : Array[Int],
  storage : Array[Int],
  point_count : Int?,
  axis_count : Int,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  max_stack : Int,
  max_call_depth : Int,
  max_function_defs : Int,
  max_instruction_defs : Int,
) -> TtEngine {
  let stack_buf = Array::make(max_stack, 0)
  let graphics = TtGraphicsState::default()
  graphics.retained = retained
  graphics.update_projection_state()
  let loop_budget = TtLoopBudget::new(cvt.length(), point_count)
  TtEngine::{
    program: TtProgramState::new(
      font_code,
      prep_code,
      glyph_code,
      TtProgram::Font,
      max_call_depth,
    ),
    value_stack: TtValueStack::new(stack_buf, true),
    functions: TtDefinitionSet::new(max_function_defs),
    instructions: TtDefinitionSet::new(max_instruction_defs),
    graphics,
    cvt,
    storage,
    loop_budget,
    axis_count,
    coords,
  }
}

///|
fn TtEngine::reset(
  self : TtEngine,
  program : TtProgram,
  is_pedantic : Bool,
) -> Unit {
  self.program.reset(program)
  self.value_stack.clear()
  // Match fontations: stack under/overflow is only an error in pedantic mode.
  self.value_stack.check = is_pedantic
  self.graphics.reset()
  self.graphics.is_pedantic = is_pedantic
  self.loop_budget.reset()
  match program {
    TtProgram::Font => {
      self.functions.reset()
      self.instructions.reset()
    }
    TtProgram::ControlValue => self.graphics.backward_compatibility = false
    TtProgram::Glyph => {
      // Instruct control bit 1 says we reset retained graphics state to default.
      if (self.graphics.retained.instruct_control & 2) != 0 {
        self.graphics.reset_retained()
      }
      // Set backward compatibility mode.
      if self.graphics.retained.target.preserve_linear_metrics() {
        self.graphics.backward_compatibility = true
      } else if self.graphics.retained.target.is_smooth() {
        self.graphics.backward_compatibility = (
            self.graphics.retained.instruct_control & 0x4
          ) ==
          0
      } else {
        self.graphics.backward_compatibility = false
      }
    }
  }
}

///|
fn TtEngine::run_program(
  self : TtEngine,
  program : TtProgram,
  is_pedantic : Bool,
) -> Result[Unit, HintError] {
  self.reset(program, is_pedantic)
  self.run()
}

///|
fn TtEngine::run(self : TtEngine) -> Result[Unit, HintError] {
  let mut count = 0
  while true {
    let ins0 = match self.program.decoder.decode() {
      Err(e) => return Err(e)
      Ok(None) =>
        if self.program.call_stack.is_empty() {
          break
        } else {
          // Implicit return at end-of-code.
          match self.program.pop_frame() {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
          continue
        }
      Ok(Some(ins)) => ins
    }
    match self.dispatch(ins0) {
      Ok(_) => ()
      Err(e) => {
        if e is HintError::ValueStackUnderflow {
          let tag = match self.program.current {
            TtProgram::Font => "fpgm"
            TtProgram::ControlValue => "prep"
            TtProgram::Glyph => "glyf"
          }
          println(
            "tt_hint underflow tag=" +
            tag +
            " pc=" +
            ins0.pc.to_string() +
            " op=0x" +
            ins0.opcode.to_string(radix=16) +
            " stack_len=" +
            self.value_stack.length().to_string(),
          )
        }
        return Err(e)
      }
    }
    count = count + 1
    if count > TT_MAX_RUN_INSTRUCTIONS {
      return Err(HintError::ExceededExecutionBudget)
    }
  }
  Ok(())
}

///|
fn TtEngine::op_unknown(
  self : TtEngine,
  op : Int,
  pc : Int,
) -> Result[Unit, HintError] {
  match self.instructions.get(op) {
    None => Err(HintError::UnhandledOpcode(op, pc))
    Some(d) =>
      match d.slice() {
        None => Err(HintError::InvalidDefinition(op))
        Some(code) => {
          let return_pc = self.program.decoder.pc
          self.program.push_frame(code, 0, return_pc)
        }
      }
  }
}

///|
fn TtEngine::dispatch(
  self : TtEngine,
  ins : TtInstruction,
) -> Result[Unit, HintError] {
  let op = ins.opcode
  // Push instructions.
  if (op >= 0xB0 && op <= 0xBF) || op == 0x40 || op == 0x41 {
    for v in ins.inline_operands.iter() {
      match self.value_stack.push(v) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    return Ok(())
  }
  // MIRP/MDRP ranges (FreeType style).
  if op >= 0xE0 {
    return self.op_mirp(op)
  }
  if op >= 0xC0 && op <= 0xDF {
    return self.op_mdrp(op)
  }
  match op {
    // SVTCA/SPVTCA/SFVTCA
    0x00 => self.op_svtca(op)
    0x01 => self.op_svtca(op)
    0x02 => self.op_svtca(op)
    0x03 => self.op_svtca(op)
    0x04 => self.op_svtca(op)
    0x05 => self.op_svtca(op)
    // SPVTL/SFVTL
    0x06 => self.op_svtl(op)
    0x07 => self.op_svtl(op)
    0x08 => self.op_svtl(op)
    0x09 => self.op_svtl(op)
    // SPVFS/SFVFS/GPV/GFV
    0x0A => self.op_spvfs()
    0x0B => self.op_sfvfs()
    0x0C => self.op_gpv()
    0x0D => self.op_gfv()
    // SFVTPV/ISECT
    0x0E => self.op_sfvtpv()
    0x0F => self.op_isect()
    // SRP0/SRP1/SRP2
    0x10 => self.op_srp0()
    0x11 => self.op_srp1()
    0x12 => self.op_srp2()
    // SZP0/SZP1/SZP2/SZPS
    0x13 => self.op_szp0()
    0x14 => self.op_szp1()
    0x15 => self.op_szp2()
    0x16 => self.op_szps()
    // SLOOP
    0x17 => self.op_sloop()
    // RTG/RTHG
    0x18 => self.op_rtg()
    0x19 => self.op_rthg()
    // SMD
    0x1A => self.op_smd()
    // FDEF
    0x2C => self.op_fdef(ins.pc)
    // ENDF
    0x2D => self.op_endf(ins.pc)
    // CALL
    0x2B => self.op_call(ins.pc)
    // LOOPCALL
    0x2A => self.op_loopcall(ins.pc)
    // IDEF
    0x89 => self.op_idef(ins.pc)
    // SCVTCI
    0x1D => self.op_scvtci()
    // SSWCI/SSW
    0x1E => self.op_sswci()
    0x1F => self.op_ssw()
    // DUP
    0x20 => self.op_dup()
    // POP
    0x21 => {
      match self.value_stack.pop() {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      Ok(())
    }
    // SWAP
    0x23 => self.op_swap()
    // CLEAR
    0x22 => {
      self.value_stack.clear()
      Ok(())
    }
    // DEPTH
    0x24 => {
      match self.value_stack.push(self.value_stack.length()) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      Ok(())
    }
    // CINDEX
    0x25 => self.op_cindex()
    // MINDEX
    0x26 => self.op_mindex()
    // ALIGNPTS
    0x27 => self.op_alignpts()
    // UTP
    0x29 => self.op_utp()
    // MDAP
    0x2E => self.op_mdap(op)
    0x2F => self.op_mdap(op)
    // IUP
    0x30 => self.op_iup(op)
    0x31 => self.op_iup(op)
    // SHP
    0x32 => self.op_shp(op)
    0x33 => self.op_shp(op)
    // SHC
    0x34 => self.op_shc(op)
    0x35 => self.op_shc(op)
    // SHZ
    0x36 => self.op_shz(op)
    0x37 => self.op_shz(op)
    // SHPIX
    0x38 => self.op_shpix()
    // IP
    0x39 => self.op_ip()
    // MSIRP
    0x3A => self.op_msirp(op)
    0x3B => self.op_msirp(op)
    // ALIGNRP
    0x3C => self.op_alignrp()
    // RTDG
    0x3D => self.op_rtdg()
    // MIAP
    0x3E => self.op_miap(op)
    0x3F => self.op_miap(op)
    // WS/RS/WCVTP/RCVT/GC/SCFS/MD
    0x42 => self.op_ws()
    0x43 => self.op_rs()
    0x44 => self.op_wcvtp()
    0x45 => self.op_rcvt()
    0x46 => self.op_gc(op)
    0x47 => self.op_gc(op)
    0x48 => self.op_scfs()
    0x49 => self.op_md(op)
    0x4A => self.op_md(op)
    // MPS
    0x4C => self.op_mps()
    // FLIPON/FLIPOFF
    0x4D => self.op_flipon()
    0x4E => self.op_flipoff()
    // DEBUG
    0x4F =>
      match self.value_stack.pop() {
        Err(e) => Err(e)
        Ok(_) => Ok(())
      }
    // ROLL
    0x8A => self.op_roll()
    // ADD
    0x60 => self.op_add()
    // SUB
    0x61 => self.op_sub()
    // MUL
    0x63 => self.op_mul()
    // DIV
    0x62 => self.op_div()
    // NEG
    0x65 => self.op_neg()
    // ABS
    0x64 => self.op_abs()
    // FLOOR/CEILING/ROUND
    0x66 => self.op_floor()
    0x67 => self.op_ceiling()
    0x68 => self.op_round()
    0x69 => self.op_round()
    0x6A => self.op_round()
    0x6B => self.op_round()
    0x6C => Ok(())
    0x6D => Ok(())
    0x6E => Ok(())
    0x6F => Ok(())
    // WCVTF
    0x70 => self.op_wcvtf()
    // DELTAP2/3
    0x71 => self.op_deltap(op)
    0x72 => self.op_deltap(op)
    // DELTAC1/2/3
    0x73 => self.op_deltac(op)
    0x74 => self.op_deltac(op)
    0x75 => self.op_deltac(op)
    // SROUND/S45ROUND
    0x76 => self.op_sround()
    0x77 => self.op_s45round()
    // ROFF/RUTG/RDTG
    0x7A => self.op_roff()
    0x7C => self.op_rutg()
    0x7D => self.op_rdtg()
    // SANGW/AA/FLIP*
    0x7E => self.op_sangw()
    0x7F => Ok(())
    0x80 => self.op_flippt()
    0x81 => self.op_fliprgon()
    0x82 => self.op_fliprgoff()
    // SCANCTRL/SDPVTL/GETINFO/MAX/MIN/SCANTYPE/INSTCTRL
    0x85 => self.op_scanctrl()
    0x86 => self.op_sdpvtl(op)
    0x87 => self.op_sdpvtl(op)
    0x88 => self.op_getinfo()
    0x8B => self.op_max()
    0x8C => self.op_min()
    0x8D => self.op_scantype()
    0x8E => self.op_instctrl()
    0x91 => self.op_getvariation(ins.pc)
    0x92 => self.op_getdata(ins.pc)
    // IF
    0x58 => self.op_if()
    // ELSE
    0x1B => self.op_else(ins.pc)
    // EIF
    0x59 => self.op_eif(ins.pc)
    // JMPR
    0x1C => self.op_jmpr(ins.pc)
    // JROT
    0x78 => self.op_jrot(ins.pc)
    // JROF
    0x79 => self.op_jrof(ins.pc)
    // AND/OR/NOT + DELTAP1/SDB/SDS
    0x5A => self.op_and()
    0x5B => self.op_or()
    0x5C => self.op_not()
    0x5D => self.op_deltap(op)
    0x5E => self.op_sdb()
    0x5F => self.op_sds()
    // MPPEM
    0x4B => self.op_mppem()
    // LT/LTEQ/GT/GTEQ/EQ/NEQ
    0x50 => self.op_cmp_lt()
    0x51 => self.op_cmp_lteq()
    0x52 => self.op_cmp_gt()
    0x53 => self.op_cmp_gteq()
    0x54 => self.op_cmp_eq()
    0x55 => self.op_cmp_neq()
    0x56 => self.op_odd()
    0x57 => self.op_even()
    _ => self.op_unknown(op, ins.pc)
  }
}

///|
fn TtEngine::op_mppem(self : TtEngine) -> Result[Unit, HintError] {
  self.value_stack.push(self.graphics.retained.ppem)
}

///|
fn tt_bool_i32(v : Bool) -> Int {
  if v {
    1
  } else {
    0
  }
}

///|
fn TtEngine::op_cmp_lt(self : TtEngine) -> Result[Unit, HintError] {
  let e2 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let e1 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_bool_i32(e1 < e2))
}

///|
fn TtEngine::op_cmp_lteq(self : TtEngine) -> Result[Unit, HintError] {
  let e2 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let e1 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_bool_i32(e1 <= e2))
}

///|
fn TtEngine::op_cmp_gt(self : TtEngine) -> Result[Unit, HintError] {
  let e2 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let e1 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_bool_i32(e1 > e2))
}

///|
fn TtEngine::op_cmp_gteq(self : TtEngine) -> Result[Unit, HintError] {
  let e2 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let e1 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_bool_i32(e1 >= e2))
}

///|
fn TtEngine::op_cmp_eq(self : TtEngine) -> Result[Unit, HintError] {
  let e2 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let e1 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_bool_i32(e1 == e2))
}

///|
fn TtEngine::op_cmp_neq(self : TtEngine) -> Result[Unit, HintError] {
  let e2 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let e1 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_bool_i32(e1 != e2))
}

///|
fn TtEngine::op_dup(self : TtEngine) -> Result[Unit, HintError] {
  match self.value_stack.peek(0) {
    Ok(v) => self.value_stack.push(v)
    Err(HintError::ValueStackUnderflow) =>
      if self.value_stack.check {
        Err(HintError::ValueStackUnderflow)
      } else {
        self.value_stack.push(0)
      }
    Err(e) => Err(e)
  }
}

///|
fn TtEngine::op_swap(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  match self.value_stack.push(a) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.value_stack.push(b)
}

///|
fn TtEngine::op_cindex(self : TtEngine) -> Result[Unit, HintError] {
  // Match fontations/FreeType: use the top element as an index without popping.
  // Index 0 is valid and is a no-op.
  let top = self.value_stack.length()
  if top <= 0 {
    return Err(HintError::ValueStackUnderflow)
  }
  let top_ix = top - 1
  let idx = self.value_stack.buf.at(top_ix)
  if idx < 0 {
    return Err(HintError::ValueStackUnderflow)
  }
  let element_ix = top_ix - idx
  if element_ix < 0 {
    return Err(HintError::ValueStackUnderflow)
  }
  self.value_stack.buf.set(top_ix, self.value_stack.buf.at(element_ix))
  Ok(())
}

///|
fn TtEngine::op_mindex(self : TtEngine) -> Result[Unit, HintError] {
  // Match fontations/FreeType: use the top element as an index without popping.
  // Index 0 moves the top element to the new top, effectively dropping one slot.
  let top = self.value_stack.length()
  if top <= 0 {
    return Err(HintError::ValueStackUnderflow)
  }
  let top_ix = top - 1
  let idx = self.value_stack.buf.at(top_ix)
  if idx < 0 {
    return Err(HintError::ValueStackUnderflow)
  }
  let element_ix = top_ix - idx
  if element_ix < 0 {
    return Err(HintError::ValueStackUnderflow)
  }
  let new_top_ix = top_ix - 1
  if new_top_ix < 0 {
    return Err(HintError::ValueStackUnderflow)
  }
  let v = self.value_stack.buf.at(element_ix)
  // Remove the element by shifting values above it down (including the index slot).
  for i in element_ix..<(top - 1) {
    self.value_stack.buf.set(i, self.value_stack.buf.at(i + 1))
  }
  self.value_stack.buf.set(new_top_ix, v)
  self.value_stack.len = self.value_stack.len - 1
  Ok(())
}

///|
fn TtEngine::op_roll(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let c = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  match self.value_stack.push(b) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match self.value_stack.push(a) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.value_stack.push(c)
}

///|
fn TtEngine::op_add(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(a + b)
}

///|
fn TtEngine::op_sub(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(a - b)
}

///|
fn TtEngine::op_mul(self : TtEngine) -> Result[Unit, HintError] {
  // 26.6 * 26.6 => 26.6 (matches fontations/FreeType).
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_hint_mul_div_16_16(a, b, 64))
}

///|
fn TtEngine::op_div(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if b == 0 {
    return Err(HintError::DivideByZero)
  }
  // 26.6 / 26.6 => 26.6 (truncates rather than rounds).
  self.value_stack.push(tt_hint_mul_div_no_round(a, 64, b))
}

///|
fn TtEngine::op_neg(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(-a)
}

///|
fn TtEngine::op_abs(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(a.abs())
}

// Control flow: skip-based IF/ELSE/EIF, aligned with fontations/FreeType.

///|
fn TtEngine::op_if(self : TtEngine) -> Result[Unit, HintError] {
  let cond = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if cond != 0 {
    return Ok(())
  }
  // Condition is false: jump to next ELSE (same nesting) or EIF.
  let mut nest_depth = 1
  let mut done = false
  while !done {
    let ins = match self.program.decoder.decode() {
      Err(e) => return Err(e)
      Ok(None) => return Err(HintError::UnexpectedEndOfBytecode)
      Ok(Some(i)) => i
    }
    match ins.opcode {
      0x58 => nest_depth = nest_depth + 1 // IF
      0x1B => done = nest_depth == 1 // ELSE
      0x59 => {
        nest_depth = nest_depth - 1 // EIF
        done = nest_depth == 0
      }
      _ => ()
    }
  }
  Ok(())
}

///|
fn TtEngine::op_else(self : TtEngine, _pc : Int) -> Result[Unit, HintError] {
  // We executed the true-branch and hit ELSE: skip to matching EIF.
  let mut nest_depth = 1
  while nest_depth != 0 {
    let ins = match self.program.decoder.decode() {
      Err(e) => return Err(e)
      Ok(None) => return Err(HintError::UnexpectedEndOfBytecode)
      Ok(Some(i)) => i
    }
    match ins.opcode {
      0x58 => nest_depth = nest_depth + 1 // IF
      0x59 => nest_depth = nest_depth - 1 // EIF
      _ => ()
    }
  }
  Ok(())
}

///|
fn TtEngine::op_eif(_self : TtEngine, _pc : Int) -> Result[Unit, HintError] {
  // No-op: handled by skip logic.
  Ok(())
}

///|
fn TtEngine::op_jmpr(self : TtEngine, _pc : Int) -> Result[Unit, HintError] {
  let off = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  // Offset is relative to the JMPR instruction, but decoder.pc currently
  // points at the next instruction, so subtract one.
  let jump = off - 1
  if jump < 0 {
    if jump == -1 {
      // If the offset is -1, we'll loop in place forever.
      return Err(HintError::InvalidJump)
    }
    match self.loop_budget.doing_backward_jump() {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  // Upstream uses wrapping pc arithmetic and does not bounds-check.
  self.program.decoder.pc = self.program.decoder.pc + jump
  Ok(())
}

///|
fn TtEngine::op_jrot(self : TtEngine, pc : Int) -> Result[Unit, HintError] {
  pc |> ignore
  let cond = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let off = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if cond != 0 {
    let jump = off - 1
    if jump < 0 {
      if jump == -1 {
        return Err(HintError::InvalidJump)
      }
      match self.loop_budget.doing_backward_jump() {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    self.program.decoder.pc = self.program.decoder.pc + jump
    Ok(())
  } else {
    Ok(())
  }
}

///|
fn TtEngine::op_jrof(self : TtEngine, pc : Int) -> Result[Unit, HintError] {
  pc |> ignore
  let cond = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let off = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if cond == 0 {
    let jump = off - 1
    if jump < 0 {
      if jump == -1 {
        return Err(HintError::InvalidJump)
      }
      match self.loop_budget.doing_backward_jump() {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    self.program.decoder.pc = self.program.decoder.pc + jump
    Ok(())
  } else {
    Ok(())
  }
}

// Definitions & calls

///|
fn tt_engine_find_endf(code : BytesView, start : Int) -> Result[Int, HintError] {
  let dec = TtDecoder::{ code, pc: start }
  while true {
    let ins = match dec.decode() {
      Err(e) => return Err(e)
      Ok(None) => return Err(HintError::UnexpectedEndOfBytecode)
      Ok(Some(i)) => i
    }
    if ins.opcode == 0x2C || ins.opcode == 0x89 {
      return Err(HintError::NestedDefinition)
    } else if ins.opcode == 0x2D {
      // Return the end offset (pc after ENDF).
      return Ok(dec.pc)
    }
  }
  Err(HintError::UnexpectedEndOfBytecode)
}

///|
fn TtEngine::op_fdef(self : TtEngine, pc : Int) -> Result[Unit, HintError] {
  if self.program.current is TtProgram::Glyph {
    return Err(HintError::DefinitionInGlyphProgram)
  }
  let fn_id = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let start = self.program.decoder.pc
  let end_pc = match tt_engine_find_endf(self.program.decoder.code, start) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if self.graphics.is_pedantic && end_pc - start > TT_MAX_DEFINITION_SIZE {
    return Err(HintError::DefinitionTooLarge)
  }
  // end_pc is pc after ENDF.
  match
    self.functions.set_definition(
      fn_id,
      self.program.decoder.code,
      start,
      end_pc,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  // Skip body + ENDF opcode byte.
  self.program.decoder.pc = end_pc
  pc |> ignore
  Ok(())
}

///|
fn TtEngine::op_idef(self : TtEngine, pc : Int) -> Result[Unit, HintError] {
  if self.program.current is TtProgram::Glyph {
    return Err(HintError::DefinitionInGlyphProgram)
  }
  let opcode = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let start = self.program.decoder.pc
  let end_pc = match tt_engine_find_endf(self.program.decoder.code, start) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if self.graphics.is_pedantic && end_pc - start > TT_MAX_DEFINITION_SIZE {
    return Err(HintError::DefinitionTooLarge)
  }
  match
    self.instructions.set_definition(
      opcode,
      self.program.decoder.code,
      start,
      end_pc,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.program.decoder.pc = end_pc
  pc |> ignore
  Ok(())
}

///|
fn TtEngine::op_endf(self : TtEngine, pc : Int) -> Result[Unit, HintError] {
  // Returning from a call: pop call frame.
  pc |> ignore
  self.program.pop_frame()
}

///|
fn TtEngine::op_call(self : TtEngine, _pc : Int) -> Result[Unit, HintError] {
  let fn_id = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  match self.functions.get(fn_id) {
    None => Err(HintError::InvalidDefinition(fn_id))
    Some(d) =>
      match d.slice() {
        None => Err(HintError::InvalidDefinition(fn_id))
        Some(code) => {
          let return_pc = self.program.decoder.pc
          self.program.push_frame(code, 0, return_pc)
        }
      }
  }
}

///|
fn TtEngine::op_loopcall(self : TtEngine, _pc : Int) -> Result[Unit, HintError] {
  // Stack order: f (top), count (next).
  let fn_id = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let count = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if count <= 0 {
    return Ok(())
  }
  match self.loop_budget.doing_loop_call(count) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match self.functions.get(fn_id) {
    None => Err(HintError::InvalidDefinition(fn_id))
    Some(d) =>
      match d.slice() {
        None => Err(HintError::InvalidDefinition(fn_id))
        Some(code) => {
          let return_pc = self.program.decoder.pc
          // Execute the function `count` times; subsequent iterations are
          // resumed by the loopcall frame on return.
          self.program.push_loopcall_frame(code, count - 1, 0, return_pc)
        }
      }
  }
}
