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
fn tt_bytes_for_limits(xs : FixedArray[Byte]) -> Bytes {
  Bytes::from_array(Array::from_fixed_array(xs).op_as_view())
}

///|
test "tt_hint: loop budget backward jumps" {
  let zero = (0).to_byte()
  let font = Bytes::from_array(Array::make(2048, zero).op_as_view())
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

  // Keep jumps in-bounds so we test loop budget behavior.
  engine.program.decoder.pc = 1000
  let limit = engine.loop_budget.limit

  // Prime the counter so the last successful iteration aligns with upstream.
  engine.value_stack.push(-1).unwrap() |> ignore
  engine.op_jmpr(0).unwrap() |> ignore
  for i in 0..<(limit + 10) {
    engine.value_stack.push(-1).unwrap() |> ignore
    let r = engine.op_jmpr(0)
    if i < limit - 1 {
      match r {
        Ok(_) => ()
        Err(_) => fail("expected Ok")
      }
    } else {
      match r {
        Err(HintError::ExceededExecutionBudget) => ()
        Ok(_) => fail("expected ExceededExecutionBudget")
        Err(_) => fail("expected ExceededExecutionBudget")
      }
    }
  }
}

///|
test "tt_hint: loop budget loopcall" {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()

  // Define FDEF 0 in the font program (body is ENDF only).
  let font = tt_bytes_for_limits([
    (0xB0).to_byte(),
    (0).to_byte(),
    (0x2C).to_byte(),
    (0x2D).to_byte(),
  ])
  // Execute LOOPCALL twice: first consumes all budget, second exceeds it.
  // With point_count=Some(1) and cvt_len=0, loop budget limit is 100:
  // PUSHB[2] (count=100, f=0), LOOPCALL, PUSHB[2] (count=1, f=0), LOOPCALL.
  let prep = tt_bytes_for_limits([
    (0xB1).to_byte(),
    (100).to_byte(),
    (0).to_byte(),
    (0x2A).to_byte(),
    (0xB1).to_byte(),
    (1).to_byte(),
    (0).to_byte(),
    (0x2A).to_byte(),
  ])
  let engine = TtEngine::new(
    font[:],
    prep[:],
    empty[:],
    retained,
    Array::new(),
    Array::new(),
    Some(1),
    0,
    coords0.op_as_view(),
    64,
    32,
    64,
    64,
  )
  engine.run_program(TtProgram::Font, false).unwrap() |> ignore
  match engine.run_program(TtProgram::ControlValue, false) {
    Err(HintError::ExceededExecutionBudget) => ()
    Ok(_) => fail("expected ExceededExecutionBudget")
    Err(_) => fail("expected ExceededExecutionBudget")
  }
}

///|
test "tt_hint: jmpr does not bounds-check pc" {
  let code = Bytes::from_array(Array::make(8, (0).to_byte()).op_as_view())
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    code[:],
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
  engine.program.decoder.pc = 0
  engine.value_stack.push(100).unwrap() |> ignore
  engine.op_jmpr(0).unwrap() |> ignore
  inspect(engine.program.decoder.pc, content="99")
}

///|
test "tt_hint: DefinitionTooLarge in pedantic mode" {
  let huge : Array[Byte] = Array::new()
  huge.push((0xB0).to_byte())
  huge.push((0).to_byte())
  huge.push((0x2C).to_byte())
  // 65536 bytes of body, plus ENDF => len > 0xFFFF.
  for _ in 0..<65536 {
    huge.push((0).to_byte())
  }
  huge.push((0x2D).to_byte())
  let font = Bytes::from_array(huge.op_as_view())
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
  match engine.run_program(TtProgram::Font, true) {
    Err(HintError::DefinitionTooLarge) => ()
    Ok(_) => fail("expected DefinitionTooLarge")
    Err(_) => fail("expected DefinitionTooLarge")
  }
}
