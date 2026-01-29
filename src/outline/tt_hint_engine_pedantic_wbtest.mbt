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
test "tt_hint: non-pedantic stack underflow uses 0 (dup/pop)" {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::new(),
    Array::new(),
    None,
    0,
    coords0.op_as_view(),
    64,
    32,
    64,
    64,
  )

  // Reset in non-pedantic mode.
  engine.run_program(TtProgram::Font, false).unwrap() |> ignore

  // DUP[] on empty stack should push 0.
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x20,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(engine.value_stack.length() == 1, content="true")
  inspect(engine.value_stack.pop().unwrap() == 0, content="true")

  // POP[] on empty stack should be Ok (consumes 0).
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x21,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(engine.value_stack.length() == 0, content="true")
}

///|
test "tt_hint: pedantic stack underflow errors (dup)" {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::new(),
    Array::new(),
    None,
    0,
    coords0.op_as_view(),
    64,
    32,
    64,
    64,
  )

  // Reset in pedantic mode.
  engine.run_program(TtProgram::Font, true).unwrap() |> ignore
  match
    engine.dispatch(TtInstruction::{
      pc: 0,
      opcode: 0x20,
      inline_operands: Array::new(),
    }) {
    Err(HintError::ValueStackUnderflow) => ()
    Ok(_) => fail("expected ValueStackUnderflow")
    Err(_) => fail("expected ValueStackUnderflow")
  }
}
