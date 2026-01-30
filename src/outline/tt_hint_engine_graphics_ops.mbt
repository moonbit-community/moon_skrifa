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
/// Graphics state instruction implementations for the TrueType interpreter.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/engine/graphics.rs`
/// (Apache-2.0 OR MIT).

///|
fn TtEngine::op_svtca(
  self : TtEngine,
  opcode0 : Int,
) -> Result[Unit, HintError] {
  let opcode = opcode0
  let x = (opcode & 1) << 14
  let y = x ^ 0x4000
  if opcode < 4 {
    self.graphics.proj_vector = TtVec14::{ x, y }
    self.graphics.dual_proj_vector = TtVec14::{ x, y }
  }
  if (opcode & 2) == 0 {
    self.graphics.freedom_vector = TtVec14::{ x, y }
  }
  self.graphics.update_projection_state()
  Ok(())
}

///|
fn tt_line_vector(p1 : TtPoint, p2 : TtPoint, is_parallel : Bool) -> TtVec14 {
  let mut a = p1.x - p2.x
  let mut b = p1.y - p2.y
  if a == 0 && b == 0 {
    a = 0x4000
  } else if !is_parallel {
    // Counter-clockwise 90deg rotation.
    let c = b
    b = a
    a = -c
  }
  let (nx, ny) = tt_hint_normalize14(a, b)
  TtVec14::{ x: nx, y: ny }
}

///|
fn TtEngine::op_svtl(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let index1 = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let index2 = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let is_parallel = (opcode & 1) == 0
  let p1 = match self.graphics.zp1_zone().point(index2) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let p2 = match self.graphics.zp2_zone().point(index1) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let v = tt_line_vector(p1, p2, is_parallel)
  if opcode < 8 {
    self.graphics.proj_vector = v
    self.graphics.dual_proj_vector = v
  } else {
    self.graphics.freedom_vector = v
  }
  self.graphics.update_projection_state()
  Ok(())
}

///|
fn TtEngine::op_spvfs(self : TtEngine) -> Result[Unit, HintError] {
  let y0 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let x0 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let x = Int16::from_int(x0).to_int()
  let y = Int16::from_int(y0).to_int()
  let v = if x == 0 && y == 0 {
    self.graphics.proj_vector
  } else {
    let (nx, ny) = tt_hint_normalize14(x, y)
    TtVec14::{ x: nx, y: ny }
  }
  self.graphics.proj_vector = v
  self.graphics.dual_proj_vector = v
  self.graphics.update_projection_state()
  Ok(())
}

///|
fn TtEngine::op_sfvfs(self : TtEngine) -> Result[Unit, HintError] {
  let y0 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let x0 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let x = Int16::from_int(x0).to_int()
  let y = Int16::from_int(y0).to_int()
  let v = if x == 0 && y == 0 {
    self.graphics.freedom_vector
  } else {
    let (nx, ny) = tt_hint_normalize14(x, y)
    TtVec14::{ x: nx, y: ny }
  }
  self.graphics.freedom_vector = v
  self.graphics.update_projection_state()
  Ok(())
}

///|
fn TtEngine::op_gpv(self : TtEngine) -> Result[Unit, HintError] {
  let v = self.graphics.proj_vector
  match self.value_stack.push(v.x) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.value_stack.push(v.y)
}

///|
fn TtEngine::op_gfv(self : TtEngine) -> Result[Unit, HintError] {
  let v = self.graphics.freedom_vector
  match self.value_stack.push(v.x) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.value_stack.push(v.y)
}

///|
fn TtEngine::op_sfvtpv(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.freedom_vector = self.graphics.proj_vector
  self.graphics.update_projection_state()
  Ok(())
}

///|
fn TtEngine::op_srp0(self : TtEngine) -> Result[Unit, HintError] {
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.rp0 = p
  Ok(())
}

///|
fn TtEngine::op_srp1(self : TtEngine) -> Result[Unit, HintError] {
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.rp1 = p
  Ok(())
}

///|
fn TtEngine::op_srp2(self : TtEngine) -> Result[Unit, HintError] {
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.rp2 = p
  Ok(())
}

///|
fn TtEngine::op_szp0(self : TtEngine) -> Result[Unit, HintError] {
  let z = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.zp0 = match tt_zone_pointer_from_i32(z) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  Ok(())
}

///|
fn TtEngine::op_szp1(self : TtEngine) -> Result[Unit, HintError] {
  let z = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.zp1 = match tt_zone_pointer_from_i32(z) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  Ok(())
}

///|
fn TtEngine::op_szp2(self : TtEngine) -> Result[Unit, HintError] {
  let z = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.zp2 = match tt_zone_pointer_from_i32(z) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  Ok(())
}

