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
/// Glyph zones for TrueType hinting.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/zone.rs` (Apache-2.0 OR MIT).
priv struct TtPoint {
  x : Int32
  y : Int32
}

///|
priv enum TtZonePointer {
  Twilight
  Glyph
}

///|
impl Eq for TtZonePointer with fn equal(a, b) {
  match (a, b) {
    (Twilight, Twilight) => true
    (Glyph, Glyph) => true
    _ => false
  }
}

///|
fn TtZonePointer::default() -> TtZonePointer {
  Glyph
}

///|
fn TtZonePointer::is_twilight(self : TtZonePointer) -> Bool {
  self is Twilight
}

///|
fn tt_zone_pointer_from_i32(value : Int32) -> TtZonePointer raise HintError {
  match value {
    0 => Twilight
    1 => Glyph
    _ => raise InvalidZoneIndex(value)
  }
}

///|
const TT_POINT_ON_CURVE : Int32 = 1

///|
const TT_POINT_TOUCHED_X : Int32 = 2

///|
const TT_POINT_TOUCHED_Y : Int32 = 4

///|
priv enum TtAxis {
  X
  Y
}

///|
fn TtAxis::touched_mask(self : TtAxis) -> Int32 {
  match self {
    X => TT_POINT_TOUCHED_X
    Y => TT_POINT_TOUCHED_Y
  }
}

///|
priv struct TtZone {
  /// Unscaled points in font units. For twilight this can be empty.
  unscaled : Array[TtPoint]
  /// Scaled outline points prior to executing instructions.
  original : Array[TtPoint]
  /// Current scaled outline points.
  points : Array[TtPoint]
  flags : Array[Int32]
  contours : Array[Int32]
}

///|
fn TtZone::default() -> TtZone {
  { unscaled: [], original: [], points: [], flags: [], contours: [], }
}

///|
fn TtZone::point(self : TtZone, index : Int32) -> TtPoint raise HintError {
  if index < 0 || index >= self.points.length() {
    raise InvalidPointIndex(index)
  } else {
    self.points.at(index)
  }
}

///|
fn TtZone::set_point(
  self : TtZone,
  index : Int32,
  p : TtPoint,
) -> Unit raise HintError {
  if index < 0 || index >= self.points.length() {
    raise InvalidPointIndex(index)
  } else {
    self.points.set(index, p)
    ()
  }
}

///|
fn TtZone::original_point(
  self : TtZone,
  index : Int32,
) -> TtPoint raise HintError {
  if index < 0 || index >= self.original.length() {
    raise InvalidPointIndex(index)
  } else {
    self.original.at(index)
  }
}

///|
fn TtZone::set_original_point(
  self : TtZone,
  index : Int32,
  p : TtPoint,
) -> Unit raise HintError {
  if index < 0 || index >= self.original.length() {
    raise InvalidPointIndex(index)
  } else {
    self.original.set(index, p)
    ()
  }
}

///|
fn TtZone::unscaled_point(self : TtZone, index : Int32) -> TtPoint {
  if index < 0 || index >= self.unscaled.length() {
    // Twilight unscaled points default to (0,0).
    { x: 0, y: 0, }
  } else {
    self.unscaled.at(index)
  }
}

///|
fn TtZone::contour_end(self : TtZone, index : Int32) -> Int32 raise HintError {
  if index < 0 || index >= self.contours.length() {
    raise InvalidStackValue(index)
  } else {
    self.contours.at(index)
  }
}

///|
fn TtZone::touch(
  self : TtZone,
  index : Int32,
  axis : TtAxis,
) -> Unit raise HintError {
  if index < 0 || index >= self.flags.length() {
    raise InvalidPointIndex(index)
  }
  self.flags.set(index, self.flags.at(index) | axis.touched_mask())
  ()
}

///|

///|
fn TtZone::is_touched(
  self : TtZone,
  index : Int32,
  axis : TtAxis,
) -> Bool raise HintError {
  if index < 0 || index >= self.flags.length() {
    raise InvalidPointIndex(index)
  } else {
    (self.flags.at(index) & axis.touched_mask()) != 0
  }
}

///|
fn TtZone::untouch(
  self : TtZone,
  index : Int32,
  axis : TtAxis,
) -> Unit raise HintError {
  if index < 0 || index >= self.flags.length() {
    raise InvalidPointIndex(index)
  }
  self.flags.set(index, self.flags.at(index) & (axis.touched_mask() ^ -1))
  ()
}

///|
fn TtZone::flip_on_curve(self : TtZone, index : Int32) -> Unit raise HintError {
  if index < 0 || index >= self.flags.length() {
    raise InvalidPointIndex(index)
  }
  self.flags.set(index, self.flags.at(index) ^ TT_POINT_ON_CURVE)
  ()
}

