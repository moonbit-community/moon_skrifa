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
fn tt_make_engine_for_delta() -> TtEngine {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::make(16, 0), // cvt
    Array::make(16, 0), // storage
    Some(32),
    0,
    coords0.op_as_view(),
    64,
    32,
    64,
    64,
  )

  // Match fontations MockEngine zone layout enough for delta ops.
  let unscaled : Array[TtPoint] = Array::make(32, TtPoint::{ x: 0, y: 0 })
  for i in 0..<32 {
    let x = 57 + i * 2
    unscaled.set(i, TtPoint::{ x, y: -x * 3 })
  }
  let glyph = TtZone::{
    unscaled,
    original: Array::make(32, TtPoint::{ x: 0, y: 0 }),
    points: Array::make(32, TtPoint::{ x: 0, y: 0 }),
    flags: Array::make(32, 0),
    contours: Array::from_fixed_array([31]),
  }
  let twilight = TtZone::{
    unscaled: Array::new(),
    original: Array::make(16, TtPoint::{ x: 0, y: 0 }),
    points: Array::make(16, TtPoint::{ x: 0, y: 0 }),
    flags: Array::make(16, 0),
    contours: Array::new(),
  }
  engine.graphics.glyph = glyph
  engine.graphics.twilight = twilight
  engine.graphics.update_projection_state()
  engine
}

///|
test "tt_hint: delta DELTAP" {
  let engine = tt_make_engine_for_delta()
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  let raw_ppem = 16
  let raw_adjustment = 7

  // (ppem_bias, opcode)
  let cases : Array[(Int, Int)] = Array::from_fixed_array([
      (0, 0x5D), // DELTAP1
      (16, 0x71), // DELTAP2
      (32, 0x72),
    ], // DELTAP3
  )
  for i in 0..<cases.length() {
    let (ppem_bias, opcode) = cases.at(i)
    engine.graphics.retained = TtRetainedGraphicsState::new(
      engine.graphics.retained.scale,
      raw_ppem + ppem_bias,
      engine.graphics.retained.target,
    )
    let packed_ppem = raw_ppem - engine.graphics.retained.delta_base

    // packed ppem + adjustment entry
    engine.value_stack.push((packed_ppem << 4) | raw_adjustment).unwrap()
    |> ignore
    // point index
    engine.value_stack.push(i).unwrap() |> ignore
    // exception count
    engine.value_stack.push(1).unwrap() |> ignore
    engine.op_deltap(opcode).unwrap() |> ignore
    let p = engine.graphics.glyph.point(i).unwrap()
    inspect(p.x == -8 && p.y == 0, content="true")
  }
}

///|
test "tt_hint: delta DELTAC" {
  let engine = tt_make_engine_for_delta()
  let raw_ppem = 16
  let raw_adjustment = 7

  // (ppem_bias, opcode)
  let cases : Array[(Int, Int)] = Array::from_fixed_array([
      (0, 0x73), // DELTAC1
      (16, 0x74), // DELTAC2
      (32, 0x75),
    ], // DELTAC3
  )
  for i in 0..<cases.length() {
    let (ppem_bias, opcode) = cases.at(i)
    engine.graphics.retained = TtRetainedGraphicsState::new(
      engine.graphics.retained.scale,
      raw_ppem + ppem_bias,
      engine.graphics.retained.target,
    )
    let packed_ppem = raw_ppem - engine.graphics.retained.delta_base

    // packed ppem + adjustment entry
    engine.value_stack.push((packed_ppem << 4) | raw_adjustment).unwrap()
    |> ignore
    // cvt index
    engine.value_stack.push(i).unwrap() |> ignore
    // exception count
    engine.value_stack.push(1).unwrap() |> ignore
    engine.op_deltac(opcode).unwrap() |> ignore
    inspect(engine.cvt.at(i) == -8, content="true")
  }
}

///|
test "tt_hint: delta negative count does not hang (DELTAP/DELTAC)" {
  let engine = tt_make_engine_for_delta()
  // Match fontations: in non-pedantic mode, stack under/overflow is not an error.
  engine.graphics.is_pedantic = false
  engine.value_stack.check = false

  // Non-pedantic mode: n=-1 results in a no-op.
  let stack : FixedArray[Int] = [0, 0, -1]
  for v in stack {
    engine.value_stack.push(v).unwrap() |> ignore
  }
  match engine.op_deltap(0x72) {
    Ok(_) => ()
    Err(_) => fail("expected Ok for deltap negative count in non-pedantic mode")
  }
  for v in stack {
    engine.value_stack.push(v).unwrap() |> ignore
  }
  match engine.op_deltac(0x75) {
    Ok(_) => ()
    Err(_) => fail("expected Ok for deltac negative count in non-pedantic mode")
  }

  // Pedantic mode: negative count is an error.
  engine.graphics.is_pedantic = true
  engine.value_stack.check = true
  for v in stack {
    engine.value_stack.push(v).unwrap() |> ignore
  }
  match engine.op_deltap(0x72) {
    Err(HintError::InvalidStackValue(-1)) => ()
    Ok(_) => fail("expected InvalidStackValue(-1)")
    Err(_) => fail("expected InvalidStackValue(-1)")
  }
  for v in stack {
    engine.value_stack.push(v).unwrap() |> ignore
  }
  match engine.op_deltac(0x75) {
    Err(HintError::InvalidStackValue(-1)) => ()
    Ok(_) => fail("expected InvalidStackValue(-1)")
    Err(_) => fail("expected InvalidStackValue(-1)")
  }
}