///|
fn TtEngine::op_szps(self : TtEngine) -> Result[Unit, HintError] {
  let z = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let zp = match tt_zone_pointer_from_i32(z) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.zp0 = zp
  self.graphics.zp1 = zp
  self.graphics.zp2 = zp
  Ok(())
}

///|
fn TtEngine::op_sloop(self : TtEngine) -> Result[Unit, HintError] {
  let n = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if n < 0 {
    return Err(HintError::NegativeLoopCounter)
  }
  // Limit to 16-bit like FreeType.
  self.graphics.loop_counter = n.min(0xFFFF)
  Ok(())
}

///|
fn TtEngine::op_rtg(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.round_state.mode = TtRoundMode::Grid
  Ok(())
}

///|
fn TtEngine::op_rthg(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.round_state.mode = TtRoundMode::HalfGrid
  Ok(())
}

///|
fn TtEngine::op_rtdg(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.round_state.mode = TtRoundMode::DoubleGrid
  Ok(())
}

///|
fn TtEngine::op_rdtg(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.round_state.mode = TtRoundMode::DownToGrid
  Ok(())
}

///|
fn TtEngine::op_rutg(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.round_state.mode = TtRoundMode::UpToGrid
  Ok(())
}

///|
fn TtEngine::op_roff(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.round_state.mode = TtRoundMode::Off
  Ok(())
}

///|
fn tt_super_round(
  gs : TtGraphicsState,
  grid_period : Int,
  selector : Int,
) -> Unit {
  let state = gs.round_state
  let period = match selector & 0xC0 {
    0x00 => grid_period / 2
    0x40 => grid_period
    0x80 => grid_period * 2
    0xC0 => grid_period
    _ => state.period << 8
  }
  let phase = match selector & 0x30 {
    0x00 => 0
    0x10 => period / 4
    0x20 => period / 2
    0x30 => period * 3 / 4
    _ => state.phase << 8
  }
  let threshold = if (selector & 0x0F) == 0 {
    period - 1
  } else {
    ((selector & 0x0F) - 4) * period / 8
  }
  gs.round_state.period = period >> 8
  gs.round_state.phase = phase >> 8
  gs.round_state.threshold = threshold >> 8
}

///|
fn TtEngine::op_sround(self : TtEngine) -> Result[Unit, HintError] {
  let n = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  tt_super_round(self.graphics, 0x4000, n)
  self.graphics.round_state.mode = TtRoundMode::Super
  Ok(())
}

///|
fn TtEngine::op_s45round(self : TtEngine) -> Result[Unit, HintError] {
  let n = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  tt_super_round(self.graphics, 0x2D41, n)
  self.graphics.round_state.mode = TtRoundMode::Super45
  Ok(())
}

///|
fn TtEngine::op_smd(self : TtEngine) -> Result[Unit, HintError] {
  let d = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.retained.min_distance = d
  Ok(())
}

///|
fn TtEngine::op_scvtci(self : TtEngine) -> Result[Unit, HintError] {
  let c = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.retained.control_value_cutin = c
  Ok(())
}

///|
fn TtEngine::op_sswci(self : TtEngine) -> Result[Unit, HintError] {
  let c = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.retained.single_width_cutin = c
  Ok(())
}

///|
fn TtEngine::op_ssw(self : TtEngine) -> Result[Unit, HintError] {
  let n = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.retained.single_width = tt_hint_mul_16_16(
    n,
    self.graphics.retained.scale,
  )
  Ok(())
}

///|
fn TtEngine::op_flipon(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.retained.auto_flip = true
  Ok(())
}

///|
fn TtEngine::op_flipoff(self : TtEngine) -> Result[Unit, HintError] {
  self.graphics.retained.auto_flip = false
  Ok(())
}

///|
fn TtEngine::op_sangw(self : TtEngine) -> Result[Unit, HintError] {
  match self.value_stack.pop() {
    Err(e) => Err(e)
    Ok(_) => Ok(())
  }
}

///|
fn TtEngine::op_instctrl(self : TtEngine) -> Result[Unit, HintError] {
  let selector = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let value = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  // Selector is index (1..=3).
  if selector < 1 || selector > 3 {
    return Ok(())
  }
  let selector_flag = 1 << (selector - 1)
  if value != 0 && value != selector_flag {
    return Ok(())
  }
  // If preserving linear metrics, prevent modification of the backward compat flag.
  if selector == 3 && self.graphics.retained.target.preserve_linear_metrics() {
    return Ok(())
  }
  match self.program.current {
    TtProgram::ControlValue => {
      self.graphics.retained.instruct_control = self.graphics.retained.instruct_control &
        (selector_flag ^ -1)
      self.graphics.retained.instruct_control = self.graphics.retained.instruct_control |
        value
    }
    TtProgram::Glyph =>
      if selector == 3 {
        self.graphics.backward_compatibility = value != 4
      }
    _ => ()
  }
  Ok(())
}

