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
/// Graphics state + projection helpers for the TrueType interpreter.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/{graphics.rs,projection.rs}`
/// (Apache-2.0 OR MIT).

///|
priv enum TtCoordAxis {
  Both
  X
  Y
}

///|
/// 2.14 fixed point vector used for projection/freedom vectors.
priv struct TtVec14 {
  x : Int
  y : Int
}

///|
fn TtVec14::default() -> TtVec14 {
  // (1, 0) in 2.14 (x-axis), matches fontations/FreeType defaults.
  TtVec14::{ x: 0x4000, y: 0 }
}

///|
/// Persistent graphics state (retained across programs as in FreeType).
priv struct TtRetainedGraphicsState {
  auto_flip : Bool
  mut control_value_cutin : Int
  mut delta_base : Int
  mut delta_shift : Int
  mut instruct_control : Int
  mut min_distance : Int
  mut scan_control : Bool
  mut scan_type : Int
  single_width_cutin : Int
  single_width : Int
  target : Target
  scale : Int
  ppem : Int
  is_rotated : Bool
  is_stretched : Bool
}

///|
fn TtRetainedGraphicsState::default() -> TtRetainedGraphicsState {
  TtRetainedGraphicsState::{
    auto_flip: true,
    // 17/16 pixels in 26.6: (17 * 64 / 16) = 68
    control_value_cutin: 68,
    delta_base: 9,
    delta_shift: 3,
    instruct_control: 0,
    // 1 pixel in 26.6
    min_distance: 64,
    scan_control: false,
    scan_type: 0,
    single_width_cutin: 0,
    single_width: 0,
    target: Target::default(),
    scale: 0,
    ppem: 0,
    is_rotated: false,
    is_stretched: false,
  }
}

///|
fn TtRetainedGraphicsState::new(
  scale : Int,
  ppem : Int,
  target : Target,
) -> TtRetainedGraphicsState {
  let d = TtRetainedGraphicsState::default()
  TtRetainedGraphicsState::{
    auto_flip: d.auto_flip,
    control_value_cutin: d.control_value_cutin,
    delta_base: d.delta_base,
    delta_shift: d.delta_shift,
    instruct_control: d.instruct_control,
    min_distance: d.min_distance,
    scan_control: d.scan_control,
    scan_type: d.scan_type,
    single_width_cutin: d.single_width_cutin,
    single_width: d.single_width,
    target,
    scale,
    ppem,
    is_rotated: d.is_rotated,
    is_stretched: d.is_stretched,
  }
}

///|
priv struct TtGraphicsState {
  mut retained : TtRetainedGraphicsState
  mut proj_vector : TtVec14
  mut proj_axis : TtCoordAxis
  mut dual_proj_vector : TtVec14
  mut dual_proj_axis : TtCoordAxis
  mut freedom_vector : TtVec14
  mut freedom_axis : TtCoordAxis
  mut fdotp : Int
  mut round_state : TtRoundState
  mut rp0 : Int
  mut rp1 : Int
  mut rp2 : Int
  mut loop_counter : Int
  mut zp0 : TtZonePointer
  mut zp1 : TtZonePointer
  mut zp2 : TtZonePointer
  mut twilight : TtZone
  mut glyph : TtZone
  mut is_composite : Bool
  mut backward_compatibility : Bool
  mut is_pedantic : Bool
  mut did_iup_x : Bool
  mut did_iup_y : Bool
}

///|
priv struct TtPointDisplacement {
  zone : TtZonePointer
  point_ix : Int
  dx : Int
  dy : Int
}

