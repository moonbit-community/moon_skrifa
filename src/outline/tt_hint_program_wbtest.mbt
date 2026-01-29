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
fn tt_prog_bytes(xs : FixedArray[Byte]) -> Bytes {
  Bytes::from_array(Array::from_fixed_array(xs).op_as_view())
}

///|
test "tt_hint: program state accounting push/pop frame" {
  let font_code = tt_prog_bytes([(0).to_byte()])
  let cv_code = tt_prog_bytes([(1).to_byte()])
  let glyph_code = tt_prog_bytes([(2).to_byte()])
  let state = TtProgramState::new(
    font_code[:],
    cv_code[:],
    glyph_code[:],
    TtProgram::Glyph,
    32,
  )
  inspect(state.current is TtProgram::Glyph, content="true")
  inspect(state.decoder.code.at(0).to_int() == 2, content="true")
  inspect(state.decoder.pc == 0, content="true")

  // Move to control value code.
  state.push_frame(cv_code[:], 33, state.decoder.pc).unwrap() |> ignore
  inspect(state.decoder.code.at(0).to_int() == 1, content="true")
  inspect(state.decoder.pc == 33, content="true")

  // Bump pc so we can validate return_pc is respected on pop.
  state.decoder.pc = state.decoder.pc + 20
  let return_pc = state.decoder.pc

  // Enter font code.
  state.push_frame(font_code[:], 10, return_pc).unwrap() |> ignore
  inspect(state.decoder.code.at(0).to_int() == 0, content="true")
  inspect(state.decoder.pc == 10, content="true")

  // Back to control value code (pc restored to return_pc).
  state.pop_frame().unwrap() |> ignore
  inspect(state.decoder.code.at(0).to_int() == 1, content="true")
  inspect(state.decoder.pc == 53, content="true")

  // Back to original glyph code.
  state.pop_frame().unwrap() |> ignore
  inspect(state.decoder.code.at(0).to_int() == 2, content="true")
  inspect(state.decoder.pc == 0, content="true")
}

///|
test "tt_hint: program state loopcall frame" {
  let font_code = tt_prog_bytes([(0).to_byte()])
  let cv_code = tt_prog_bytes([(1).to_byte()])
  let glyph_code = tt_prog_bytes([(2).to_byte()])
  let state = TtProgramState::new(
    font_code[:],
    cv_code[:],
    glyph_code[:],
    TtProgram::Glyph,
    32,
  )
  // Execute "font" callee 3 times => remaining=2 (count-1).
  state.push_loopcall_frame(font_code[:], 2, 0, 0).unwrap() |> ignore
  for _ in 0..<3 {
    inspect(state.decoder.code.at(0).to_int() == 0, content="true")
    inspect(state.decoder.pc == 0, content="true")
    // Modify program counter to ensure we reset on loop iteration.
    state.decoder.pc = state.decoder.pc + 22
    state.pop_frame().unwrap() |> ignore
  }
  inspect(state.decoder.code.at(0).to_int() == 2, content="true")
  inspect(state.decoder.pc == 0, content="true")
}

///|
test "tt_hint: program state call stack underflow" {
  let font_code = tt_prog_bytes([(0).to_byte()])
  let cv_code = tt_prog_bytes([(1).to_byte()])
  let glyph_code = tt_prog_bytes([(2).to_byte()])
  let state = TtProgramState::new(
    font_code[:],
    cv_code[:],
    glyph_code[:],
    TtProgram::Glyph,
    32,
  )
  inspect(
    state.pop_frame() is Err(HintError::CallStackUnderflow),
    content="true",
  )
}

///|
test "tt_hint: program state call stack overflow" {
  let font_code = tt_prog_bytes([(0).to_byte()])
  let cv_code = tt_prog_bytes([(1).to_byte()])
  let glyph_code = tt_prog_bytes([(2).to_byte()])
  let state = TtProgramState::new(
    font_code[:],
    cv_code[:],
    glyph_code[:],
    TtProgram::Glyph,
    3,
  )
  for _ in 0..<3 {
    state.push_frame(cv_code[:], 0, 0).unwrap() |> ignore
  }
  inspect(
    state.push_frame(cv_code[:], 0, 0) is Err(HintError::CallStackOverflow),
    content="true",
  )
}
