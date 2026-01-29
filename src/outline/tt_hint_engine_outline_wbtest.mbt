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
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::default()
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let engine = TtEngine::new(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::make(16, 0),
    Array::make(16, 0),
    Some(32),
    0,
    coords0.op_as_view(),
    64,
    32,
    64,
    64,
  )

  // Mirror fontations MockEngine zone shape + unscaled point pattern.
  let unscaled : Array[TtPoint] = Array::make(32, TtPoint::{ x: 0, y: 0 })
  for i in 0..<32 {
    let x = 57 + i * 2
    unscaled.set(i, TtPoint::{ x, y: -x * 3 })
  }
  engine.graphics.glyph = TtZone::{
    unscaled,
    original: Array::make(32, TtPoint::{ x: 0, y: 0 }),
    points: Array::make(32, TtPoint::{ x: 0, y: 0 }),
    flags: Array::make(32, 0),
    contours: Array::from_fixed_array([31]),
  }
  engine.graphics.twilight = TtZone::{
    unscaled: Array::new(),
    original: Array::make(16, TtPoint::{ x: 0, y: 0 }),
    points: Array::make(16, TtPoint::{ x: 0, y: 0 }),
    flags: Array::make(16, 0),
    contours: Array::new(),
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
  let v = TtVec14::{ x, y }
  engine.graphics.proj_vector = v
  engine.graphics.dual_proj_vector = v
  engine.graphics.freedom_vector = v
  engine.graphics.update_projection_state()
}

///|
fn tt_set_point_for_outline(
  engine : TtEngine,
  point_ix : Int,
  x : Int,
  y : Int,
) -> Unit {
  engine.graphics.glyph.points.set(point_ix, TtPoint::{ x, y })
}

///|
test "tt_hint: outline FLIPPT" {
  let engine = tt_make_engine_for_outline()
  let count = 5
  engine.value_stack.push(count).unwrap() |> ignore
  engine.op_sloop().unwrap() |> ignore
  for i in 1..<10 {
    if (i & 1) != 0 {
      engine.value_stack.push(i).unwrap() |> ignore
    }
  }
  inspect(engine.value_stack.length() == count, content="true")
  engine.op_flippt().unwrap() |> ignore
  for i in 0..<10 {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(on_curve == ((i & 1) != 0), content="true")
  }
}

///|
test "tt_hint: outline backward compat + IUP prevents FLIPPT" {
  let engine = tt_make_engine_for_outline()
  let count = 5
  engine.value_stack.push(count).unwrap() |> ignore
  engine.op_sloop().unwrap() |> ignore
  for i in 1..<10 {
    if (i & 1) != 0 {
      engine.value_stack.push(i).unwrap() |> ignore
    }
  }
  engine.graphics.backward_compatibility = true
  engine.graphics.did_iup_x = true
  engine.graphics.did_iup_y = true
  engine.op_flippt().unwrap() |> ignore
  for i in 0..<10 {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(!on_curve, content="true")
  }
}