///|
fn TtGraphicsState::default() -> TtGraphicsState {
  // Default vectors: proj=(0,1), freedom=(0,1)
  let v = TtVec14::default()
  let s = TtGraphicsState::{
    retained: TtRetainedGraphicsState::default(),
    proj_vector: v,
    proj_axis: TtCoordAxis::Y,
    dual_proj_vector: v,
    dual_proj_axis: TtCoordAxis::Y,
    freedom_vector: v,
    freedom_axis: TtCoordAxis::Y,
    fdotp: 0x4000,
    round_state: TtRoundState::default(),
    rp0: 0,
    rp1: 0,
    rp2: 0,
    loop_counter: 1,
    zp0: TtZonePointer::default(),
    zp1: TtZonePointer::default(),
    zp2: TtZonePointer::default(),
    twilight: TtZone::default(),
    glyph: TtZone::default(),
    is_composite: false,
    backward_compatibility: true,
    is_pedantic: false,
    did_iup_x: false,
    did_iup_y: false,
  }
  s.update_projection_state()
  s
}

///|
/// Resets transient graphics state and keeps retained fields.
fn TtGraphicsState::reset(self : TtGraphicsState) -> Unit {
  let v = TtVec14::default()
  self.proj_vector = v
  self.dual_proj_vector = v
  self.freedom_vector = v
  self.round_state = TtRoundState::default()
  self.rp0 = 0
  self.rp1 = 0
  self.rp2 = 0
  self.loop_counter = 1
  self.zp0 = TtZonePointer::default()
  self.zp1 = TtZonePointer::default()
  self.zp2 = TtZonePointer::default()
  self.is_composite = false
  self.backward_compatibility = true
  self.did_iup_x = false
  self.did_iup_y = false
  self.update_projection_state()
}

///|
/// Resets retained graphics state to default values.
fn TtGraphicsState::reset_retained(self : TtGraphicsState) -> Unit {
  let scale = self.retained.scale
  let ppem = self.retained.ppem
  let target = self.retained.target
  self.retained = TtRetainedGraphicsState::new(scale, ppem, target)
}

///|
fn TtGraphicsState::zp0_zone(self : TtGraphicsState) -> TtZone {
  match self.zp0 {
    TtZonePointer::Twilight => self.twilight
    TtZonePointer::Glyph => self.glyph
  }
}

///|
fn TtGraphicsState::zp1_zone(self : TtGraphicsState) -> TtZone {
  match self.zp1 {
    TtZonePointer::Twilight => self.twilight
    TtZonePointer::Glyph => self.glyph
  }
}

///|
fn TtGraphicsState::zp2_zone(self : TtGraphicsState) -> TtZone {
  match self.zp2 {
    TtZonePointer::Twilight => self.twilight
    TtZonePointer::Glyph => self.glyph
  }
}

///|
fn tt_dot14(ax : Int, ay : Int, bx : Int, by : Int) -> Int {
  let mut v1 = ax.to_int64() * bx.to_int64()
  let v2 = ay.to_int64() * by.to_int64()
  v1 = v1 + v2
  v1 = v1 + 0x2000 + (v1 >> 63)
  (v1 >> 14).to_int()
}

///|
/// Updates cached state derived from projection vectors.
fn TtGraphicsState::update_projection_state(self : TtGraphicsState) -> Unit {
  // 1.0 in 2.14 fixed point.
  let one = 0x4000
  if self.freedom_vector.x == one {
    self.fdotp = self.proj_vector.x
  } else if self.freedom_vector.y == one {
    self.fdotp = self.proj_vector.y
  } else {
    let px = self.proj_vector.x
    let py = self.proj_vector.y
    let fx = self.freedom_vector.x
    let fy = self.freedom_vector.y
    self.fdotp = (px * fx + py * fy) >> 14
  }
  self.proj_axis = TtCoordAxis::Both
  if self.proj_vector.x == one {
    self.proj_axis = TtCoordAxis::X
  } else if self.proj_vector.y == one {
    self.proj_axis = TtCoordAxis::Y
  }
  self.dual_proj_axis = TtCoordAxis::Both
  if self.dual_proj_vector.x == one {
    self.dual_proj_axis = TtCoordAxis::X
  } else if self.dual_proj_vector.y == one {
    self.dual_proj_axis = TtCoordAxis::Y
  }
  self.freedom_axis = TtCoordAxis::Both
  if self.fdotp == one {
    if self.freedom_vector.x == one {
      self.freedom_axis = TtCoordAxis::X
    } else if self.freedom_vector.y == one {
      self.freedom_axis = TtCoordAxis::Y
    }
  }
  // Avoid tiny fdotp that can lead to overflows.
  if self.fdotp.abs() < 0x400 {
    self.fdotp = one
  }
}

