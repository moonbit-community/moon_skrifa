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
fn tt_bytes_for_control_flow(xs : FixedArray[Byte]) -> Bytes {
  Bytes::from_array(Array::from_fixed_array(xs).op_as_view())
}

///|
fn tt_make_engine_for_control_flow() -> TtEngine {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  TtEngine::new(
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
}

///|
test "tt_hint: control flow IF/ELSE nesting skip" {
  let engine = tt_make_engine_for_control_flow()
  // Some code with nested IF/ELSE/EIF blocks.
  let code = tt_bytes_for_control_flow([
    (0x58).to_byte(), // IF
    (0x60).to_byte(), // ADD
    (0x61).to_byte(), // SUB
    (0x58).to_byte(), // IF
    (0x63).to_byte(), // MUL
    (0x62).to_byte(), // DIV
    (0x1B).to_byte(), // ELSE
    (0x30).to_byte(), // IUP0
    (0x31).to_byte(), // IUP1
    (0x59).to_byte(), // EIF
    (0x1B).to_byte(), // ELSE
    (0x7C).to_byte(), // RUTG
    (0x58).to_byte(), // IF
    (0x59).to_byte(), // EIF
    (0x59).to_byte(), // EIF
  ])
  engine.program.decoder = TtDecoder::new(code[:])

  // Outer IF (at pc=0, so body starts at pc=1).
  engine.program.decoder.pc = 1
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_if().unwrap() |> ignore
  inspect(engine.program.decoder.pc == 1, content="true")
  engine.program.decoder.pc = 1
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_if().unwrap() |> ignore
  // Jumped to the start of the outer ELSE body (pc after ELSE).
  inspect(engine.program.decoder.pc == 11, content="true")

  // Inner IF (at pc=3, so body starts at pc=4).
  engine.program.decoder.pc = 4
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_if().unwrap() |> ignore
  inspect(engine.program.decoder.pc == 4, content="true")
  engine.program.decoder.pc = 4
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_if().unwrap() |> ignore
  // Jumped to the start of the inner ELSE body (pc after ELSE).
  inspect(engine.program.decoder.pc == 7, content="true")

  // ELSE skipping: skip to matching EIF, ignoring nested IF/EIF.
  engine.program.decoder.pc = 11
  engine.op_else(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc == 15, content="true")
  engine.program.decoder.pc = 7
  engine.op_else(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc == 10, content="true")
}

///|
test "tt_hint: control flow JMPR/JROT/JROF pc math" {
  let engine = tt_make_engine_for_control_flow()

  // Unconditional jump: pc += (offset - 1)
  engine.program.decoder.pc = 1000
  engine.value_stack.push(100).unwrap() |> ignore
  engine.op_jmpr(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc == 1099, content="true")

  // Jump if true: stack is [offset, cond] (cond on top)
  engine.program.decoder.pc = 1000
  engine.value_stack.push(100).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_jrot(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc == 1000, content="true")
  engine.value_stack.push(100).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_jrot(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc == 1099, content="true")

  // Jump if false
  engine.program.decoder.pc = 1000
  engine.value_stack.push(-100).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_jrof(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc == 1000, content="true")
  engine.value_stack.push(-100).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_jrof(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc == 899, content="true")
}
