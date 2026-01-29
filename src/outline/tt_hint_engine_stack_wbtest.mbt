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
fn tt_stack_snapshot(engine : TtEngine) -> Array[Int] {
  let out : Array[Int] = Array::new()
  let n = engine.value_stack.length()
  for i in 0..<n {
    out.push(engine.value_stack.buf.at(i))
  }
  out
}

///|
fn tt_stack_eq(engine : TtEngine, expected : FixedArray[Int]) -> Bool {
  let got = tt_stack_snapshot(engine)
  if got.length() != expected.length() {
    return false
  }
  for i in 0..<expected.length() {
    if got.at(i) != expected[i] {
      return false
    }
  }
  true
}

///|
test "tt_hint: engine stack ops (push/depth/pop/swap/roll/cindex/mindex)" {
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

  // Push instructions (PUSHB[4], PUSHW[4]).
  let byte_args = Array::from_fixed_array([2, 4, 6, 8])
  let word_args = Array::from_fixed_array([-2000, 4000, -6000, 8000])
  engine
  .dispatch(TtInstruction::{ pc: 0, opcode: 0xB3, inline_operands: byte_args })
  .unwrap()
  |> ignore
  engine
  .dispatch(TtInstruction::{ pc: 0, opcode: 0xBB, inline_operands: word_args })
  .unwrap()
  |> ignore
  inspect(
    tt_stack_eq(engine, [2, 4, 6, 8, -2000, 4000, -6000, 8000]),
    content="true",
  )

  // DEPTH[]
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x24,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(engine.value_stack.pop().unwrap() == 8, content="true")

  // POP[] x2
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x21,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x21,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(tt_stack_eq(engine, [2, 4, 6, 8, -2000, 4000]), content="true")

  // SWAP[]
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x23,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(tt_stack_eq(engine, [2, 4, 6, 8, 4000, -2000]), content="true")

  // ROLL[]
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x8A,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(tt_stack_eq(engine, [2, 4, 6, 4000, -2000, 8]), content="true")

  // CINDEX[] (push index=4, then CINDEX: top element becomes 6).
  engine.value_stack.push(4).unwrap() |> ignore
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x25,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(engine.value_stack.peek(0).unwrap() == 6, content="true")

  // MINDEX[] (push index=3, then MINDEX: top element becomes -2000).
  engine.value_stack.push(3).unwrap() |> ignore
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x26,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(engine.value_stack.peek(0).unwrap() == -2000, content="true")
}

///|
test "tt_hint: engine cindex/mindex accept zero index (FreeType style)" {
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
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(2).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore

  // CINDEX with index=0 is a no-op in upstream (copies top element onto itself).
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x25,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(tt_stack_eq(engine, [1, 2, 0]), content="true")

  // MINDEX with index=0 moves the top element to the new top, effectively popping one slot.
  engine
  .dispatch(TtInstruction::{
    pc: 0,
    opcode: 0x26,
    inline_operands: Array::new(),
  })
  .unwrap()
  |> ignore
  inspect(tt_stack_eq(engine, [1, 0]), content="true")
}