///|
/// Projects (p1 - p2) along current projection vector, returning 26.6.
fn TtGraphicsState::project(
  self : TtGraphicsState,
  p1 : TtPoint,
  p2 : TtPoint,
) -> Int {
  match self.proj_axis {
    TtCoordAxis::X => p1.x - p2.x
    TtCoordAxis::Y => p1.y - p2.y
    TtCoordAxis::Both => {
      let dx = p1.x - p2.x
      let dy = p1.y - p2.y
      tt_dot14(dx, dy, self.proj_vector.x, self.proj_vector.y)
    }
  }
}

///|
/// Dual-projects (p1 - p2) along dual projection vector, returning 26.6.
fn TtGraphicsState::dual_project(
  self : TtGraphicsState,
  p1 : TtPoint,
  p2 : TtPoint,
) -> Int {
  match self.dual_proj_axis {
    TtCoordAxis::X => p1.x - p2.x
    TtCoordAxis::Y => p1.y - p2.y
    TtCoordAxis::Both => {
      let dx = p1.x - p2.x
      let dy = p1.y - p2.y
      tt_dot14(dx, dy, self.dual_proj_vector.x, self.dual_proj_vector.y)
    }
  }
}

///|
/// Dual-projects (p1 - p2) for unscaled points (font units), returning i32.
fn TtGraphicsState::dual_project_unscaled(
  self : TtGraphicsState,
  p1 : TtPoint,
  p2 : TtPoint,
) -> Int {
  match self.dual_proj_axis {
    TtCoordAxis::X => p1.x - p2.x
    TtCoordAxis::Y => p1.y - p2.y
    TtCoordAxis::Both => {
      let dx = p1.x - p2.x
      let dy = p1.y - p2.y
      tt_dot14(dx, dy, self.dual_proj_vector.x, self.dual_proj_vector.y)
    }
  }
}

///|
fn TtGraphicsState::round(self : TtGraphicsState, distance_bits : Int) -> Int {
  self.round_state.round(distance_bits)
}

///|
/// Returns the factor for scaling unscaled points to pixels (26.6).
fn TtGraphicsState::unscaled_to_pixels(self : TtGraphicsState) -> Int {
  if self.is_composite {
    0x10000
  } else {
    self.retained.scale
  }
}

///|
fn tt_mul_div_round(a : Int, b : Int, c : Int) -> Int {
  // a * b / c with rounding, matching FreeType-ish behavior.
  if c == 0 {
    return 0x7FFFFFFF
  }
  let mut sign = 1
  let mut aa = a.to_int64()
  let mut bb = b.to_int64()
  let mut cc = c.to_int64()
  if aa < 0 {
    aa = -aa
    sign = -sign
  }
  if bb < 0 {
    bb = -bb
    sign = -sign
  }
  if cc < 0 {
    cc = -cc
    sign = -sign
  }
  let res = (aa * bb + (cc >> 1)) / cc
  let out = res.to_int()
  if sign < 0 {
    -out
  } else {
    out
  }
}

