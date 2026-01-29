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
fn tt_vec14_normalize(x : Int, y : Int) -> TtVec14 {
  let (nx, ny) = tt_hint_normalize14(x, y)
  TtVec14::{ x: nx, y: ny }
}

///|
test "tt_hint: projection one axis" {
  let state = TtGraphicsState::default()
  state.proj_vector = tt_vec14_normalize(1, 0)
  state.update_projection_state()
  inspect(state.proj_axis is TtCoordAxis::X, content="true")
  inspect(
    state.proj_vector.x == 0x4000 && state.proj_vector.y == 0,
    content="true",
  )
  let cases : Array[(TtPoint, TtPoint, Int)] = Array::from_fixed_array([
    (TtPoint::{ x: 0, y: 0 }, TtPoint::{ x: 0, y: 0 }, 0),
    (TtPoint::{ x: 100, y: 100 }, TtPoint::{ x: 0, y: 0 }, 100),
    (TtPoint::{ x: 42, y: 100 }, TtPoint::{ x: 100, y: 0 }, -58),
    (TtPoint::{ x: 0, y: 0 }, TtPoint::{ x: 100, y: 100 }, -100),
  ])
  for entry in cases.iter() {
    let (p1, p2, expected) = entry
    let got = state.project(p1, p2)
    inspect(got == expected, content="true")
  }
}

///|
test "tt_hint: projection both axes" {
  let state = TtGraphicsState::default()
  state.proj_vector = tt_vec14_normalize(0x4000, 0x4000)
  state.update_projection_state()
  inspect(state.proj_axis is TtCoordAxis::Both, content="true")
  let cases : Array[(TtPoint, TtPoint, Int)] = Array::from_fixed_array([
    (TtPoint::{ x: 0, y: 0 }, TtPoint::{ x: 0, y: 0 }, 0),
    (TtPoint::{ x: 100, y: 100 }, TtPoint::{ x: 0, y: 0 }, 141),
    (TtPoint::{ x: 42, y: 100 }, TtPoint::{ x: 100, y: 0 }, 30),
    (TtPoint::{ x: 0, y: 0 }, TtPoint::{ x: 100, y: 100 }, -141),
  ])
  for entry in cases.iter() {
    let (p1, p2, expected) = entry
    let got = state.project(p1, p2)
    inspect(got == expected, content="true")
  }
}
