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
test "tt_hint: fdef/call/loopcall basic flow" {
  let font = Bytes::from_array(
    Array::from_fixed_array([
      // FDEF 0: ADD 2
      (0xB0).to_byte(),
      (0).to_byte(),
      (0x2C).to_byte(),
      (0xB0).to_byte(),
      (2).to_byte(),
      (0x60).to_byte(),
      (0x2D).to_byte(),
      // FDEF 1: CALL 0, LOOPCALL 5x 0, NEG
      (0xB0).to_byte(),
      (1).to_byte(),
      (0x2C).to_byte(),
      (0xB0).to_byte(),
      (0).to_byte(),
      (0x2B).to_byte(),
      (0xB1).to_byte(),
      (5).to_byte(),
      (0).to_byte(),
      (0x2A).to_byte(),
      (0x65).to_byte(),
      (0x2D).to_byte(),
    ]).op_as_view(),
  )
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    font[:],
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
  engine.run_program(TtProgram::Font, false).unwrap() |> ignore
  engine.value_stack.push(10).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_call(0).unwrap() |> ignore
  engine.run().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap(), content="-22")
}

///|
test "tt_hint: fdef in glyph program errors" {
  let glyph = Bytes::from_array(
    Array::from_fixed_array([
      (0xB0).to_byte(),
      (0).to_byte(),
      (0x2C).to_byte(),
      (0x2D).to_byte(),
    ]).op_as_view(),
  )
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    empty[:],
    empty[:],
    glyph[:],
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
  match engine.run_program(TtProgram::Glyph, false) {
    Err(HintError::DefinitionInGlyphProgram) => ()
    Ok(_) => fail("expected DefinitionInGlyphProgram")
    Err(_) => fail("expected DefinitionInGlyphProgram")
  }
}

///|
test "tt_hint: nested definitions error" {
  let font = Bytes::from_array(
    Array::from_fixed_array([
      (0xB0).to_byte(),
      (0).to_byte(),
      (0x2C).to_byte(),
      // Nested FDEF
      (0xB0).to_byte(),
      (1).to_byte(),
      (0x2C).to_byte(),
      (0x2D).to_byte(),
      (0x2D).to_byte(),
    ]).op_as_view(),
  )
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    font[:],
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
  match engine.run_program(TtProgram::Font, false) {
    Err(HintError::NestedDefinition) => ()
    Ok(_) => fail("expected NestedDefinition")
    Err(_) => fail("expected NestedDefinition")
  }
}

///|
test "tt_hint: TooManyDefinitions when max_function_defs=0" {
  let font = Bytes::from_array(
    Array::from_fixed_array([
      (0xB0).to_byte(),
      (0).to_byte(),
      (0x2C).to_byte(),
      (0x2D).to_byte(),
    ]).op_as_view(),
  )
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    font[:],
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
    0,
    64,
  )
  match engine.run_program(TtProgram::Font, false) {
    Err(HintError::TooManyDefinitions) => ()
    Ok(_) => fail("expected TooManyDefinitions")
    Err(_) => fail("expected TooManyDefinitions")
  }
}
