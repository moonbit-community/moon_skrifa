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
fn tt_abs_i(x : Int32) -> Int32 {
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
  p : Int32,
) -> Bool {
  let zone = match zone_ptr {
    Twilight => gs.twilight
    Glyph => gs.glyph
  }
  p >= 0 && p < zone.points.length()
}

///|
fn TtEngine::op_flippt(self : TtEngine) -> Unit raise HintError {
  let count = self.graphics.loop_counter
  self.graphics.loop_counter = 1
  // In backward compatibility mode, don't flip points after IUP has run.
  if self.graphics.backward_compatibility &&
    self.graphics.did_iup_x &&
    self.graphics.did_iup_y {
    for _ in 0..<count {
      ignore(self.value_stack.pop())
    }
    return ()
  }
  let zone = self.graphics.glyph
  for _ in 0..<count {
    let p = self.value_stack.pop_usize()
    zone.flip_on_curve(p)
  }
  ()
}

///|
fn TtEngine::set_on_curve_for_range(
  self : TtEngine,
  on : Bool,
) -> Unit raise HintError {
  let high0 = self.value_stack.pop_usize()
  let low = self.value_stack.pop_usize()
  // high_point is inclusive; convert to exclusive.
  let high = high0 + 1
  if high <= high0 {
    raise InvalidPointIndex(high0)
  }
  if self.graphics.backward_compatibility &&
    self.graphics.did_iup_x &&
    self.graphics.did_iup_y {
    return ()
  }
  self.graphics.glyph.set_on_curve(low, high, on)
}

///|
fn TtEngine::op_fliprgon(self : TtEngine) -> Unit raise HintError {
  self.set_on_curve_for_range(true)
}

///|
fn TtEngine::op_fliprgoff(self : TtEngine) -> Unit raise HintError {
  self.set_on_curve_for_range(false)
}

///|
fn TtEngine::op_shp(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let gs = self.graphics
  let disp = gs.point_displacement(opcode)
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  for _ in 0..<count {
    let p = self.value_stack.pop_usize()
    self.graphics.move_zp2_point(p, disp.dx, disp.dy, true)
  }
  ()
}

///|
fn TtEngine::op_shc(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let contour_ix = self.value_stack.pop_usize()
  let gs = self.graphics
  let z = gs.zp2_zone()
  if !gs.is_pedantic && (contour_ix < 0 || contour_ix >= z.contours.length()) {
    return ()
  }
  let disp = gs.point_displacement(opcode)
  let start = if contour_ix != 0 {
    let v = z.contour_end(contour_ix - 1)
    v + 1
  } else {
    0
  }
  let end = if gs.zp2.is_twilight() {
    z.points.length()
  } else {
    let v = z.contour_end(contour_ix)
    v + 1
  }
  for i in start..<end {
    if disp.zone != gs.zp2 || disp.point_ix != i {
      self.graphics.move_zp2_point(i, disp.dx, disp.dy, true)
    }
  }
  ()
}

///|
fn TtEngine::op_shz(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let e = self.value_stack.pop()
  // Validate zone pointer but we shift the current zp2 zone regardless.
  ignore(tt_zone_pointer_from_i32(e))
  let gs = self.graphics
  let disp = gs.point_displacement(opcode)
  let z = gs.zp2_zone()
  let end = if gs.zp2.is_twilight() {
    z.points.length()
  } else if !z.contours.is_empty() {
    z.contours.at(z.contours.length() - 1) + 1
  } else {
    0
  }
  for i in 0..<end {
    if disp.zone != gs.zp2 || disp.point_ix != i {
      self.graphics.move_zp2_point(i, disp.dx, disp.dy, false)
    }
  }
  ()
}

