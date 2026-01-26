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
/// Data read/write instruction implementations (GC/SCFS/MD) for the TT engine.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/engine/data.rs`
/// (Apache-2.0 OR MIT).
fn tt_scale_unscaled_to_pixels(gs : TtGraphicsState, dist : Int) -> Int {
  // dist (font units) * scale_bits (16.16, includes *64) => 26.6
  // Match fontations `math::mul` sign-aware rounding.
  tt_hint_mul_16_16(dist, gs.unscaled_to_pixels())
}

///|
fn tt_in_bounds_zone(zone : TtZone, p : Int) -> Bool {
  p >= 0 && p < zone.points.length()
}

///|
fn TtEngine::op_gc(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let gs = self.graphics
  let zone = gs.zp2_zone()
  if !gs.is_pedantic && !tt_in_bounds_zone(zone, p) {
    return self.value_stack.push(0)
  }
  let value = if (opcode & 1) != 0 {
    // original scaled
    let op = match zone.original_point(p) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    gs.dual_project(op, TtPoint::{ x: 0, y: 0 })
  } else {
    let cp = match zone.point(p) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    gs.project(cp, TtPoint::{ x: 0, y: 0 })
  }
  self.value_stack.push(value)
}

///|
fn TtEngine::op_scfs(self : TtEngine) -> Result[Unit, HintError] {
  let value = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let p = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let gs = self.graphics
  let cur = match gs.zp2_zone().point(p) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let projection = gs.project(cur, TtPoint::{ x: 0, y: 0 })
  match gs.move_point(gs.zp2, p, value - projection) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  // If moving a twilight point, also update its original position.
  if gs.zp2 is TtZonePointer::Twilight {
    let twilight = gs.twilight
    let tp = match twilight.point(p) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    match twilight.set_original_point(p, tp) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
fn TtEngine::op_md(self : TtEngine, opcode : Int) -> Result[Unit, HintError] {
  let p1 = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let p2 = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let gs = self.graphics
  let z0 = gs.zp0_zone()
  let z1 = gs.zp1_zone()
  if !gs.is_pedantic &&
    (!tt_in_bounds_zone(z0, p2) || !tt_in_bounds_zone(z1, p1)) {
    return self.value_stack.push(0)
  }
  let distance = if (opcode & 1) != 0 {
    // measure in grid fitted outline
    let a = match z0.point(p2) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let b = match z1.point(p1) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    gs.project(a, b)
  } else if gs.zp0 is TtZonePointer::Twilight ||
    gs.zp1 is TtZonePointer::Twilight {
    let a = match z0.original_point(p2) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let b = match z1.original_point(p1) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    gs.dual_project(a, b)
  } else {
    let a = z0.unscaled_point(p2)
    let b = z1.unscaled_point(p1)
    let unscaled = gs.dual_project_unscaled(a, b)
    tt_scale_unscaled_to_pixels(gs, unscaled)
  }
  self.value_stack.push(distance)
}