///|
fn TtZone::set_on_curve(
  self : TtZone,
  start : Int32,
  end_ : Int32,
  on : Bool,
) -> Unit raise HintError {
  if start < 0 || end_ < start || end_ > self.flags.length() {
    raise InvalidPointRange(start, end_)
  }
  let mask = TT_POINT_ON_CURVE
  for i in start..<end_ {
    let f = self.flags.at(i)
    self.flags.set(i, if on { f | mask } else { f & (mask ^ -1) })
  }
  ()
}

///|

///|

///|
/// Interpolate untouched points (IUP).
fn TtZone::iup(self : TtZone, axis : TtAxis) -> Unit raise HintError {
  let mut point = 0
  for i in 0..<self.contours.length() {
    let mut end_point = self.contour_end(i)
    let first_point = point
    if end_point >= self.points.length() {
      end_point = self.points.length() - 1
    }
    while point <= end_point {
      let touched = self.is_touched(point, axis)
      if touched {
        break
      } else {
        point = point + 1
      }
    }
    if point <= end_point {
      let first_touched = point
      let mut cur_touched = point
      point = point + 1
      while point <= end_point {
        {
          let touched = self.is_touched(point, axis)
          if touched {
            self.iup_interpolate(
              axis,
              cur_touched + 1,
              point - 1,
              cur_touched,
              point,
            )
            cur_touched = point
          }
        }
        point = point + 1
      }
      if cur_touched == first_touched {
        self.iup_shift(axis, first_point, end_point, cur_touched)
      } else {
        self.iup_interpolate(
          axis,
          cur_touched + 1,
          end_point,
          cur_touched,
          first_touched,
        )
        if first_touched > 0 {
          self.iup_interpolate(
            axis,
            first_point,
            first_touched - 1,
            cur_touched,
            first_touched,
          )
        }
      }
    }
  }
  ()
}

///|
fn TtZone::iup_shift(
  self : TtZone,
  axis : TtAxis,
  p1 : Int32,
  p2 : Int32,
  p : Int32,
) -> Unit raise HintError {
  if p1 > p2 || p1 > p || p > p2 {
    return ()
  }
  let p_now = self.point(p)
  let p_orig = self.original_point(p)
  let delta = match axis {
    X => p_now.x - p_orig.x
    Y => p_now.y - p_orig.y
  }
  if delta != 0 {
    for i in p1..<(p2 + 1) {
      if i == p {
        continue
      }
      let mut pt = self.point(i)
      match axis {
        X => pt = { x: pt.x + delta, y: pt.y, }
        Y => pt = { x: pt.x, y: pt.y + delta, }
      }
      self.set_point(i, pt)
    }
  }
  ()
}

///|
fn tt_zone_axis_coord(p : TtPoint, axis : TtAxis) -> Int32 {
  match axis {
    X => p.x
    Y => p.y
  }
}

///|
fn tt_zone_set_axis_coord(p : TtPoint, axis : TtAxis, v : Int32) -> TtPoint {
  match axis {
    X => { x: v, y: p.y, }
    Y => { x: p.x, y: v, }
  }
}

///|
fn TtZone::iup_interpolate(
  self : TtZone,
  axis : TtAxis,
  p1 : Int32,
  p2 : Int32,
  ref1_0 : Int32,
  ref2_0 : Int32,
) -> Unit raise HintError {
  if p1 > p2 {
    return ()
  }
  let mut ref1 = ref1_0
  let mut ref2 = ref2_0
  let max_points = self.points.length()
  if ref1 < 0 || ref2 < 0 || ref1 >= max_points || ref2 >= max_points {
    return ()
  }
  // Unscaled reference coordinates in font units.
  let mut orus1 = tt_zone_axis_coord(self.unscaled_point(ref1), axis)
  let mut orus2 = tt_zone_axis_coord(self.unscaled_point(ref2), axis)
  if orus1 > orus2 {
    let tmp = orus1
    orus1 = orus2
    orus2 = tmp
    let tmpr = ref1
    ref1 = ref2
    ref2 = tmpr
  }
  // Scaled reference coordinates.
  let org1 = tt_zone_axis_coord(self.original_point(ref1), axis)
  let org2 = tt_zone_axis_coord(self.original_point(ref2), axis)
  let cur1 = tt_zone_axis_coord(self.point(ref1), axis)
  let cur2 = tt_zone_axis_coord(self.point(ref2), axis)
  let delta1 = cur1 - org1
  let delta2 = cur2 - org2
  let use_simple = cur1 == cur2 || orus1 == orus2
  let scale = if use_simple {
    0
  } else {
    tt_hint_div_16_16(cur2 - cur1, orus2 - orus1)
  }
  for i in p1..<(p2 + 1) {
    let org = tt_zone_axis_coord(self.original_point(i), axis)
    let pt = self.point(i)
    let new_coord = if org <= org1 {
      org + delta1
    } else if org >= org2 {
      org + delta2
    } else if use_simple {
      cur1
    } else {
      let unscaled = tt_zone_axis_coord(self.unscaled_point(i), axis)
      cur1 + tt_hint_mul_16_16(unscaled - orus1, scale)
    }
    self.set_point(i, tt_zone_set_axis_coord(pt, axis, new_coord))
  }
  ()
}
