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
fn tt_make_engine_for_outline() -> TtEngine {
  let empty = Bytes::from_array([][:])
  let retained = TtRetainedGraphicsState::default()
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = []
  let engine = TtEngine(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::make(16, 0),
    Array::make(16, 0),
    Some(32),
    0,
    coords0[:],
    64,
    32,
    64,
    64,
  )

  // Mirror fontations MockEngine zone shape + unscaled point pattern.
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
    unscaled: [],
    original: Array::make(16, { x: 0, y: 0, }),
    points: Array::make(16, { x: 0, y: 0, }),
    flags: Array::make(16, 0),
    contours: [],
  }
  // Outline engine tests mirror fontations non-pedantic defaults.
  engine.graphics.is_pedantic = false
  engine.value_stack.check = false
  engine.graphics.update_projection_state()
  engine
}

///|
fn tt_set_test_vectors_for_outline(engine : TtEngine) -> Unit {
  let (x, y) = tt_hint_normalize14(100, 50)
  let v = TtVec14::{ x, y, }
  engine.graphics.proj_vector = v
  engine.graphics.dual_proj_vector = v
  engine.graphics.freedom_vector = v
  engine.graphics.update_projection_state()
}

///|
fn tt_set_point_for_outline(
  engine : TtEngine,
  point_ix : Int32,
  x : Int32,
  y : Int32,
) -> Unit {
  engine.graphics.glyph.points.set(point_ix, { x, y, })
}

///|
test "tt_hint: outline FLIPPT" {
  let engine = tt_make_engine_for_outline()
  let count = 5
  engine.value_stack.push(count) |> ignore
  engine.op_sloop() |> ignore
  for i in 1..<10 {
    if (i & 1) != 0 {
      engine.value_stack.push(i) |> ignore
    }
  }
  inspect(engine.value_stack.length() == count, content="true")
  engine.op_flippt() |> ignore
  for i in 0..<10 {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(on_curve == ((i & 1) != 0), content="true")
  }
}

///|
test "tt_hint: outline backward compat + IUP prevents FLIPPT" {
  let engine = tt_make_engine_for_outline()
  let count = 5
  engine.value_stack.push(count) |> ignore
  engine.op_sloop() |> ignore
  for i in 1..<10 {
    if (i & 1) != 0 {
      engine.value_stack.push(i) |> ignore
    }
  }
  engine.graphics.backward_compatibility = true
  engine.graphics.did_iup_x = true
  engine.graphics.did_iup_y = true
  engine.op_flippt() |> ignore
  for i in 0..<10 {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(!on_curve, content="true")
  }
}

///|
test "tt_hint: outline FLIPRGON/FLIPRGOFF" {
  let engine = tt_make_engine_for_outline()
  // Flip 10..=20 on.
  engine.value_stack.push(10) |> ignore
  engine.value_stack.push(20) |> ignore
  engine.op_fliprgon() |> ignore
  for i in 0..<engine.graphics.glyph.flags.length() {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(on_curve == (i >= 10 && i <= 20), content="true")
  }
  // Flip 12..=15 off.
  engine.value_stack.push(12) |> ignore
  engine.value_stack.push(15) |> ignore
  engine.op_fliprgoff() |> ignore
  for i in 0..<engine.graphics.glyph.flags.length() {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(
      on_curve == ((i >= 10 && i <= 11) || (i >= 16 && i <= 20)),
      content="true",
    )
  }
}

///|
test "tt_hint: outline backward compat + IUP prevents FLIPRGON/FLIPRGOFF" {
  let engine = tt_make_engine_for_outline()
  engine.graphics.backward_compatibility = true
  engine.graphics.did_iup_x = true
  engine.graphics.did_iup_y = true
  engine.value_stack.push(10) |> ignore
  engine.value_stack.push(20) |> ignore
  engine.op_fliprgon() |> ignore
  for i in 0..<engine.graphics.glyph.flags.length() {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(!on_curve, content="true")
  }

  // Reset all points to on-curve.
  for i in 0..<engine.graphics.glyph.flags.length() {
    engine.graphics.glyph.flags.set(i, engine.graphics.glyph.flags.at(i) | 1)
  }
  engine.value_stack.push(12) |> ignore
  engine.value_stack.push(15) |> ignore
  engine.op_fliprgoff() |> ignore
  for i in 0..<engine.graphics.glyph.flags.length() {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(on_curve, content="true")
  }
}

