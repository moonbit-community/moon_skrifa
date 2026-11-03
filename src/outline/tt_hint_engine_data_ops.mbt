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
fn tt_scale_unscaled_to_pixels(gs : TtGraphicsState, dist : Int32) -> Int32 {
  // dist (font units) * scale_bits (16.16, includes *64) => 26.6
  // Match fontations `math::mul` sign-aware rounding.
  tt_hint_mul_16_16(dist, gs.unscaled_to_pixels())
}

///|
fn tt_in_bounds_zone(zone : TtZone, p : Int32) -> Bool {
  p >= 0 && p < zone.points.length()
}

///|
fn TtEngine::op_mps(self : TtEngine) -> Unit raise HintError {
  self.value_stack.push(self.graphics.retained.ppem * 64)
}

///|
fn TtEngine::op_gc(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let p = self.value_stack.pop_usize()
  let gs = self.graphics
  let zone = gs.zp2_zone()
  if !gs.is_pedantic && !tt_in_bounds_zone(zone, p) {
    return self.value_stack.push(0)
  }
  let value = if (opcode & 1) != 0 {
    // original scaled
    let op = zone.original_point(p)
    gs.dual_project(op, { x: 0, y: 0, })
  } else {
    let cp = zone.point(p)
    gs.project(cp, { x: 0, y: 0, })
  }
  self.value_stack.push(value)
}

///|
fn TtEngine::op_scfs(self : TtEngine) -> Unit raise HintError {
  let value = self.value_stack.pop()
  let p = self.value_stack.pop_usize()
  let gs = self.graphics
  let cur = gs.zp2_zone().point(p)
  let projection = gs.project(cur, { x: 0, y: 0, })
  gs.move_point(gs.zp2, p, value - projection)
  // If moving a twilight point, also update its original position.
  if gs.zp2 is Twilight {
    let twilight = gs.twilight
    let tp = twilight.point(p)
    twilight.set_original_point(p, tp)
  }
  ()
}

///|
fn TtEngine::op_md(self : TtEngine, opcode : Int32) -> Unit raise HintError {
  let p1 = self.value_stack.pop_usize()
  let p2 = self.value_stack.pop_usize()
  let gs = self.graphics
  let z0 = gs.zp0_zone()
  let z1 = gs.zp1_zone()
  if !gs.is_pedantic &&
    (!tt_in_bounds_zone(z0, p2) || !tt_in_bounds_zone(z1, p1)) {
    return self.value_stack.push(0)
  }
  let distance = if (opcode & 1) != 0 {
    // measure in grid fitted outline
    let a = z0.point(p2)
    let b = z1.point(p1)
    gs.project(a, b)
  } else if gs.zp0 is Twilight || gs.zp1 is Twilight {
    let a = z0.original_point(p2)
    let b = z1.original_point(p1)
    gs.dual_project(a, b)
  } else {
    let a = z0.unscaled_point(p2)
    let b = z1.unscaled_point(p1)
    let unscaled = gs.dual_project_unscaled(a, b)
    tt_scale_unscaled_to_pixels(gs, unscaled)
  }
  self.value_stack.push(distance)
}
