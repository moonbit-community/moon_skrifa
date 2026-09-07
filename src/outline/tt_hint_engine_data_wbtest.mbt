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
fn tt_make_engine_for_data_ops() -> TtEngine {
  let empty = Bytes::from_array(Array()[:])
  let retained = TtRetainedGraphicsState(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array()
  let engine = TtEngine(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::make(16, 0), // cvt
    Array::make(16, 0), // storage
    Some(32),
    0,
    coords0[:],
    64,
    32,
    64,
    64,
  )

  // Mirror fontations MockEngine setup (shape + unscaled point pattern).
  let unscaled : Array[TtPoint] = Array::make(32, { x: 0, y: 0, })
  for i in 0..<32 {
    let x = 57 + i * 2
    unscaled.set(i, { x, y: -x * 3, })
  }
  engine.graphics.glyph = {
    unscaled,
    original: Array::make(32, { x: 0, y: 0, }),
    points: Array::make(32, { x: 0, y: 0, }),
    flags: Array::make(32, 0),
    contours: Array::from_fixed_array([31]),
  }
  engine.graphics.twilight = {
    unscaled: Array(),
    original: Array::make(16, { x: 0, y: 0, }),
    points: Array::make(16, { x: 0, y: 0, }),
    flags: Array::make(16, 0),
    contours: Array(),
  }
  // Match fontations: default tests run in non-pedantic mode.
  engine.graphics.is_pedantic = false
  engine.value_stack.check = false
  engine.graphics.update_projection_state()
  engine
}

///|
fn tt_set_test_vectors(engine : TtEngine) -> Unit {
  let (x, y) = tt_hint_normalize14(100, 50)
  let v = TtVec14::{ x, y, }
  engine.graphics.proj_vector = v
  engine.graphics.dual_proj_vector = v
  engine.graphics.freedom_vector = v
  engine.graphics.update_projection_state()
}

///|
test "tt_hint: data MPPEM/MPS" {
  let engine = tt_make_engine_for_data_ops()
  let ppem = 20
  engine.graphics.retained = TtRetainedGraphicsState(
    engine.graphics.retained.scale,
    ppem,
    engine.graphics.retained.target,
  )
  engine.op_mppem().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == ppem, content="true")
  engine.op_mps().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == ppem * 64, content="true")
}

///|
test "tt_hint: data GC" {
  let engine = tt_make_engine_for_data_ops()
  tt_set_test_vectors(engine)
  engine.graphics.zp2 = Glyph

  // current point projected coord
  engine.graphics.glyph.points.set(1, { x: 132, y: -256, })
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_gc(0).unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 4, content="true")

  // original point projected coord
  engine.graphics.glyph.original.set(1, { x: -64, y: 521, })
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_gc(1).unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 176, content="true")
}

///|
test "tt_hint: data SCFS updates twilight original" {
  let engine = tt_make_engine_for_data_ops()
  tt_set_test_vectors(engine)

  // Enable non-backcompat move behavior (matches fontations test comments).
  engine.graphics.backward_compatibility = false
  engine.graphics.did_iup_x = true
  engine.graphics.did_iup_y = true
  engine.graphics.zp2 = Twilight
  engine.graphics.twilight.points.set(1, { x: 132, y: -256, })
  let p0 = engine.graphics.twilight.point(1).unwrap()
  let o0 = engine.graphics.twilight.original_point(1).unwrap()
  inspect(!(p0.x == o0.x && p0.y == o0.y), content="true")

  // push point number, then value to match
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(42).unwrap() |> ignore
  engine.op_scfs().unwrap() |> ignore
  let p = engine.graphics.twilight.point(1).unwrap()
  inspect(p.x == 166 && p.y == -239, content="true")
  let o = engine.graphics.twilight.original_point(1).unwrap()
  inspect(p.x == o.x && p.y == o.y, content="true")
}

///|
test "tt_hint: data MD scaled" {
  let engine = tt_make_engine_for_data_ops()
  tt_set_test_vectors(engine)
  engine.graphics.zp0 = Glyph
  engine.graphics.zp1 = Glyph
  engine.graphics.glyph.points.set(1, { x: 132, y: -256, })
  engine.graphics.glyph.points.set(3, { x: -64, y: 100, })
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(3).unwrap() |> ignore
  engine.op_md(1).unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 16, content="true")
}

///|
test "tt_hint: data MD unscaled" {
  let engine = tt_make_engine_for_data_ops()
  tt_set_test_vectors(engine)
  engine.graphics.retained = TtRetainedGraphicsState(
    375912,
    engine.graphics.retained.ppem,
    engine.graphics.retained.target,
  )
  engine.graphics.zp0 = Glyph
  engine.graphics.zp1 = Glyph
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(3).unwrap() |> ignore
  engine.op_md(0).unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 11, content="true")
}

///|
test "tt_hint: data MD twilight (original outline)" {
  let engine = tt_make_engine_for_data_ops()
  tt_set_test_vectors(engine)
  engine.graphics.zp0 = Twilight
  engine.graphics.zp1 = Twilight
  engine.graphics.twilight.original.set(1, { x: 132, y: -256, })
  engine.graphics.twilight.original.set(3, { x: -64, y: 100, })
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(3).unwrap() |> ignore
  engine.op_md(0).unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 16, content="true")
}
