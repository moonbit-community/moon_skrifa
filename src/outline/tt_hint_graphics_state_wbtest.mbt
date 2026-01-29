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
fn tt_make_mock_gs(fv_x : Int, fv_y : Int) -> TtGraphicsState {
  let points = Array::from_fixed_array([
    TtPoint::{ x: -5, y: -20 },
    TtPoint::{ x: 10, y: 10 },
    TtPoint::{ x: 20, y: 20 },
  ])
  let original = Array::from_fixed_array([
    TtPoint::{ x: 0, y: 0 },
    TtPoint::{ x: 10, y: 10 },
    TtPoint::{ x: 20, y: -42 },
  ])
  let flags = Array::make(3, 0)
  let glyph = TtZone::{
    unscaled: Array::new(),
    original,
    points,
    flags,
    contours: Array::from_fixed_array([3]),
  }
  let gs = TtGraphicsState::default()
  let (nx, ny) = tt_hint_normalize14(fv_x, fv_y)
  gs.freedom_vector = TtVec14::{ x: nx, y: ny }
  gs.proj_vector = TtVec14::{ x: nx, y: ny }
  gs.zp0 = TtZonePointer::Glyph
  gs.zp1 = TtZonePointer::Glyph
  gs.zp2 = TtZonePointer::Glyph
  gs.glyph = glyph
  gs.update_projection_state()
  gs
}

///|
test "tt_hint: graphics move_point x" {
  let gs = tt_make_mock_gs(100, 0)
  let orig_x = gs.glyph.point(0).unwrap().x
  let dx = 10
  // backward compatibility is on by default: x movement is blocked.
  gs.move_point(TtZonePointer::Glyph, 0, dx).unwrap() |> ignore
  inspect(gs.glyph.point(0).unwrap().x == orig_x, content="true")
  // disable and retry
  gs.backward_compatibility = false
  gs.move_point(TtZonePointer::Glyph, 0, dx).unwrap() |> ignore
  inspect(gs.glyph.point(0).unwrap().x == orig_x + dx, content="true")
}

///|
test "tt_hint: graphics move_point y" {
  let gs = tt_make_mock_gs(0, 100)
  let orig_y = gs.glyph.point(0).unwrap().y
  let dy = 10
  // movement in y is prevented post-iup when backward compatibility is enabled
  gs.did_iup_x = true
  gs.did_iup_y = true
  gs.move_point(TtZonePointer::Glyph, 0, dy).unwrap() |> ignore
  inspect(gs.glyph.point(0).unwrap().y == orig_y, content="true")
  // allow movement
  gs.did_iup_x = false
  gs.did_iup_y = false
  gs.move_point(TtZonePointer::Glyph, 0, dy).unwrap() |> ignore
  inspect(gs.glyph.point(0).unwrap().y == orig_y + dy, content="true")
}

///|
test "tt_hint: graphics move_point x and y" {
  let gs = tt_make_mock_gs(100, 50)
  let orig = gs.glyph.point(0).unwrap()
  let dist = 10
  // prevent movement in x and y
  gs.did_iup_x = true
  gs.did_iup_y = true
  gs.move_point(TtZonePointer::Glyph, 0, dist).unwrap() |> ignore
  inspect(gs.glyph.point(0).unwrap().x == orig.x, content="true")
  inspect(gs.glyph.point(0).unwrap().y == orig.y, content="true")
  // allow movement
  gs.backward_compatibility = false
  gs.did_iup_x = false
  gs.did_iup_y = false
  gs.move_point(TtZonePointer::Glyph, 0, dist).unwrap() |> ignore
  let p = gs.glyph.point(0).unwrap()
  inspect(p.x == 4 && p.y == -16, content="true")
}

///|
test "tt_hint: graphics move_zp2_point" {
  let gs = tt_make_mock_gs(100, 50)
  gs.zp2 = TtZonePointer::Glyph
  let point_ix = 0
  let orig = gs.glyph.point(point_ix).unwrap()
  let dx = 10
  let dy = -10
  // prevent movement in x and y
  gs.did_iup_x = true
  gs.did_iup_y = true
  gs.move_zp2_point(point_ix, dx, dy, false).unwrap() |> ignore
  inspect(gs.glyph.point(point_ix).unwrap().x == orig.x, content="true")
  inspect(gs.glyph.point(point_ix).unwrap().y == orig.y, content="true")
  // allow movement
  gs.backward_compatibility = false
  gs.did_iup_x = false
  gs.did_iup_y = false
  gs.move_zp2_point(point_ix, dx, dy, false).unwrap() |> ignore
  let p = gs.glyph.point(point_ix).unwrap()
  inspect(p.x == orig.x + dx && p.y == orig.y + dy, content="true")
}

///|
test "tt_hint: graphics point displacement" {
  let gs = tt_make_mock_gs(100, 50)
  gs.zp0 = TtZonePointer::Glyph
  gs.rp1 = 0
  let d0 = gs.point_displacement(1).unwrap()
  inspect(d0.zone is TtZonePointer::Glyph, content="true")
  inspect(d0.point_ix == 0, content="true")
  inspect(d0.dx == -12 && d0.dy == -6, content="true")
  gs.rp2 = 2
  let d1 = gs.point_displacement(0).unwrap()
  inspect(d1.zone is TtZonePointer::Glyph, content="true")
  inspect(d1.point_ix == 2, content="true")
  inspect(d1.dx == 25 && d1.dy == 13, content="true")
}