///|
test "tt_hint: outline FLIPRGON/FLIPRGOFF" {
  let engine = tt_make_engine_for_outline()
  // Flip 10..=20 on.
  engine.value_stack.push(10).unwrap() |> ignore
  engine.value_stack.push(20).unwrap() |> ignore
  engine.op_fliprgon().unwrap() |> ignore
  for i in 0..<engine.graphics.glyph.flags.length() {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(on_curve == (i >= 10 && i <= 20), content="true")
  }
  // Flip 12..=15 off.
  engine.value_stack.push(12).unwrap() |> ignore
  engine.value_stack.push(15).unwrap() |> ignore
  engine.op_fliprgoff().unwrap() |> ignore
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
  engine.value_stack.push(10).unwrap() |> ignore
  engine.value_stack.push(20).unwrap() |> ignore
  engine.op_fliprgon().unwrap() |> ignore
  for i in 0..<engine.graphics.glyph.flags.length() {
    let on_curve = (engine.graphics.glyph.flags.at(i) & 1) != 0
    inspect(!on_curve, content="true")
  }

  // Reset all points to on-curve.
  for i in 0..<engine.graphics.glyph.flags.length() {
    engine.graphics.glyph.flags.set(i, engine.graphics.glyph.flags.at(i) | 1)
  }
  engine.value_stack.push(12).unwrap() |> ignore
  engine.value_stack.push(15).unwrap() |> ignore
  engine.op_fliprgoff().unwrap() |> ignore
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
    engine.graphics.glyph.touch(i, TtAxis::X).unwrap() |> ignore
    engine.graphics.glyph.touch(i, TtAxis::Y).unwrap() |> ignore
  }

  // Untouch x
  inspect(
    engine.graphics.glyph.is_touched(0, TtAxis::X).unwrap(),
    content="true",
  )
  engine.graphics.freedom_vector = TtVec14::{ x: 1, y: 0 }
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_utp().unwrap() |> ignore
  inspect(
    !engine.graphics.glyph.is_touched(0, TtAxis::X).unwrap(),
    content="true",
  )
  inspect(
    engine.graphics.glyph.is_touched(0, TtAxis::Y).unwrap(),
    content="true",
  )

  // Untouch y
  inspect(
    engine.graphics.glyph.is_touched(1, TtAxis::Y).unwrap(),
    content="true",
  )
  engine.graphics.freedom_vector = TtVec14::{ x: 0, y: 1 }
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_utp().unwrap() |> ignore
  inspect(
    engine.graphics.glyph.is_touched(1, TtAxis::X).unwrap(),
    content="true",
  )
  inspect(
    !engine.graphics.glyph.is_touched(1, TtAxis::Y).unwrap(),
    content="true",
  )

  // Untouch both
  engine.graphics.freedom_vector = TtVec14::{ x: 1, y: 1 }
  engine.value_stack.push(2).unwrap() |> ignore
  engine.op_utp().unwrap() |> ignore
  inspect(
    !engine.graphics.glyph.is_touched(2, TtAxis::X).unwrap(),
    content="true",
  )
  inspect(
    !engine.graphics.glyph.is_touched(2, TtAxis::Y).unwrap(),
    content="true",
  )
}

///|
test "tt_hint: outline SHP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp2 = TtZonePointer::Glyph
  engine.graphics.rp2 = 1
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_shp(0).unwrap() |> ignore
  let p = engine.graphics.glyph.point(1).unwrap()
  inspect(p.x == 136 && p.y == -254, content="true")
}

///|
test "tt_hint: outline SHC" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp2 = TtZonePointer::Glyph
  engine.graphics.rp2 = 1
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_shc(0).unwrap() |> ignore
  let p0 = engine.graphics.glyph.point(0).unwrap()
  let p1 = engine.graphics.glyph.point(1).unwrap()
  let p2 = engine.graphics.glyph.point(2).unwrap()
  inspect(p0.x == 4 && p0.y == 2, content="true")
  inspect(p1.x == 132 && p1.y == -256, content="true")
  inspect(p2.x == 4 && p2.y == 2, content="true")
}

///|
test "tt_hint: outline SHZ" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp2 = TtZonePointer::Glyph
  engine.graphics.rp2 = 1
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_shz(0).unwrap() |> ignore
  let q0 = engine.graphics.glyph.point(0).unwrap()
  let q1 = engine.graphics.glyph.point(1).unwrap()
  let q2 = engine.graphics.glyph.point(2).unwrap()
  inspect(q0.x == 4 && q0.y == 2, content="true")
  inspect(q1.x == 132 && q1.y == -256, content="true")
  inspect(q2.x == 4 && q2.y == 2, content="true")
}

///|
test "tt_hint: outline SHPIX" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp2 = TtZonePointer::Glyph
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(42).unwrap() |> ignore
  engine.op_shpix().unwrap() |> ignore
  let r = engine.graphics.glyph.point(1).unwrap()
  inspect(r.x == 170 && r.y == -237, content="true")
}

///|
test "tt_hint: outline MSIRP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp1 = TtZonePointer::Glyph
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(-42).unwrap() |> ignore
  engine.op_msirp(0).unwrap() |> ignore
  let p = engine.graphics.glyph.point(1).unwrap()
  inspect(p.x == 91 && p.y == -277, content="true")
  inspect(engine.graphics.rp0 == 0, content="true")
  engine.value_stack.push(4).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_msirp(1).unwrap() |> ignore
  inspect(engine.graphics.rp0 == 4, content="true")
}