///|
test "tt_hint: outline UTP untouch uses freedom vector axes" {
  let engine = tt_make_engine_for_outline()
  let count = engine.graphics.glyph.points.length()
  for i in 0..<count {
    engine.graphics.glyph.touch(i, X) |> ignore
    engine.graphics.glyph.touch(i, Y) |> ignore
  }

  // Untouch x
  inspect(engine.graphics.glyph.is_touched(0, X), content="true")
  engine.graphics.freedom_vector = { x: 1, y: 0, }
  engine.value_stack.push(0) |> ignore
  engine.op_utp() |> ignore
  inspect(!engine.graphics.glyph.is_touched(0, X), content="true")
  inspect(engine.graphics.glyph.is_touched(0, Y), content="true")

  // Untouch y
  inspect(engine.graphics.glyph.is_touched(1, Y), content="true")
  engine.graphics.freedom_vector = { x: 0, y: 1, }
  engine.value_stack.push(1) |> ignore
  engine.op_utp() |> ignore
  inspect(engine.graphics.glyph.is_touched(1, X), content="true")
  inspect(!engine.graphics.glyph.is_touched(1, Y), content="true")

  // Untouch both
  engine.graphics.freedom_vector = { x: 1, y: 1, }
  engine.value_stack.push(2) |> ignore
  engine.op_utp() |> ignore
  inspect(!engine.graphics.glyph.is_touched(2, X), content="true")
  inspect(!engine.graphics.glyph.is_touched(2, Y), content="true")
}

///|
test "tt_hint: outline SHP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.graphics.zp2 = Glyph
  engine.graphics.rp2 = 1
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1) |> ignore
  engine.op_shp(0) |> ignore
  let p = engine.graphics.glyph.point(1)
  inspect(p.x == 136 && p.y == -254, content="true")
}

///|
test "tt_hint: outline SHC" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.graphics.zp2 = Glyph
  engine.graphics.rp2 = 1
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(0) |> ignore
  engine.op_shc(0) |> ignore
  let p0 = engine.graphics.glyph.point(0)
  let p1 = engine.graphics.glyph.point(1)
  let p2 = engine.graphics.glyph.point(2)
  inspect(p0.x == 4 && p0.y == 2, content="true")
  inspect(p1.x == 132 && p1.y == -256, content="true")
  inspect(p2.x == 4 && p2.y == 2, content="true")
}

///|
test "tt_hint: outline SHZ" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.graphics.zp2 = Glyph
  engine.graphics.rp2 = 1
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(0) |> ignore
  engine.op_shz(0) |> ignore
  let q0 = engine.graphics.glyph.point(0)
  let q1 = engine.graphics.glyph.point(1)
  let q2 = engine.graphics.glyph.point(2)
  inspect(q0.x == 4 && q0.y == 2, content="true")
  inspect(q1.x == 132 && q1.y == -256, content="true")
  inspect(q2.x == 4 && q2.y == 2, content="true")
}

///|
test "tt_hint: outline SHPIX" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp2 = Glyph
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(42) |> ignore
  engine.op_shpix() |> ignore
  let r = engine.graphics.glyph.point(1)
  inspect(r.x == 170 && r.y == -237, content="true")
}

///|
test "tt_hint: outline MSIRP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.graphics.zp1 = Glyph
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(-42) |> ignore
  engine.op_msirp(0) |> ignore
  let p = engine.graphics.glyph.point(1)
  inspect(p.x == 91 && p.y == -277, content="true")
  inspect(engine.graphics.rp0 == 0, content="true")
  engine.value_stack.push(4) |> ignore
  engine.value_stack.push(0) |> ignore
  engine.op_msirp(1) |> ignore
  inspect(engine.graphics.rp0 == 4, content="true")
}