///|
fn TtEngine::op_scanctrl(self : TtEngine) -> Result[Unit, HintError] {
  let n = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let threshold = n & 0xFF
  if threshold == 0xFF {
    self.graphics.retained.scan_control = true
    return Ok(())
  }
  if threshold == 0 {
    self.graphics.retained.scan_control = false
    return Ok(())
  }
  let ppem = self.graphics.retained.ppem
  let is_rotated = self.graphics.retained.is_rotated
  let is_stretched = self.graphics.retained.is_stretched
  // See fontations/skrifa + FreeType: bits 8..13 conditionally enable/disable.
  let mut scan_control = self.graphics.retained.scan_control
  // Bits 8-10 set scan_control to true when the condition is met.
  if (n & 0x100) != 0 && ppem <= threshold {
    scan_control = true
  }
  if (n & 0x200) != 0 && is_rotated {
    scan_control = true
  }
  if (n & 0x400) != 0 && is_stretched {
    scan_control = true
  }
  // Bits 11-13 set scan_control to false when the condition is met.
  if (n & 0x800) != 0 && ppem > threshold {
    scan_control = false
  }
  if (n & 0x1000) != 0 && is_rotated {
    scan_control = false
  }
  if (n & 0x2000) != 0 && is_stretched {
    scan_control = false
  }
  self.graphics.retained.scan_control = scan_control
  Ok(())
}

///|
fn TtEngine::op_scantype(self : TtEngine) -> Result[Unit, HintError] {
  let n = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.retained.scan_type = n & 0xFFFF
  Ok(())
}

///|
fn TtEngine::op_getinfo(self : TtEngine) -> Result[Unit, HintError] {
  // See <https://learn.microsoft.com/en-us/typography/opentype/spec/tt_instructions#get-information>
  // and `fontations/skrifa` GETINFO implementation.
  let selector = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let mut result = 0
  // Interpreter version: selector bit 0, result bits 0..7.
  if (selector & (1 << 0)) != 0 {
    result = 40
  }
  // Glyph rotated: selector bit 1, result bit 8.
  if (selector & (1 << 1)) != 0 && self.graphics.retained.is_rotated {
    result = result | (1 << 8)
  }
  // Glyph stretched: selector bit 2, result bit 9.
  if (selector & (1 << 2)) != 0 && self.graphics.retained.is_stretched {
    result = result | (1 << 9)
  }
  // Font variations: selector bit 3, result bit 10.
  if (selector & (1 << 3)) != 0 && self.axis_count != 0 {
    result = result | (1 << 10)
  }
  if self.graphics.retained.target.is_smooth() {
    // Subpixel hinting: selector bit 6, result bit 13 (always enabled).
    if (selector & (1 << 6)) != 0 {
      result = result | (1 << 13)
    }
    // Vertical LCD: selector bit 8, result bit 15.
    if (selector & (1 << 8)) != 0 &&
      self.graphics.retained.target.is_vertical_lcd() {
      result = result | (1 << 15)
    }
    // Subpixel positioned: selector bit 10, result bit 17 (always enabled).
    if (selector & (1 << 10)) != 0 {
      result = result | (1 << 17)
    }
    // Symmetrical smoothing: selector bit 11, result bit 18.
    if (selector & (1 << 11)) != 0 &&
      self.graphics.retained.target.symmetric_rendering() {
      result = result | (1 << 18)
    }
    // ClearType + grayscale: selector bit 12, result bit 19.
    if (selector & (1 << 12)) != 0 &&
      self.graphics.retained.target.is_grayscale_cleartype() {
      result = result | (1 << 19)
    }
  }
  self.value_stack.push(result)
}

///|
fn TtEngine::op_getvariation(
  self : TtEngine,
  pc : Int,
) -> Result[Unit, HintError] {
  if self.axis_count != 0 {
    for i in 0..<self.axis_count {
      let coord = if i < self.coords.length() { self.coords.at(i) } else { 0 }
      match self.value_stack.push(coord) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    Ok(())
  } else {
    self.op_unknown(0x91, pc)
  }
}

///|
fn TtEngine::op_getdata(self : TtEngine, pc : Int) -> Result[Unit, HintError] {
  if self.axis_count != 0 {
    self.value_stack.push(17)
  } else {
    self.op_unknown(0x92, pc)
  }
}

///|
fn TtEngine::op_sdpvtl(
  self : TtEngine,
  opcode : Int,
) -> Result[Unit, HintError] {
  // Sets dual projection vector to line.
  let index1 = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let index2 = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let is_parallel = (opcode & 1) == 0
  let p1 = match self.graphics.zp1_zone().original_point(index2) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let p2 = match self.graphics.zp2_zone().original_point(index1) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let v = tt_line_vector(p1, p2, is_parallel)
  self.graphics.dual_proj_vector = v
  self.graphics.update_projection_state()
  Ok(())
}