///|
fn TtEngine::op_shpix(self : TtEngine) -> Unit raise HintError {
  let gs = self.graphics
  let in_twilight = gs.zp0.is_twilight() ||
    gs.zp1.is_twilight() ||
    gs.zp2.is_twilight()
  let amount = self.value_stack.pop()
  let dx = tt_hint_mul14(amount, gs.freedom_vector.x)
  let dy = tt_hint_mul14(amount, gs.freedom_vector.y)
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  let did_iup = gs.did_iup_x && gs.did_iup_y
  for _ in 0..<count {
    let p = self.value_stack.pop_usize()
    if gs.backward_compatibility {
      let touched_y = gs.zp2_zone().is_touched(p, Y)
      if in_twilight ||
        (
          !did_iup &&
          ((gs.is_composite && gs.freedom_vector.y != 0) || touched_y)
        ) {
        self.graphics.move_zp2_point(p, dx, dy, true)
      }
    } else {
      self.graphics.move_zp2_point(p, dx, dy, true)
    }
  }
  ()
}

///|
fn TtEngine::op_msirp(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let gs = self.graphics
  let distance = self.value_stack.pop()
  let point_ix = self.value_stack.pop_usize()
  if !gs.is_pedantic &&
    (!tt_in_bounds(gs, gs.zp1, point_ix) || !tt_in_bounds(gs, gs.zp0, gs.rp0)) {
    return ()
  }
  if gs.zp1.is_twilight() {
    let zp0z = gs.zp0_zone()
    let orig = zp0z.original_point(gs.rp0)
    let zp1z = gs.zp1_zone()
    zp1z.set_point(point_ix, orig)
    zp1z.set_original_point(point_ix, orig)
    self.graphics.move_point(gs.zp1, point_ix, distance)
    let p1 = zp1z.original_point(point_ix)
    zp1z.set_point(point_ix, p1)
  }
  let d = self.graphics.project(
    gs.zp1_zone().point(point_ix),
    gs.zp0_zone().point(gs.rp0),
  )
  self.graphics.move_point(gs.zp1, point_ix, distance - d)
  self.graphics.rp1 = gs.rp0
  self.graphics.rp2 = point_ix
  if (opcode & 1) != 0 {
    self.graphics.rp0 = point_ix
  }
  ()
}

///|
fn TtEngine::op_mdap(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let p = self.value_stack.pop_usize()
  let gs = self.graphics
  if !gs.is_pedantic && !tt_in_bounds(gs, gs.zp0, p) {
    self.graphics.rp0 = p
    self.graphics.rp1 = p
    return ()
  }
  let distance = if (opcode & 1) != 0 {
    let cur_dist = self.graphics.project(gs.zp0_zone().point(p), { x: 0, y: 0, })
    self.graphics.round(cur_dist) - cur_dist
  } else {
    0
  }
  self.graphics.move_point(gs.zp0, p, distance)
  self.graphics.rp0 = p
  self.graphics.rp1 = p
  ()
}

///|
fn TtEngine::op_miap(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let cvt_entry = self.value_stack.pop_usize()
  let point_ix = self.value_stack.pop_usize()
  if cvt_entry < 0 || cvt_entry >= self.cvt.length() {
    raise InvalidCvtIndex(cvt_entry)
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
    z.set_original_point(point_ix, original_point)
    z.set_point(point_ix, original_point)
  }
  let original_distance = self.graphics.project(gs.zp0_zone().point(point_ix), {
    x: 0,
    y: 0,
  })
  if (opcode & 1) != 0 {
    let delta = tt_abs_i(distance - original_distance)
    if delta > gs.retained.control_value_cutin {
      distance = original_distance
    }
    distance = self.graphics.round(distance)
  }
  self.graphics.move_point(gs.zp0, point_ix, distance - original_distance)
  self.graphics.rp0 = point_ix
  self.graphics.rp1 = point_ix
  ()
}

