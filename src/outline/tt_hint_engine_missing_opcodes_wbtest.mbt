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
fn tt_bytes(xs : FixedArray[Byte]) -> Bytes {
  Bytes::from_array(Array::from_fixed_array(xs).op_as_view())
}

///|
test "tt_hint: missing opcodes (getvariation/getdata/odd/even/mps/debug)" {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let cvt : Array[Int] = Array::new()
  let storage : Array[Int] = Array::new()
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()

  // Define IDEF for opcode 0x91 (GETVARIATION) that pushes 123.
  let font = tt_bytes([
    (0xB0).to_byte(),
    (0x91).to_byte(),
    (0x89).to_byte(),
    (0xB0).to_byte(),
    (123).to_byte(),
    (0x2D).to_byte(),
  ])
  let prep = tt_bytes([(0x91).to_byte()])
  let engine0 = TtEngine::new(
    font[:],
    prep[:],
    empty[:],
    retained,
    cvt,
    storage,
    None,
    0,
    coords0.op_as_view(),
    64,
    32,
    64,
    64,
  )
  engine0.run_program(TtProgram::Font, false).unwrap() |> ignore
  engine0.run_program(TtProgram::ControlValue, false).unwrap() |> ignore
  inspect(engine0.value_stack.pop().unwrap(), content="123")

  // GETVARIATION pushes axis_count coords; pad with zeros if missing.
  let coords1 : Array[@moon_skrifa.NormalizedCoord] = Array::from_fixed_array([
    8192,
  ])
  let prep1 = tt_bytes([(0x91).to_byte()])
  let engine1 = TtEngine::new(
    empty[:],
    prep1[:],
    empty[:],
    retained,
    Array::new(),
    Array::new(),
    None,
    2,
    coords1.op_as_view(),
    64,
    32,
    64,
    64,
  )
  engine1.run_program(TtProgram::ControlValue, false).unwrap() |> ignore
  inspect(engine1.value_stack.pop().unwrap(), content="0")
  inspect(engine1.value_stack.pop().unwrap(), content="8192")

  // GETDATA pushes 17 for variable fonts.
  let prep2 = tt_bytes([(0x92).to_byte()])
  let engine2 = TtEngine::new(
    empty[:],
    prep2[:],
    empty[:],
    retained,
    Array::new(),
    Array::new(),
    None,
    1,
    coords1.op_as_view(),
    64,
    32,
    64,
    64,
  )
  engine2.run_program(TtProgram::ControlValue, false).unwrap() |> ignore
  inspect(engine2.value_stack.pop().unwrap(), content="17")

  // ODD/EVEN.
  let prep3 = tt_bytes([
    (0xB0).to_byte(),
    (64).to_byte(),
    (0x56).to_byte(),
    (0xB0).to_byte(),
    (128).to_byte(),
    (0x57).to_byte(),
  ])
  let engine3 = TtEngine::new(
    empty[:],
    prep3[:],
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
  engine3.run_program(TtProgram::ControlValue, false).unwrap() |> ignore
  inspect(engine3.value_stack.pop().unwrap(), content="1")
  inspect(engine3.value_stack.pop().unwrap(), content="1")

  // MPS: ppem * 64.
  let prep4 = tt_bytes([(0x4C).to_byte()])
  let engine4 = TtEngine::new(
    empty[:],
    prep4[:],
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
  engine4.run_program(TtProgram::ControlValue, false).unwrap() |> ignore
  inspect(engine4.value_stack.pop().unwrap(), content="1280")

  // DEBUG: pops a value and leaves stack empty.
  let prep5 = tt_bytes([(0xB0).to_byte(), (1).to_byte(), (0x4F).to_byte()])
  let engine5 = TtEngine::new(
    empty[:],
    prep5[:],
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
  engine5.run_program(TtProgram::ControlValue, false).unwrap() |> ignore
  inspect(engine5.value_stack.length(), content="0")
}
