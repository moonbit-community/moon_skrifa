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
/// Outline manipulation instruction implementations for the TT engine.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/engine/outline.rs`
/// (Apache-2.0 OR MIT).
fn tt_abs_i(x : Int) -> Int {
  if x < 0 {
    -x
  } else {
    x
  }
}

///|
fn tt_in_bounds(
  gs : TtGraphicsState,
  zone_ptr : TtZonePointer,
  p : Int,
) -> Bool {
  let zone = match zone_ptr {
    TtZonePointer::Twilight => gs.twilight
    TtZonePointer::Glyph => gs.glyph
  }
  p >= 0 && p < zone.points.length()
}

///|
fn TtEngine::op_shp(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let gs = self.graphics
  let disp = match gs.point_displacement(opcode) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  for _ in 0..<count {
    let p = match self.value_stack.pop_usize() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    match self.graphics.move_zp2_point(p, disp.dx, disp.dy, true) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
fn TtEngine::op_shc(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let contour_ix = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let gs = self.graphics
  let z = gs.zp2_zone()
  if !gs.is_pedantic && (contour_ix < 0 || contour_ix >= z.contours.length()) {
    return Ok(())
  }
  let disp = match gs.point_displacement(opcode) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let start = if contour_ix != 0 {
    match z.contour_end(contour_ix - 1) {
      Err(e) => return Err(e)
      Ok(v) => v + 1
    }
  } else {
    0
  }
  let end = if gs.zp2.is_twilight() {
    z.points.length()
  } else {
    match z.contour_end(contour_ix) {
      Err(e) => return Err(e)
      Ok(v) => v + 1
    }
  }
  for i in start..<end {
    if disp.zone != gs.zp2 || disp.point_ix != i {
      match self.graphics.move_zp2_point(i, disp.dx, disp.dy, true) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
fn TtEngine::op_shpix(self : TtEngine) -> Result[Unit, HintError] {
  let gs = self.graphics
  let in_twilight = gs.zp0.is_twilight() ||
    gs.zp1.is_twilight() ||
    gs.zp2.is_twilight()
  let amount = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let dx = tt_hint_mul14(amount, gs.freedom_vector.x)
  let dy = tt_hint_mul14(amount, gs.freedom_vector.y)
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  let did_iup = gs.did_iup_x && gs.did_iup_y
  for _ in 0..<count {
    let p = match self.value_stack.pop_usize() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    if gs.backward_compatibility {
      let touched_y = match gs.zp2_zone().is_touched(p, TtAxis::Y) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
      if in_twilight ||
        (
          !did_iup &&
          ((gs.is_composite && gs.freedom_vector.y != 0) || touched_y)
        ) {
        match self.graphics.move_zp2_point(p, dx, dy, true) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
    } else {
      match self.graphics.move_zp2_point(p, dx, dy, true) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
fn TtEngine::op_msirp(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let gs = self.graphics
  let distance = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let point_ix = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if !gs.is_pedantic &&
    (!tt_in_bounds(gs, gs.zp1, point_ix) || !tt_in_bounds(gs, gs.zp0, gs.rp0)) {
    return Ok(())
  }
  if gs.zp1.is_twilight() {
    let zp0z = gs.zp0_zone()
    let orig = match zp0z.original_point(gs.rp0) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let zp1z = gs.zp1_zone()
    match zp1z.set_point(point_ix, orig) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match zp1z.set_original_point(point_ix, orig) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match self.graphics.move_point(gs.zp1, point_ix, distance) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    let p1 = match zp1z.original_point(point_ix) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    match zp1z.set_point(point_ix, p1) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let d = self.graphics.project(
    match gs.zp1_zone().point(point_ix) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    match gs.zp0_zone().point(gs.rp0) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
  )
  match self.graphics.move_point(gs.zp1, point_ix, distance - d) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.graphics.rp1 = gs.rp0
  self.graphics.rp2 = point_ix
  if (opcode & 1) != 0 {
    self.graphics.rp0 = point_ix
  }
  Ok(())
}

///|
fn TtEngine::op_mdap(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let gs = self.graphics
  if !gs.is_pedantic && !tt_in_bounds(gs, gs.zp0, p) {
    self.graphics.rp0 = p
    self.graphics.rp1 = p
    return Ok(())
  }
  let distance = if (opcode & 1) != 0 {
    let cur_dist = self.graphics.project(
      match gs.zp0_zone().point(p) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
      TtPoint::{ x: 0, y: 0 },
    )
    self.graphics.round(cur_dist) - cur_dist
  } else {
    0
  }
  match self.graphics.move_point(gs.zp0, p, distance) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.graphics.rp0 = p
  self.graphics.rp1 = p
  Ok(())
}

///|
fn TtEngine::op_miap(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let cvt_entry = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let point_ix = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if cvt_entry < 0 || cvt_entry >= self.cvt.length() {
    return Err(HintError::InvalidCvtIndex(cvt_entry))
  }
  let mut distance = self.cvt.at(cvt_entry)
  let gs = self.graphics
  if gs.zp0.is_twilight() {
    let fv = gs.freedom_vector
    let z = gs.zp0_zone()
    let original_point = TtPoint::{
      x: tt_hint_mul14(distance, fv.x),
      y: tt_hint_mul14(distance, fv.y),
    }
    match z.set_original_point(point_ix, original_point) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match z.set_point(point_ix, original_point) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let original_distance = self.graphics.project(
    match gs.zp0_zone().point(point_ix) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    TtPoint::{ x: 0, y: 0 },
  )
  if (opcode & 1) != 0 {
    let delta = tt_abs_i(distance - original_distance)
    if delta > gs.retained.control_value_cutin {
      distance = original_distance
    }
    distance = self.graphics.round(distance)
  }
  match
    self.graphics.move_point(gs.zp0, point_ix, distance - original_distance) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.graphics.rp0 = point_ix
  self.graphics.rp1 = point_ix
  Ok(())
}

///|
fn TtEngine::op_mdrp(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let gs = self.graphics
  if !gs.is_pedantic &&
    (!tt_in_bounds(gs, gs.zp1, p) || !tt_in_bounds(gs, gs.zp0, gs.rp0)) {
    self.graphics.rp1 = gs.rp0
    self.graphics.rp2 = p
    if (opcode & 16) != 0 {
      self.graphics.rp0 = p
    }
    return Ok(())
  }
  let mut original_distance = if gs.zp0.is_twilight() || gs.zp1.is_twilight() {
    self.graphics.dual_project(
      match gs.zp1_zone().original_point(p) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
      match gs.zp0_zone().original_point(gs.rp0) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
    )
  } else {
    let v1 = gs.zp1_zone().unscaled_point(p)
    let v2 = gs.zp0_zone().unscaled_point(gs.rp0)
    let dist = self.graphics.dual_project_unscaled(v1, v2)
    // scale to pixels (matches fontations `math::mul` sign-aware rounding)
    tt_hint_mul_16_16(dist, gs.unscaled_to_pixels())
  }
  let cutin = gs.retained.single_width_cutin
  let value = gs.retained.single_width
  if cutin > 0 &&
    original_distance < value + cutin &&
    original_distance > value - cutin {
    original_distance = if original_distance >= 0 { value } else { -value }
  }
  let mut distance = if (opcode & 4) != 0 {
    self.graphics.round(original_distance)
  } else {
    original_distance
  }
  if (opcode & 8) != 0 {
    let min_distance = gs.retained.min_distance
    if original_distance >= 0 {
      if distance < min_distance {
        distance = min_distance
      }
    } else if distance > -min_distance {
      distance = -min_distance
    }
  }
  let cur = self.graphics.project(
    match gs.zp1_zone().point(p) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    match gs.zp0_zone().point(gs.rp0) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
  )
  match self.graphics.move_point(gs.zp1, p, distance - cur) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.graphics.rp1 = gs.rp0
  self.graphics.rp2 = p
  if (opcode & 16) != 0 {
    self.graphics.rp0 = p
  }
  Ok(())
}

///|
fn TtEngine::op_mirp(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let n = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v + 1
  }
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let gs = self.graphics
  if !gs.is_pedantic &&
    (
      !tt_in_bounds(gs, gs.zp1, p) ||
      !tt_in_bounds(gs, gs.zp0, gs.rp0) ||
      n > self.cvt.length()
    ) {
    self.graphics.rp1 = gs.rp0
    if (opcode & 16) != 0 {
      self.graphics.rp0 = p
    }
    self.graphics.rp2 = p
    return Ok(())
  }
  let mut cvt_distance = if n == 0 { 0 } else { self.cvt.at(n - 1) }
  let cutin = gs.retained.single_width_cutin
  let value = gs.retained.single_width
  let mut delta = tt_abs_i(cvt_distance - value)
  if delta < cutin {
    cvt_distance = if cvt_distance >= 0 { value } else { -value }
  }
  if gs.zp1.is_twilight() {
    let fv = gs.freedom_vector
    let d = cvt_distance
    let p2 = match gs.zp0_zone().original_point(gs.rp0) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let p1 = TtPoint::{
      x: p2.x + tt_hint_mul14(d, fv.x),
      y: p2.y + tt_hint_mul14(d, fv.y),
    }
    let z1 = gs.zp1_zone()
    match z1.set_original_point(p, p1) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match z1.set_point(p, p1) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let original_distance = self.graphics.dual_project(
    match gs.zp1_zone().original_point(p) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    match gs.zp0_zone().original_point(gs.rp0) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
  )
  let current_distance = self.graphics.project(
    match gs.zp1_zone().point(p) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    match gs.zp0_zone().point(gs.rp0) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
  )
  if gs.retained.auto_flip && (original_distance ^ cvt_distance) < 0 {
    cvt_distance = -cvt_distance
  }
  let mut distance = if (opcode & 4) != 0 {
    if gs.zp0 == gs.zp1 {
      delta = tt_abs_i(cvt_distance - original_distance)
      if delta > gs.retained.control_value_cutin {
        cvt_distance = original_distance
      }
    }
    self.graphics.round(cvt_distance)
  } else {
    cvt_distance
  }
  if (opcode & 8) != 0 {
    let min_distance = gs.retained.min_distance
    if original_distance >= 0 {
      if distance < min_distance {
        distance = min_distance
      }
    } else if distance > -min_distance {
      distance = -min_distance
    }
  }
  match self.graphics.move_point(gs.zp1, p, distance - current_distance) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.graphics.rp1 = gs.rp0
  if (opcode & 16) != 0 {
    self.graphics.rp0 = p
  }
  self.graphics.rp2 = p
  Ok(())
}

///|
fn TtEngine::op_alignrp(self : TtEngine) -> Result[Unit, HintError] {
  let gs = self.graphics
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  for _ in 0..<count {
    let p = match self.value_stack.pop_usize() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let distance = self.graphics.project(
      match gs.zp1_zone().point(p) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
      match gs.zp0_zone().point(gs.rp0) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
    )
    match self.graphics.move_point(gs.zp1, p, -distance) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
fn tt_mul_div26(a : Int, b : Int, c : Int) -> Int {
  tt_mul_div_round(a, b, c)
}

///|
fn TtEngine::op_ip(self : TtEngine) -> Result[Unit, HintError] {
  let gs = self.graphics
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  if !gs.is_pedantic &&
    (!tt_in_bounds(gs, gs.zp0, gs.rp1) || !tt_in_bounds(gs, gs.zp1, gs.rp2)) {
    return Ok(())
  }
  let in_twilight = gs.zp0.is_twilight() ||
    gs.zp1.is_twilight() ||
    gs.zp2.is_twilight()
  let orus_base = if in_twilight {
    match gs.zp0_zone().original_point(gs.rp1) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
  } else {
    gs.zp0_zone().unscaled_point(gs.rp1)
  }
  let cur_base = match gs.zp0_zone().point(gs.rp1) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let old_range = if in_twilight {
    self.graphics.dual_project(
      match gs.zp1_zone().original_point(gs.rp2) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
      orus_base,
    )
  } else {
    self.graphics.dual_project_unscaled(
      gs.zp1_zone().unscaled_point(gs.rp2),
      orus_base,
    )
  }
  let cur_range = self.graphics.project(
    match gs.zp1_zone().point(gs.rp2) {
      Err(e) => return Err(e)
      Ok(v) => v
    },
    cur_base,
  )
  for _ in 0..<count {
    let point = match self.value_stack.pop_usize() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    if !gs.is_pedantic && !tt_in_bounds(gs, gs.zp2, point) {
      continue
    }
    let original_distance = if in_twilight {
      self.graphics.dual_project(
        match gs.zp2_zone().original_point(point) {
          Err(e) => return Err(e)
          Ok(v) => v
        },
        orus_base,
      )
    } else {
      self.graphics.dual_project_unscaled(
        gs.zp2_zone().unscaled_point(point),
        orus_base,
      )
    }
    let cur_distance = self.graphics.project(
      match gs.zp2_zone().point(point) {
        Err(e) => return Err(e)
        Ok(v) => v
      },
      cur_base,
    )
    let new_distance = if original_distance != 0 {
      if old_range != 0 {
        tt_mul_div26(original_distance, cur_range, old_range)
      } else {
        original_distance
      }
    } else {
      0
    }
    match self.graphics.move_point(gs.zp2, point, new_distance - cur_distance) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
fn TtEngine::op_iup(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let axis = if (opcode & 1) != 0 { TtAxis::X } else { TtAxis::Y }
  let mut run = true
  if self.graphics.backward_compatibility {
    if self.graphics.did_iup_x && self.graphics.did_iup_y {
      run = false
    }
    if axis is TtAxis::X {
      self.graphics.did_iup_x = true
    } else {
      self.graphics.did_iup_y = true
    }
  }
  if run {
    let glyph = self.graphics.glyph
    match glyph.iup(axis) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}