///|
fn TtEngine::op_mdrp(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let p = self.value_stack.pop_usize()
  let gs = self.graphics
  if !gs.is_pedantic &&
    (!tt_in_bounds(gs, gs.zp1, p) || !tt_in_bounds(gs, gs.zp0, gs.rp0)) {
    self.graphics.rp1 = gs.rp0
    self.graphics.rp2 = p
    if (opcode & 16) != 0 {
      self.graphics.rp0 = p
    }
    return ()
  }
  let mut original_distance = if gs.zp0.is_twilight() || gs.zp1.is_twilight() {
    self.graphics.dual_project(
      gs.zp1_zone().original_point(p),
      gs.zp0_zone().original_point(gs.rp0),
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
    gs.zp1_zone().point(p),
    gs.zp0_zone().point(gs.rp0),
  )
  self.graphics.move_point(gs.zp1, p, distance - cur)
  self.graphics.rp1 = gs.rp0
  self.graphics.rp2 = p
  if (opcode & 16) != 0 {
    self.graphics.rp0 = p
  }
  ()
}

///|
fn TtEngine::op_mirp(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let n = {
    let v = self.value_stack.pop()
    v + 1
  }
  let p = self.value_stack.pop_usize()
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
    return ()
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
    let p2 = gs.zp0_zone().original_point(gs.rp0)
    let p1 = TtPoint::{
      x: p2.x + tt_hint_mul14(d, fv.x),
      y: p2.y + tt_hint_mul14(d, fv.y),
    }
    let z1 = gs.zp1_zone()
    z1.set_original_point(p, p1)
    z1.set_point(p, p1)
  }
  let original_distance = self.graphics.dual_project(
    gs.zp1_zone().original_point(p),
    gs.zp0_zone().original_point(gs.rp0),
  )
  let current_distance = self.graphics.project(
    gs.zp1_zone().point(p),
    gs.zp0_zone().point(gs.rp0),
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
  self.graphics.move_point(gs.zp1, p, distance - current_distance)
  self.graphics.rp1 = gs.rp0
  if (opcode & 16) != 0 {
    self.graphics.rp0 = p
  }
  self.graphics.rp2 = p
  ()
}

///|
fn TtEngine::op_alignrp(self : TtEngine) -> Unit raise HintError {
  let gs = self.graphics
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  for _ in 0..<count {
    let p = self.value_stack.pop_usize()
    let distance = self.graphics.project(
      gs.zp1_zone().point(p),
      gs.zp0_zone().point(gs.rp0),
    )
    self.graphics.move_point(gs.zp1, p, -distance)
  }
  ()
}

///|
fn TtEngine::op_isect(self : TtEngine) -> Unit raise HintError {
  let gs = self.graphics
  let b1 = self.value_stack.pop_usize()
  let b0 = self.value_stack.pop_usize()
  let a1 = self.value_stack.pop_usize()
  let a0 = self.value_stack.pop_usize()
  let point_ix = self.value_stack.pop_usize()
  let z1 = gs.zp1_zone()
  let pa0 = z1.point(a0)
  let pa1 = z1.point(a1)
  let z0 = gs.zp0_zone()
  let pb0 = z0.point(b0)
  let pb1 = z0.point(b1)
  let dbx = pb1.x - pb0.x
  let dby = pb1.y - pb0.y
  let dax = pa1.x - pa0.x
  let day = pa1.y - pa0.y
  let dx = pb0.x - pa0.x
  let dy = pb0.y - pa0.y
  let discriminant = tt_mul_div26(dax, -dby, 0x40) +
    tt_mul_div26(day, dbx, 0x40)
  let dotproduct = tt_mul_div26(dax, dbx, 0x40) + tt_mul_div26(day, dby, 0x40)
  let z2 = gs.zp2_zone()
  let (new_x, new_y) = if tt_abs_i(discriminant).to_int64() * 19 >
    tt_abs_i(dotproduct).to_int64() {
    let v = tt_mul_div26(dx, -dby, 0x40) + tt_mul_div26(dy, dbx, 0x40)
    let x = tt_mul_div26(v, dax, discriminant)
    let y = tt_mul_div26(v, day, discriminant)
    (pa0.x + x, pa0.y + y)
  } else {
    ((pa0.x + pa1.x + pb0.x + pb1.x) / 4, (pa0.y + pa1.y + pb0.y + pb1.y) / 4)
  }
  z2.set_point(point_ix, { x: new_x, y: new_y, })
  z2.touch(point_ix, X)
  z2.touch(point_ix, Y)
}

///|
fn TtEngine::op_alignpts(self : TtEngine) -> Unit raise HintError {
  let p2 = self.value_stack.pop_usize()
  let p1 = self.value_stack.pop_usize()
  let gs = self.graphics
  let distance = self.graphics.project(
      gs.zp0_zone().point(p2),
      gs.zp1_zone().point(p1),
    ) /
    2
  self.graphics.move_point(gs.zp1, p1, distance)
  self.graphics.move_point(gs.zp0, p2, -distance)
}

///|
fn tt_mul_div26(a : Int32, b : Int32, c : Int32) -> Int32 {
  tt_mul_div_round(a, b, c)
}

///|
fn TtEngine::op_ip(self : TtEngine) -> Unit raise HintError {
  let gs = self.graphics
  let count = gs.loop_counter
  self.graphics.loop_counter = 1
  if !gs.is_pedantic &&
    (!tt_in_bounds(gs, gs.zp0, gs.rp1) || !tt_in_bounds(gs, gs.zp1, gs.rp2)) {
    return ()
  }
  let in_twilight = gs.zp0.is_twilight() ||
    gs.zp1.is_twilight() ||
    gs.zp2.is_twilight()
  let orus_base = if in_twilight {
    gs.zp0_zone().original_point(gs.rp1)
  } else {
    gs.zp0_zone().unscaled_point(gs.rp1)
  }
  let cur_base = gs.zp0_zone().point(gs.rp1)
  let old_range = if in_twilight {
    self.graphics.dual_project(gs.zp1_zone().original_point(gs.rp2), orus_base)
  } else {
    self.graphics.dual_project_unscaled(
      gs.zp1_zone().unscaled_point(gs.rp2),
      orus_base,
    )
  }
  let cur_range = self.graphics.project(gs.zp1_zone().point(gs.rp2), cur_base)
  for _ in 0..<count {
    let point = self.value_stack.pop_usize()
    if !gs.is_pedantic && !tt_in_bounds(gs, gs.zp2, point) {
      continue
    }
    let original_distance = if in_twilight {
      self.graphics.dual_project(gs.zp2_zone().original_point(point), orus_base)
    } else {
      self.graphics.dual_project_unscaled(
        gs.zp2_zone().unscaled_point(point),
        orus_base,
      )
    }
    let cur_distance = self.graphics.project(
      gs.zp2_zone().point(point),
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
    self.graphics.move_point(gs.zp2, point, new_distance - cur_distance)
  }
  ()
}

///|
fn TtEngine::op_iup(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let axis = if (opcode & 1) != 0 { TtAxis::X } else { Y }
  let mut run = true
  if self.graphics.backward_compatibility {
    if self.graphics.did_iup_x && self.graphics.did_iup_y {
      run = false
    }
    if axis is X {
      self.graphics.did_iup_x = true
    } else {
      self.graphics.did_iup_y = true
    }
  }
  if run {
    let glyph = self.graphics.glyph
    glyph.iup(axis)
  }
  ()
}

///|
fn TtEngine::op_utp(self : TtEngine) -> Unit raise HintError {
  let p = self.value_stack.pop_usize()
  let has_x = self.graphics.freedom_vector.x != 0
  let has_y = self.graphics.freedom_vector.y != 0
  if !has_x && !has_y {
    return ()
  }
  let z0 = self.graphics.zp0_zone()
  if has_x {
    z0.untouch(p, X)
  }
  if has_y {
    z0.untouch(p, Y)
  }
  ()
}