///|
test "tt_hint: outline MDAP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph

  // with rounding
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mdap(1).unwrap() |> ignore
  let q = engine.graphics.glyph.point(1).unwrap()
  inspect(q.x == 128 && q.y == -258, content="true")

  // without rounding
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2).unwrap() |> ignore
  engine.op_mdap(0).unwrap() |> ignore
  let q2 = engine.graphics.glyph.point(2).unwrap()
  inspect(q2.x == 132 && q2.y == -256, content="true")
}

///|
test "tt_hint: outline MIAP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph

  // set CVT[1] = 0.75px = 48 in 26.6.
  engine.cvt.set(1, 48)

  // with rounding
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_miap(1).unwrap() |> ignore
  let m = engine.graphics.glyph.point(1).unwrap()
  inspect(m.x == 186 && m.y == -229, content="true")

  // without rounding
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_miap(0).unwrap() |> ignore
  let m2 = engine.graphics.glyph.point(2).unwrap()
  inspect(m2.x == 171 && m2.y == -236, content="true")
}

///|
test "tt_hint: outline MDRP rp0 bit" {
  let engine = tt_make_engine_for_outline()
  engine.graphics.rp0 = 0

  // Don't change rp0
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mdrp(0xC0).unwrap() |> ignore
  inspect(engine.graphics.rp0 == 0, content="true")

  // Change rp0
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mdrp(0xD0).unwrap() |> ignore
  inspect(engine.graphics.rp0 == 1, content="true")
}

///|
test "tt_hint: outline MDRP mindist bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph

  // without min distance check
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mdrp(0xC0).unwrap() |> ignore
  let p1 = engine.graphics.glyph.point(1).unwrap()
  inspect(p1.x == 128 && p1.y == -258, content="true")

  // with min distance check
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2).unwrap() |> ignore
  engine.op_mdrp(0xC8).unwrap() |> ignore
  let p2 = engine.graphics.glyph.point(2).unwrap()
  inspect(p2.x == 186 && p2.y == -229, content="true")
}

///|
test "tt_hint: outline MDRP round bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.op_rthg().unwrap() |> ignore

  // without rounding
  tt_set_point_for_outline(engine, 1, 132, -231)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mdrp(0xC0).unwrap() |> ignore
  let p3 = engine.graphics.glyph.point(1).unwrap()
  inspect(p3.x == 119 && p3.y == -238, content="true")

  // with rounding
  tt_set_point_for_outline(engine, 2, 132, -231)
  engine.value_stack.push(2).unwrap() |> ignore
  engine.op_mdrp(0xC4).unwrap() |> ignore
  let p4 = engine.graphics.glyph.point(2).unwrap()
  inspect(p4.x == 147 && p4.y == -223, content="true")
}

///|
test "tt_hint: outline MIRP rp0 bit" {
  let engine = tt_make_engine_for_outline()
  engine.graphics.rp0 = 0

  // Don't change rp0
  engine.value_stack.push(1).unwrap() |> ignore // point
  engine.value_stack.push(1).unwrap() |> ignore // cvt entry number
  engine.op_mirp(0xE0).unwrap() |> ignore
  inspect(engine.graphics.rp0 == 0, content="true")

  // Change rp0
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mirp(0xF0).unwrap() |> ignore
  inspect(engine.graphics.rp0 == 1, content="true")
}

///|
test "tt_hint: outline MIRP mindist bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  // set CVT[1] = 0.75px
  engine.cvt.set(1, 48)

  // without min distance check
  tt_set_point_for_outline(engine, 1, 132, -256)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mirp(0xE0).unwrap() |> ignore
  let p1 = engine.graphics.glyph.point(1).unwrap()
  inspect(p1.x == 171 && p1.y == -236, content="true")

  // with min distance check
  tt_set_point_for_outline(engine, 2, 132, -256)
  engine.value_stack.push(2).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mirp(0xE8).unwrap() |> ignore
  let p2 = engine.graphics.glyph.point(2).unwrap()
  inspect(p2.x == 186 && p2.y == -229, content="true")
}

