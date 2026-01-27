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
/// Bytecode decoding helpers for the TrueType interpreter.
///
/// Ported from `read_fonts::tables::glyf::bytecode` usage in
/// `fontations/skrifa/src/outline/glyf/hint/engine/dispatch.rs`
/// (Apache-2.0 OR MIT).
priv enum TtProgram {
  Font
  ControlValue
  Glyph
}

///|
priv struct TtInstruction {
  pc : Int
  opcode : Int
  inline_operands : Array[Int]
}

///|
priv struct TtDecoder {
  code : BytesView
  mut pc : Int
}

///|
fn TtDecoder::new(code : BytesView) -> TtDecoder {
  TtDecoder::{ code, pc: 0 }
}

///|
/// Decodes the next TrueType instruction.
///
/// The decoder only expands push instructions into `inline_operands`; all other
/// opcodes have an empty operand list.
fn TtDecoder::decode(self : TtDecoder) -> Result[TtInstruction?, HintError] {
  if self.pc < 0 || self.pc >= self.code.length() {
    return Ok(None)
  }
  let start = self.pc
  let op = self.code.at(self.pc).to_int()
  self.pc = self.pc + 1
  let operands : Array[Int] = Array::new()
  // PUSHB[1..8] 0xB0..0xB7
  if op >= 0xB0 && op <= 0xB7 {
    let n = op - 0xB0 + 1
    if self.pc + n > self.code.length() {
      return Err(HintError::UnexpectedEndOfBytecode)
    }
    for _ in 0..<n {
      operands.push(self.code.at(self.pc).to_int())
      self.pc = self.pc + 1
    }
    return Ok(
      Some(TtInstruction::{ pc: start, opcode: op, inline_operands: operands }),
    )
  }
  // PUSHW[1..8] 0xB8..0xBF
  if op >= 0xB8 && op <= 0xBF {
    let n = op - 0xB8 + 1
    let bytes = n * 2
    if self.pc + bytes > self.code.length() {
      return Err(HintError::UnexpectedEndOfBytecode)
    }
    for i in 0..<n {
      let off = self.pc + i * 2
      operands.push(tt_read_i16_be(self.code, off).unwrap_or(0))
    }
    self.pc = self.pc + bytes
    return Ok(
      Some(TtInstruction::{ pc: start, opcode: op, inline_operands: operands }),
    )
  }
  // NPUSHB 0x40
  if op == 0x40 {
    if self.pc + 1 > self.code.length() {
      return Err(HintError::UnexpectedEndOfBytecode)
    }
    let n = self.code.at(self.pc).to_int()
    self.pc = self.pc + 1
    if n < 0 || self.pc + n > self.code.length() {
      return Err(HintError::UnexpectedEndOfBytecode)
    }
    for _ in 0..<n {
      operands.push(self.code.at(self.pc).to_int())
      self.pc = self.pc + 1
    }
    return Ok(
      Some(TtInstruction::{ pc: start, opcode: op, inline_operands: operands }),
    )
  }
  // NPUSHW 0x41
  if op == 0x41 {
    if self.pc + 1 > self.code.length() {
      return Err(HintError::UnexpectedEndOfBytecode)
    }
    let n = self.code.at(self.pc).to_int()
    self.pc = self.pc + 1
    let bytes = n * 2
    if n < 0 || self.pc + bytes > self.code.length() {
      return Err(HintError::UnexpectedEndOfBytecode)
    }
    for i in 0..<n {
      let off = self.pc + i * 2
      operands.push(tt_read_i16_be(self.code, off).unwrap_or(0))
    }
    self.pc = self.pc + bytes
    return Ok(
      Some(TtInstruction::{ pc: start, opcode: op, inline_operands: operands }),
    )
  }
  Ok(Some(TtInstruction::{ pc: start, opcode: op, inline_operands: operands }))
}