///|
/// Computes adjustment made to a point along the current freedom vector.
fn TtGraphicsState::point_displacement(
  self : TtGraphicsState,
  opcode : Int,
) -> Result[TtPointDisplacement, HintError] {
  let (zone_ptr, point_ix) = if (opcode & 1) != 0 {
    (self.zp0, self.rp1)
  } else {
    (self.zp1, self.rp2)
  }
  let zone = match zone_ptr {
    TtZonePointer::Twilight => self.twilight
    TtZonePointer::Glyph => self.glyph
  }
  let point = match zone.point(point_ix) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let original = match zone.original_point(point_ix) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let dist = self.project(point, original)
  let fv = self.freedom_vector
  let dx = tt_mul_div_round(dist, fv.x, self.fdotp)
  let dy = tt_mul_div_round(dist, fv.y, self.fdotp)
  Ok(TtPointDisplacement::{ zone: zone_ptr, point_ix, dx, dy })
}

///|
/// Moves a point in zp2 by (dx, dy) in 26.6 units.
fn TtGraphicsState::move_zp2_point(
  self : TtGraphicsState,
  index : Int,
  dx : Int,
  dy : Int,
  touch : Bool,
) -> Result[Unit, HintError] {
  // Backward compatibility behavior matches fontations/FreeType:
  // - Never adjust x in back-compat mode.
  // - Never adjust y in back-compat mode after IUP has been applied in both
  //   directions (avoids late y tweaks after interpolation).
  let back_compat = self.backward_compatibility
  let back_compat_and_did_iup = back_compat && self.did_iup_x && self.did_iup_y
  let fv = self.freedom_vector
  let zone = self.zp2_zone()
  if fv.x != 0 {
    if !back_compat {
      let p = match zone.point(index) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
      match zone.set_point(index, TtPoint::{ x: p.x + dx, y: p.y }) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    if touch {
      match zone.touch(index, TtAxis::X) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  if fv.y != 0 {
    if !back_compat_and_did_iup {
      let p = match zone.point(index) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
      match zone.set_point(index, TtPoint::{ x: p.x, y: p.y + dy }) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    if touch {
      match zone.touch(index, TtAxis::Y) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
/// Moves a point in the given zone by a distance along the freedom vector.
fn TtGraphicsState::move_point(
  self : TtGraphicsState,
  zone_ptr : TtZonePointer,
  index : Int,
  distance_bits : Int,
) -> Result[Unit, HintError] {
  let back_compat = self.backward_compatibility
  let back_compat_and_did_iup = back_compat && self.did_iup_x && self.did_iup_y
  let fv = self.freedom_vector
  let fdotp = self.fdotp
  let zone = match zone_ptr {
    TtZonePointer::Twilight => self.twilight
    TtZonePointer::Glyph => self.glyph
  }
  match self.freedom_axis {
    TtCoordAxis::X => {
      if !back_compat {
        let p = match zone.point(index) {
          Err(e) => return Err(e)
          Ok(v) => v
        }
        match
          zone.set_point(index, TtPoint::{ x: p.x + distance_bits, y: p.y }) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
      match zone.touch(index, TtAxis::X) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    TtCoordAxis::Y => {
      if !back_compat_and_did_iup {
        let p = match zone.point(index) {
          Err(e) => return Err(e)
          Ok(v) => v
        }
        match
          zone.set_point(index, TtPoint::{ x: p.x, y: p.y + distance_bits }) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
      match zone.touch(index, TtAxis::Y) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    TtCoordAxis::Both => {
      if fv.x != 0 {
        if !back_compat {
          let dx = tt_mul_div_round(distance_bits, fv.x, fdotp)
          let p = match zone.point(index) {
            Err(e) => return Err(e)
            Ok(v) => v
          }
          match zone.set_point(index, TtPoint::{ x: p.x + dx, y: p.y }) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        }
        match zone.touch(index, TtAxis::X) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
      if fv.y != 0 {
        if !back_compat_and_did_iup {
          let dy = tt_mul_div_round(distance_bits, fv.y, fdotp)
          let p = match zone.point(index) {
            Err(e) => return Err(e)
            Ok(v) => v
          }
          match zone.set_point(index, TtPoint::{ x: p.x, y: p.y + dy }) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        }
        match zone.touch(index, TtAxis::Y) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
    }
  }
  Ok(())
}