///|
test "tt_hint: outline MIRP round bit" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  // set CVT[1] = 0.75px
  engine.cvt.set(1, 48)
  engine.op_rthg().unwrap() |> ignore

  // without rounding
  tt_set_point_for_outline(engine, 1, 132, -231)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mirp(0xE0).unwrap() |> ignore
  let p3 = engine.graphics.glyph.point(1).unwrap()
  inspect(p3.x == 162 && p3.y == -216, content="true")

  // with rounding
  tt_set_point_for_outline(engine, 2, 132, -231)
  engine.value_stack.push(2).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_mirp(0xE4).unwrap() |> ignore
  let p4 = engine.graphics.glyph.point(2).unwrap()
  inspect(p4.x == 147 && p4.y == -223, content="true")
}

///|
test "tt_hint: outline ALIGNRP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp1 = TtZonePointer::Glyph
  engine.graphics.rp0 = 0
  tt_set_point_for_outline(engine, 0, 132, -231)
  tt_set_point_for_outline(engine, 1, -72, 109)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_alignrp().unwrap() |> ignore
  let ar = engine.graphics.glyph.point(1).unwrap()
  inspect(ar.x == -45 && ar.y == 122, content="true")
}

///|
test "tt_hint: outline ISECT" {
  let engine = tt_make_engine_for_outline()
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp1 = TtZonePointer::Glyph
  engine.graphics.rp0 = 0

  // Two points for line 1
  tt_set_point_for_outline(engine, 0, 0, 0)
  tt_set_point_for_outline(engine, 1, 100, 100)
  // And two more for line 2
  tt_set_point_for_outline(engine, 2, 0, 100)
  tt_set_point_for_outline(engine, 3, 100, 0)
  // Push point numbers: first is the point where the intersection should be stored.
  for ix in [4, 0, 1, 2, 3] {
    engine.value_stack.push(ix).unwrap() |> ignore
  }
  engine.op_isect().unwrap() |> ignore
  let ipt = engine.graphics.glyph.point(4).unwrap()
  inspect(ipt.x == 50 && ipt.y == 50, content="true")
}

///|
test "tt_hint: outline ALIGNPTS" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp1 = TtZonePointer::Glyph
  tt_set_point_for_outline(engine, 0, 132, -231)
  tt_set_point_for_outline(engine, 1, -72, 109)
  engine.value_stack.push(0).unwrap() |> ignore
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_alignpts().unwrap() |> ignore
  let ap0 = engine.graphics.glyph.point(0).unwrap()
  let ap1 = engine.graphics.glyph.point(1).unwrap()
  inspect(ap0.x == 119 && ap0.y == -238, content="true")
  inspect(ap1.x == -59 && ap1.y == 116, content="true")
}

///|
test "tt_hint: outline IP" {
  let engine = tt_make_engine_for_outline()
  tt_set_test_vectors_for_outline(engine)
  engine.graphics.backward_compatibility = false
  engine.graphics.zp0 = TtZonePointer::Glyph
  engine.graphics.zp1 = TtZonePointer::Glyph
  engine.graphics.zp2 = TtZonePointer::Glyph
  engine.graphics.rp1 = 2
  engine.graphics.rp2 = 3
  tt_set_point_for_outline(engine, 2, 72, -109)
  tt_set_point_for_outline(engine, 1, 132, -231)
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_ip().unwrap() |> ignore
  let ip_p = engine.graphics.glyph.point(1).unwrap()
  inspect(ip_p.x == 147 && ip_p.y == -223, content="true")
}

///|
test "tt_hint: outline IUP flags" {
  let engine = tt_make_engine_for_outline()
  inspect(!engine.graphics.did_iup_x, content="true")
  inspect(!engine.graphics.did_iup_y, content="true")

  // IUP[y]
  engine.op_iup(0).unwrap() |> ignore
  inspect(!engine.graphics.did_iup_x, content="true")
  inspect(engine.graphics.did_iup_y, content="true")

  // IUP[x]
  engine.op_iup(1).unwrap() |> ignore
  inspect(engine.graphics.did_iup_x, content="true")
  inspect(engine.graphics.did_iup_y, content="true")
}

///|
test "tt_hint: outline FLIP region avoid overflow" {
  let engine = tt_make_engine_for_outline()
  engine.value_stack.push(1).unwrap() |> ignore
  engine.value_stack.push(-1).unwrap() |> ignore
  engine.set_on_curve_for_range(true) |> ignore
}