///|
test "tt_hint: outline MDAP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph

  // with rounding
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1) |> ignore
  engine.op_mdap(1) |> ignore
  let q = engine.graphics.glyph.point(1)
  inspect(q.x == 128 && q.y == -258, content="true")

  // without rounding
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2) |> ignore
  engine.op_mdap(0) |> ignore
  let q2 = engine.graphics.glyph.point(2)
  inspect(q2.x == 132 && q2.y == -256, content="true")
}

///|
test "tt_hint: outline MIAP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph

  // set CVT[1] = 0.75px = 48 in 26.6.
  engine.cvt.set(1, 48)

  // with rounding
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_miap(1) |> ignore
  let m = engine.graphics.glyph.point(1)
  inspect(m.x == 186 && m.y == -229, content="true")

  // without rounding
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_miap(0) |> ignore
  let m2 = engine.graphics.glyph.point(2)
  inspect(m2.x == 171 && m2.y == -236, content="true")
}

///|
test "tt_hint: outline MDRP rp0 bit" {
  let engine = tt_make_engine_for_outline()
  engine.graphics.rp0 = 0

  // Don't change rp0
  engine.value_stack.push(1) |> ignore
  engine.op_mdrp(0xC0) |> ignore
  inspect(engine.graphics.rp0 == 0, content="true")

  // Change rp0
  engine.value_stack.push(1) |> ignore
  engine.op_mdrp(0xD0) |> ignore
  inspect(engine.graphics.rp0 == 1, content="true")
}

///|
test "tt_hint: outline MDRP mindist bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph

  // without min distance check
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1) |> ignore
  engine.op_mdrp(0xC0) |> ignore
  let p1 = engine.graphics.glyph.point(1)
  inspect(p1.x == 128 && p1.y == -258, content="true")

  // with min distance check
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2) |> ignore
  engine.op_mdrp(0xC8) |> ignore
  let p2 = engine.graphics.glyph.point(2)
  inspect(p2.x == 186 && p2.y == -229, content="true")
}

///|
test "tt_hint: outline MDRP round bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.op_rthg() |> ignore

  // without rounding
  tt_set_point_for_outline(engine, 1, 132, -231)
  engine.value_stack.push(1) |> ignore
  engine.op_mdrp(0xC0) |> ignore
  let p3 = engine.graphics.glyph.point(1)
  inspect(p3.x == 119 && p3.y == -238, content="true")

  // with rounding
  tt_set_point_for_outline(engine, 2, 132, -231)
  engine.value_stack.push(2) |> ignore
  engine.op_mdrp(0xC4) |> ignore
  let p4 = engine.graphics.glyph.point(2)
  inspect(p4.x == 147 && p4.y == -223, content="true")
}

///|
test "tt_hint: outline MIRP rp0 bit" {
  let engine = tt_make_engine_for_outline()
  engine.graphics.rp0 = 0

  // Don't change rp0
  engine.value_stack.push(1) |> ignore // point
  engine.value_stack.push(1) |> ignore // cvt entry number
  engine.op_mirp(0xE0) |> ignore
  inspect(engine.graphics.rp0 == 0, content="true")

  // Change rp0
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_mirp(0xF0) |> ignore
  inspect(engine.graphics.rp0 == 1, content="true")
}

///|
test "tt_hint: outline MIRP mindist bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  // set CVT[1] = 0.75px
  engine.cvt.set(1, 48)

  // without min distance check
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_mirp(0xE0) |> ignore
  let p1 = engine.graphics.glyph.point(1)
  inspect(p1.x == 171 && p1.y == -236, content="true")

  // with min distance check
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_mirp(0xE8) |> ignore
  let p2 = engine.graphics.glyph.point(2)
  inspect(p2.x == 186 && p2.y == -229, content="true")
}

