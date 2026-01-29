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
fn tt_points_equal(zone : TtZone, expected : FixedArray[TtPoint]) -> Bool {
  let n = expected.length()
  if zone.points.length() != n {
    return false
  }
  for i in 0..<n {
    let got = zone.points.at(i)
    let exp = expected[i]
    if got.x != exp.x || got.y != exp.y {
      return false
    }
  }
  true
}

///|
test "tt_hint: zone flip_on_curve point" {
  let on = TT_POINT_ON_CURVE
  let off = 0
  let zone = TtZone::{
    unscaled: Array::new(),
    original: Array::new(),
    points: Array::make(4, TtPoint::{ x: 0, y: 0 }),
    flags: Array::from_fixed_array([on, off, off, on]),
    contours: Array::new(),
  }
  for i in 0..<4 {
    zone.flip_on_curve(i).unwrap() |> ignore
  }
  inspect(zone.flags.at(0) == off, content="true")
  inspect(zone.flags.at(1) == on, content="true")
  inspect(zone.flags.at(2) == on, content="true")
  inspect(zone.flags.at(3) == off, content="true")
}

///|
test "tt_hint: zone set_on_curve regions" {
  let on = TT_POINT_ON_CURVE
  let off = 0
  let zone = TtZone::{
    unscaled: Array::new(),
    original: Array::new(),
    points: Array::make(4, TtPoint::{ x: 0, y: 0 }),
    flags: Array::from_fixed_array([on, off, off, on]),
    contours: Array::new(),
  }
  zone.set_on_curve(0, 2, true).unwrap() |> ignore
  zone.set_on_curve(2, 4, false).unwrap() |> ignore
  inspect(zone.flags.at(0) == on, content="true")
  inspect(zone.flags.at(1) == on, content="true")
  inspect(zone.flags.at(2) == off, content="true")
  inspect(zone.flags.at(3) == off, content="true")
}

///|
test "tt_hint: zone iup shift" {
  let untouched = 0
  let touched = TT_POINT_TOUCHED_X | TT_POINT_TOUCHED_Y
  let original = Array::from_fixed_array([
    TtPoint::{ x: 0, y: 0 },
    TtPoint::{ x: 10, y: 10 },
    TtPoint::{ x: 20, y: 20 },
  ])
  let points = Array::from_fixed_array([
    TtPoint::{ x: -5, y: -20 },
    TtPoint::{ x: 10, y: 10 },
    TtPoint::{ x: 20, y: 20 },
  ])
  let zone = TtZone::{
    unscaled: Array::new(),
    original,
    points,
    contours: Array::from_fixed_array([3]),
    flags: Array::from_fixed_array([touched, untouched, untouched]),
  }
  zone.iup(TtAxis::X).unwrap() |> ignore
  inspect(
    tt_points_equal(zone, [
      TtPoint::{ x: -5, y: -20 },
      TtPoint::{ x: 5, y: 10 },
      TtPoint::{ x: 15, y: 20 },
    ]),
    content="true",
  )
  zone.iup(TtAxis::Y).unwrap() |> ignore
  inspect(
    tt_points_equal(zone, [
      TtPoint::{ x: -5, y: -20 },
      TtPoint::{ x: 5, y: -10 },
      TtPoint::{ x: 15, y: 0 },
    ]),
    content="true",
  )
}

///|
test "tt_hint: zone iup interpolate" {
  let untouched = 0
  let touched = TT_POINT_TOUCHED_X | TT_POINT_TOUCHED_Y
  let unscaled = Array::from_fixed_array([
    TtPoint::{ x: 0, y: 0 },
    TtPoint::{ x: 500, y: 500 },
    TtPoint::{ x: 1000, y: 1000 },
  ])
  let original = Array::from_fixed_array([
    TtPoint::{ x: 0, y: 0 },
    TtPoint::{ x: 10, y: 10 },
    TtPoint::{ x: 20, y: 20 },
  ])
  let points = Array::from_fixed_array([
    TtPoint::{ x: -5, y: -20 },
    TtPoint::{ x: 10, y: 10 },
    TtPoint::{ x: 27, y: 56 },
  ])
  let zone = TtZone::{
    unscaled,
    original,
    points,
    contours: Array::from_fixed_array([3]),
    flags: Array::from_fixed_array([touched, untouched, touched]),
  }
  zone.iup(TtAxis::X).unwrap() |> ignore
  inspect(
    tt_points_equal(zone, [
      TtPoint::{ x: -5, y: -20 },
      TtPoint::{ x: 11, y: 10 },
      TtPoint::{ x: 27, y: 56 },
    ]),
    content="true",
  )
  zone.iup(TtAxis::Y).unwrap() |> ignore
  inspect(
    tt_points_equal(zone, [
      TtPoint::{ x: -5, y: -20 },
      TtPoint::{ x: 11, y: 18 },
      TtPoint::{ x: 27, y: 56 },
    ]),
    content="true",
  )
}
