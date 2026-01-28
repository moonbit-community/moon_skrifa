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
/// Glyph zones for TrueType hinting (partial port).
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/zone.rs` (Apache-2.0 OR MIT).
priv struct TtPoint {
  x : Int
  y : Int
}

///|
priv enum TtZonePointer {
  Twilight
  Glyph
}

///|
impl Eq for TtZonePointer with equal(a, b) {
  match (a, b) {
    (TtZonePointer::Twilight, TtZonePointer::Twilight) => true
    (TtZonePointer::Glyph, TtZonePointer::Glyph) => true
    _ => false
  }
}

///|
fn TtZonePointer::default() -> TtZonePointer {
  TtZonePointer::Glyph
}

///|
fn TtZonePointer::is_twilight(self : TtZonePointer) -> Bool {
  self is TtZonePointer::Twilight
}

///|
fn tt_zone_pointer_from_i32(value : Int) -> Result[TtZonePointer, HintError] {
  match value {
    0 => Ok(TtZonePointer::Twilight)
    1 => Ok(TtZonePointer::Glyph)
    _ => Err(HintError::InvalidZoneIndex(value))
  }
}

///|
const TT_POINT_ON_CURVE : Int = 1

///|
const TT_POINT_TOUCHED_X : Int = 2

///|
const TT_POINT_TOUCHED_Y : Int = 4

///|
priv enum TtAxis {
  X
  Y
}

///|
fn TtAxis::touched_mask(self : TtAxis) -> Int {
  match self {
    TtAxis::X => TT_POINT_TOUCHED_X
    TtAxis::Y => TT_POINT_TOUCHED_Y
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
  flags : Array[Int]
  contours : Array[Int]
}

///|
fn TtZone::default() -> TtZone {
  TtZone::{
    unscaled: Array::new(),
    original: Array::new(),
    points: Array::new(),
    flags: Array::new(),
    contours: Array::new(),
  }
}

///|
fn TtZone::point(self : TtZone, index : Int) -> Result[TtPoint, HintError] {
  if index < 0 || index >= self.points.length() {
    Err(HintError::InvalidPointIndex(index))
  } else {
    Ok(self.points.at(index))
  }
}

///|
fn TtZone::set_point(
  self : TtZone,
  index : Int,
  p : TtPoint,
) -> Result[Unit, HintError] {
  if index < 0 || index >= self.points.length() {
    Err(HintError::InvalidPointIndex(index))
  } else {
    self.points.set(index, p)
    Ok(())
  }
}

///|
fn TtZone::original_point(
  self : TtZone,
  index : Int,
) -> Result[TtPoint, HintError] {
  if index < 0 || index >= self.original.length() {
    Err(HintError::InvalidPointIndex(index))
  } else {
    Ok(self.original.at(index))
  }
}

///|
fn TtZone::set_original_point(
  self : TtZone,
  index : Int,
  p : TtPoint,
) -> Result[Unit, HintError] {
  if index < 0 || index >= self.original.length() {
    Err(HintError::InvalidPointIndex(index))
  } else {
    self.original.set(index, p)
    Ok(())
  }
}

///|
fn TtZone::unscaled_point(self : TtZone, index : Int) -> TtPoint {
  if index < 0 || index >= self.unscaled.length() {
    // Twilight unscaled points default to (0,0).
    TtPoint::{ x: 0, y: 0 }
  } else {
    self.unscaled.at(index)
  }
}

///|
fn TtZone::contour_end(self : TtZone, index : Int) -> Result[Int, HintError] {
  if index < 0 || index >= self.contours.length() {
    Err(HintError::InvalidStackValue(index))
  } else {
    Ok(self.contours.at(index))
  }
}

///|
fn TtZone::touch(
  self : TtZone,
  index : Int,
  axis : TtAxis,
) -> Result[Unit, HintError] {
  if index < 0 || index >= self.flags.length() {
    return Err(HintError::InvalidPointIndex(index))
  }
  self.flags.set(index, self.flags.at(index) | axis.touched_mask())
  Ok(())
}

///|

///|
fn TtZone::is_touched(
  self : TtZone,
  index : Int,
  axis : TtAxis,
) -> Result[Bool, HintError] {
  if index < 0 || index >= self.flags.length() {
    Err(HintError::InvalidPointIndex(index))
  } else {
    Ok((self.flags.at(index) & axis.touched_mask()) != 0)
  }
}

///|
fn TtZone::untouch(
  self : TtZone,
  index : Int,
  axis : TtAxis,
) -> Result[Unit, HintError] {
  if index < 0 || index >= self.flags.length() {
    return Err(HintError::InvalidPointIndex(index))
  }
  self.flags.set(index, self.flags.at(index) & (axis.touched_mask() ^ -1))
  Ok(())
}

///|
fn TtZone::flip_on_curve(self : TtZone, index : Int) -> Result[Unit, HintError] {
  if index < 0 || index >= self.flags.length() {
    return Err(HintError::InvalidPointIndex(index))
  }
  self.flags.set(index, self.flags.at(index) ^ TT_POINT_ON_CURVE)
  Ok(())
}

///|
fn TtZone::set_on_curve(
  self : TtZone,
  start : Int,
  end_ : Int,
  on : Bool,
) -> Result[Unit, HintError] {
  if start < 0 || end_ < start || end_ > self.flags.length() {
    return Err(HintError::InvalidPointRange(start, end_))
  }
  let mask = TT_POINT_ON_CURVE
  for i in start..<end_ {
    let f = self.flags.at(i)
    self.flags.set(i, if on { f | mask } else { f & (mask ^ -1) })
  }
  Ok(())
}

///|

///|

///|
/// Interpolate untouched points (IUP).
fn TtZone::iup(self : TtZone, axis : TtAxis) -> Result[Unit, HintError] {
  let mut point = 0
  for i in 0..<self.contours.length() {
    let mut end_point = match self.contour_end(i) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let first_point = point
    if end_point >= self.points.length() {
      end_point = self.points.length() - 1
    }
    while point <= end_point {
      match self.is_touched(point, axis) {
        Err(e) => return Err(e)
        Ok(touched) => if touched { break } else { point = point + 1 }
      }
    }
    if point <= end_point {
      let first_touched = point
      let mut cur_touched = point
      point = point + 1
      while point <= end_point {
        match self.is_touched(point, axis) {
          Err(e) => return Err(e)
          Ok(touched) =>
            if touched {
              match
                self.iup_interpolate(
                  axis,
                  cur_touched + 1,
                  point - 1,
                  cur_touched,
                  point,
                ) {
                Err(e) => return Err(e)
                Ok(_) => ()
              }
              cur_touched = point
            }
        }
        point = point + 1
      }
      if cur_touched == first_touched {
        match self.iup_shift(axis, first_point, end_point, cur_touched) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      } else {
        match
          self.iup_interpolate(
            axis,
            cur_touched + 1,
            end_point,
            cur_touched,
            first_touched,
          ) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        if first_touched > 0 {
          match
            self.iup_interpolate(
              axis,
              first_point,
              first_touched - 1,
              cur_touched,
              first_touched,
            ) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        }
      }
    }
  }
  Ok(())
}

///|
fn TtZone::iup_shift(
  self : TtZone,
  axis : TtAxis,
  p1 : Int,
  p2 : Int,
  p : Int,
) -> Result[Unit, HintError] {
  if p1 > p2 || p1 > p || p > p2 {
    return Ok(())
  }
  let (p_now, p_orig) = match (self.point(p), self.original_point(p)) {
    (Ok(a), Ok(b)) => (a, b)
    (Err(e), _) => return Err(e)
    (_, Err(e)) => return Err(e)
  }
  let delta = match axis {
    TtAxis::X => p_now.x - p_orig.x
    TtAxis::Y => p_now.y - p_orig.y
  }
  if delta != 0 {
    for i in p1..<(p2 + 1) {
      if i == p {
        continue
      }
      let mut pt = match self.point(i) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
      match axis {
        TtAxis::X => pt = TtPoint::{ x: pt.x + delta, y: pt.y }
        TtAxis::Y => pt = TtPoint::{ x: pt.x, y: pt.y + delta }
      }
      match self.set_point(i, pt) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
fn tt_zone_axis_coord(p : TtPoint, axis : TtAxis) -> Int {
  match axis {
    TtAxis::X => p.x
    TtAxis::Y => p.y
  }
}

///|
fn tt_zone_set_axis_coord(p : TtPoint, axis : TtAxis, v : Int) -> TtPoint {
  match axis {
    TtAxis::X => TtPoint::{ x: v, y: p.y }
    TtAxis::Y => TtPoint::{ x: p.x, y: v }
  }
}

///|
fn TtZone::iup_interpolate(
  self : TtZone,
  axis : TtAxis,
  p1 : Int,
  p2 : Int,
  ref1_0 : Int,
  ref2_0 : Int,
) -> Result[Unit, HintError] {
  if p1 > p2 {
    return Ok(())
  }
  let mut ref1 = ref1_0
  let mut ref2 = ref2_0
  let max_points = self.points.length()
  if ref1 < 0 || ref2 < 0 || ref1 >= max_points || ref2 >= max_points {
    return Ok(())
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
  let org1 = tt_zone_axis_coord(
    match self.original_point(ref1) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    axis,
  )
  let org2 = tt_zone_axis_coord(
    match self.original_point(ref2) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    axis,
  )
  let cur1 = tt_zone_axis_coord(
    match self.point(ref1) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    axis,
  )
  let cur2 = tt_zone_axis_coord(
    match self.point(ref2) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    axis,
  )
  let delta1 = cur1 - org1
  let delta2 = cur2 - org2
  let use_simple = cur1 == cur2 || orus1 == orus2
  let scale = if use_simple {
    0
  } else {
    tt_hint_div_16_16(cur2 - cur1, orus2 - orus1)
  }
  for i in p1..<(p2 + 1) {
    let org = tt_zone_axis_coord(
      match self.original_point(i) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
      axis,
    )
    let pt = match self.point(i) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
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
    match self.set_point(i, tt_zone_set_axis_coord(pt, axis, new_coord)) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}