///|
test "tt_hint: outline MIRP round bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  // set CVT[1] = 0.75px
  engine.cvt.set(1, 48)
  engine.op_rthg() |> ignore

  // without rounding
  tt_set_point_for_outline(engine, 1, 132, -231)
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_mirp(0xE0) |> ignore
  let p3 = engine.graphics.glyph.point(1)
  inspect(p3.x == 162 && p3.y == -216, content="true")

  // with rounding
  tt_set_point_for_outline(engine, 2, 132, -231)
  engine.value_stack.push(2) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_mirp(0xE4) |> ignore
  let p4 = engine.graphics.glyph.point(2)
  inspect(p4.x == 147 && p4.y == -223, content="true")
}

///|
test "tt_hint: outline ALIGNRP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.graphics.zp1 = Glyph
  engine.graphics.rp0 = 0
  tt_set_point_for_outline(engine, 0, 132, -231)
  tt_set_point_for_outline(engine, 1, -72, 109)
  engine.value_stack.push(1) |> ignore
  engine.op_alignrp() |> ignore
  let ar = engine.graphics.glyph.point(1)
  inspect(ar.x == -45 && ar.y == 122, content="true")
}

///|
test "tt_hint: outline ISECT" {
  let engine = tt_make_engine_for_outline()
  engine.graphics.zp0 = Glyph
  engine.graphics.zp1 = Glyph
  engine.graphics.rp0 = 0

  // Two points for line 1
  tt_set_point_for_outline(engine, 0, 0, 0)
  tt_set_point_for_outline(engine, 1, 100, 100)
  // And two more for line 2
  tt_set_point_for_outline(engine, 2, 0, 100)
  tt_set_point_for_outline(engine, 3, 100, 0)
  // Push point numbers: first is the point where the intersection should be stored.
  for ix in [4, 0, 1, 2, 3] {
    engine.value_stack.push(ix) |> ignore
  }
  engine.op_isect() |> ignore
  let ipt = engine.graphics.glyph.point(4)
  inspect(ipt.x == 50 && ipt.y == 50, content="true")
}

///|
test "tt_hint: outline ALIGNPTS" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.graphics.zp1 = Glyph
  tt_set_point_for_outline(engine, 0, 132, -231)
  tt_set_point_for_outline(engine, 1, -72, 109)
  engine.value_stack.push(0) |> ignore
  engine.value_stack.push(1) |> ignore
  engine.op_alignpts() |> ignore
  let ap0 = engine.graphics.glyph.point(0)
  let ap1 = engine.graphics.glyph.point(1)
  inspect(ap0.x == 119 && ap0.y == -238, content="true")
  inspect(ap1.x == -59 && ap1.y == 116, content="true")
}

///|
test "tt_hint: outline IP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = Glyph
  engine.graphics.zp1 = Glyph
  engine.graphics.zp2 = Glyph
  engine.graphics.rp1 = 2
  engine.graphics.rp2 = 3
  tt_set_point_for_outline(engine, 2, 72, -109)
  tt_set_point_for_outline(engine, 1, 132, -231)
  engine.value_stack.push(1) |> ignore
  engine.op_ip() |> ignore
  let ip_p = engine.graphics.glyph.point(1)
  inspect(ip_p.x == 147 && ip_p.y == -223, content="true")
}

///|
test "tt_hint: outline IUP flags" {
  let engine = tt_make_engine_for_outline()
  inspect(!engine.graphics.did_iup_x, content="true")
  inspect(!engine.graphics.did_iup_y, content="true")

  // IUP[y]
  engine.op_iup(0) |> ignore
  inspect(!engine.graphics.did_iup_x, content="true")
  inspect(engine.graphics.did_iup_y, content="true")

  // IUP[x]
  engine.op_iup(1) |> ignore
  inspect(engine.graphics.did_iup_x, content="true")
  inspect(engine.graphics.did_iup_y, content="true")
}

///|
test "tt_hint: outline FLIP region avoid overflow" {
  let engine = tt_make_engine_for_outline()
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(-1) |> ignore
  try engine.set_on_curve_for_range(true) catch {
    InvalidStackValue(-1) => ()
    _ => fail("expected InvalidStackValue(-1)")
  } noraise {
    _ => fail("expected InvalidStackValue(-1)")
  }
}
