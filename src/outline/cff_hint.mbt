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
/// CFF/CFF2 (Type2) stem hinting for Y coordinates.
///
/// Ported from `fontations/skrifa/src/outline/cff/hint.rs`.

///|
const CFF_FIXED_ONE_BITS : Int = 0x0001_0000

///|
const CFF_FIXED_ZERO_BITS : Int = 0

///|
const CFF_FIXED_MAX_BITS : Int = 0x7FFF_FFFF

///|
const CFF_FIXED_INT_MASK : Int = 0xFFFF_0000

///|
priv struct CffFixed {
  bits : Int
}

///|
fn CffFixed::from_bits(bits : Int) -> CffFixed {
  CffFixed::{ bits, }
}

///|
fn CffFixed::zero() -> CffFixed {
  CffFixed::from_bits(CFF_FIXED_ZERO_BITS)
}

///|
fn CffFixed::one() -> CffFixed {
  CffFixed::from_bits(CFF_FIXED_ONE_BITS)
}

///|
fn CffFixed::max() -> CffFixed {
  CffFixed::from_bits(CFF_FIXED_MAX_BITS)
}

///|
fn CffFixed::from_i32(v : Int) -> CffFixed {
  CffFixed::from_bits(v << 16)
}

///|
fn CffFixed::from_f64(v : Double) -> CffFixed {
  // Match typical Fixed::from_f64 rounding.
  CffFixed::from_bits((v * 65536.0).round().to_int())
}

///|
fn CffFixed::abs(self : CffFixed) -> CffFixed {
  if self.bits < 0 {
    CffFixed::from_bits(-self.bits)
  } else {
    self
  }
}

///|
fn CffFixed::max_with(self : CffFixed, other : CffFixed) -> CffFixed {
  if self.bits >= other.bits {
    self
  } else {
    other
  }
}

///|
fn CffFixed::min_with(self : CffFixed, other : CffFixed) -> CffFixed {
  if self.bits <= other.bits {
    self
  } else {
    other
  }
}

///|
fn CffFixed::wrapping_add(self : CffFixed, other : CffFixed) -> CffFixed {
  let a = self.bits.reinterpret_as_uint()
  let b = other.bits.reinterpret_as_uint()
  CffFixed::from_bits((a + b).reinterpret_as_int())
}

///|
fn CffFixed::wrapping_sub(self : CffFixed, other : CffFixed) -> CffFixed {
  let a = self.bits.reinterpret_as_uint()
  let b = other.bits.reinterpret_as_uint()
  CffFixed::from_bits((a - b).reinterpret_as_int())
}

///|
fn CffFixed::add(self : CffFixed, other : CffFixed) -> CffFixed {
  CffFixed::from_bits(self.bits + other.bits)
}

///|
fn CffFixed::sub(self : CffFixed, other : CffFixed) -> CffFixed {
  CffFixed::from_bits(self.bits - other.bits)
}

///|
fn CffFixed::neg(self : CffFixed) -> CffFixed {
  CffFixed::from_bits(-self.bits)
}

///|
fn cff_fixed_mul_bits(a_bits : Int, b_bits : Int) -> Int {
  // Match fontations `Fixed` multiplication:
  //   ((ab + 0x8000 - (ab < 0)) >> 16)
  //
  // Use Int64 intermediates to avoid overflow (MoonBit Int is 32-bit on wasm).
  let ab : Int64 = a_bits.to_int64() * b_bits.to_int64()
  let adj : Int64 = (0x8000).to_int64() -
    (if ab < 0 { 1 } else { 0 }).to_int64()
  let q : Int64 = (ab + adj) >> 16
  if q > (0x7FFF_FFFF).to_int64() {
    0x7FFF_FFFF
  } else if q < (-2147483648).to_int64() {
    -2147483648
  } else {
    q.to_int()
  }
}

///|
fn CffFixed::mul(self : CffFixed, other : CffFixed) -> CffFixed {
  CffFixed::from_bits(cff_fixed_mul_bits(self.bits, other.bits))
}

///|
fn CffFixed::div(self : CffFixed, other : CffFixed) -> CffFixed {
  // Match fontations `Fixed` division:
  //   ((((a as u64) << 16) + ((b as u64) >> 1)) / b) with sign handling.
  let mut sign = 1
  let mut a : Int64 = self.bits.to_int64()
  let mut b : Int64 = other.bits.to_int64()
  if a < 0 {
    a = -a
    sign = -1
  }
  if b < 0 {
    b = -b
    sign = -sign
  }
  let q : Int64 = if b == 0 {
    (0x7FFF_FFFF).to_int64()
  } else {
    let num : Int64 = (a << 16) + (b >> 1)
    num / b
  }
  let q = if q > (0x7FFF_FFFF).to_int64() {
    (0x7FFF_FFFF).to_int64()
  } else {
    q
  }
  let out : Int64 = if sign < 0 { -q } else { q }
  CffFixed::from_bits(out.to_int())
}

///|
fn CffFixed::mul_div(self : CffFixed, b : CffFixed, c : CffFixed) -> CffFixed {
  // Match fontations `Fixed::mul_div`:
  //   su*au + (bu>>1) / bu, with sign handling and bu==0 -> 0x7FFFFFFF.
  let mut sign = 1
  let mut su : Int64 = self.bits.to_int64()
  let mut au : Int64 = b.bits.to_int64()
  let mut bu : Int64 = c.bits.to_int64()
  if su < 0 {
    su = -su
    sign = -1
  }
  if au < 0 {
    au = -au
    sign = -sign
  }
  if bu < 0 {
    bu = -bu
    sign = -sign
  }
  let result : Int64 = if bu > 0 {
    // + (bu>>1) implements rounding to nearest.
    (su * au + (bu >> 1)) / bu
  } else {
    (0x7FFF_FFFF).to_int64()
  }
  let q = if result > (0x7FFF_FFFF).to_int64() {
    (0x7FFF_FFFF).to_int64()
  } else {
    result
  }
  let out : Int64 = if sign < 0 { -q } else { q }
  CffFixed::from_bits(out.to_int())
}

///|
fn CffFixed::round(self : CffFixed) -> CffFixed {
  // Equivalent to (x + 0x8000) & ~0xFFFF for two's complement.
  CffFixed::from_bits((self.bits + 0x8000) & CFF_FIXED_INT_MASK)
}

///|
fn CffFixed::fract(self : CffFixed) -> CffFixed {
  // Match fontations `Fixed::fract()`:
  //   fract = bits - floor(bits)
  // where floor() rounds toward -inf for negative values.
  let floor_bits = self.bits & CFF_FIXED_INT_MASK
  CffFixed::from_bits(self.bits - floor_bits)
}

///|
fn cff_hint_trunc(value : CffFixed) -> CffFixed {
  CffFixed::from_bits(value.bits & (0x3FF |> Int::lnot))
}

///|
fn cff_hint_half(value : CffFixed) -> CffFixed {
  CffFixed::from_bits(value.bits / 2)
}

///|
fn cff_hint_twice(value : CffFixed) -> CffFixed {
  let a = value.bits.reinterpret_as_uint()
  CffFixed::from_bits((a * 2).reinterpret_as_int())
}

///|
fn cff_hint_midpoint(a : CffFixed, b : CffFixed) -> CffFixed {
  a.add(cff_hint_half(b.sub(a)))
}

///|
const CFF_HINT_ICF_TOP_BITS : Int = 880 << 16

///|
const CFF_HINT_ICF_BOTTOM_BITS : Int = -120 << 16

///|
const CFF_HINT_MAX_BLUES : Int = 7

///|
const CFF_HINT_MAX_OTHER_BLUES : Int = 5

///|
const CFF_HINT_MAX_BLUE_ZONES : Int = CFF_HINT_MAX_BLUES +
  CFF_HINT_MAX_OTHER_BLUES

///|
const CFF_HINT_MAX_HINTS : Int = 96

///|
const CFF_HINT_MASK_SIZE : Int = (CFF_HINT_MAX_HINTS + 7) / 8

///|
const CFF_HINT_MIN_COUNTER_BITS : Int = 0x8000

///|
const CFF_HINT_EPSILON_BITS : Int = 1

///|
priv struct CffBlues {
  pairs : Array[(CffFixed, CffFixed)]
}

///|
fn CffBlues::default() -> CffBlues {
  CffBlues::{ pairs: Array::new() }
}

///|
fn CffBlues::new(values : ArrayView[CffFixed]) -> CffBlues {
  let pairs : Array[(CffFixed, CffFixed)] = Array::new()
  let n = values.length()
  let mut i = 0
  while i + 1 < n {
    pairs.push((values.at(i), values.at(i + 1)))
    i = i + 2
  }
  CffBlues::{ pairs, }
}

///|
fn CffBlues::values(self : CffBlues) -> ArrayView[(CffFixed, CffFixed)] {
  self.pairs.op_as_view()
}

///|
priv struct HintParams {
  mut blues : CffBlues
  mut family_blues : CffBlues
  mut other_blues : CffBlues
  mut family_other_blues : CffBlues
  mut blue_scale : CffFixed
  mut blue_shift : CffFixed
  mut blue_fuzz : CffFixed
  mut language_group : Int
}

///|
fn HintParams::default() -> HintParams {
  HintParams::{
    blues: CffBlues::default(),
    other_blues: CffBlues::default(),
    family_blues: CffBlues::default(),
    family_other_blues: CffBlues::default(),
    blue_scale: CffFixed::from_f64(0.039625),
    blue_shift: CffFixed::from_i32(7),
    blue_fuzz: CffFixed::one(),
    language_group: 0,
  }
}

///|
priv struct BlueZone {
  mut is_bottom : Bool
  mut cs_bottom_edge : CffFixed
  mut cs_top_edge : CffFixed
  mut cs_flat_edge : CffFixed
  mut ds_flat_edge : CffFixed
}

///|
fn BlueZone::default() -> BlueZone {
  BlueZone::{
    is_bottom: false,
    cs_bottom_edge: CffFixed::zero(),
    cs_top_edge: CffFixed::zero(),
    cs_flat_edge: CffFixed::zero(),
    ds_flat_edge: CffFixed::zero(),
  }
}

///|
priv struct HintState {
  mut scale : CffFixed
  mut blue_scale : CffFixed
  mut blue_shift : CffFixed
  mut blue_fuzz : CffFixed
  mut language_group : Int
  mut suppress_overshoot : Bool
  mut do_em_box_hints : Bool
  mut boost : CffFixed
  mut darken_y : CffFixed
  mut zones : Array[BlueZone]
  mut zone_count : Int
}

///|
fn HintState::default() -> HintState {
  let zones : Array[BlueZone] = Array::new()
  for _ in 0..<CFF_HINT_MAX_BLUE_ZONES {
    zones.push(BlueZone::default())
  }
  HintState::{
    scale: CffFixed::zero(),
    blue_scale: CffFixed::zero(),
    blue_shift: CffFixed::zero(),
    blue_fuzz: CffFixed::zero(),
    language_group: 0,
    suppress_overshoot: false,
    do_em_box_hints: false,
    boost: CffFixed::zero(),
    darken_y: CffFixed::zero(),
    zones,
    zone_count: 0,
  }
}

///|
fn HintState::new(params : HintParams, scale : CffFixed) -> HintState {
  let st = HintState::default()
  st.scale = scale
  st.blue_scale = params.blue_scale
  st.blue_shift = params.blue_shift
  st.blue_fuzz = params.blue_fuzz
  st.language_group = params.language_group
  st.suppress_overshoot = false
  st.do_em_box_hints = false
  st.boost = CffFixed::zero()
  st.darken_y = CffFixed::zero()
  st.zone_count = 0
  HintState::build_zones(st, params)
  st
}

///|
fn HintState::zones(self : HintState) -> ArrayView[BlueZone] {
  self.zones.sub(start=0, end=self.zone_count).op_as_view()
}

///|
fn HintState::build_zones(self : HintState, params : HintParams) -> Unit {
  self.do_em_box_hints = false
  // Special language group behavior.
  let blues0 = params.blues.values()
  match (self.language_group, blues0.length()) {
    (1, 2) => {
      let (b0, t0) = blues0.at(0)
      let (b1, t1) = blues0.at(1)
      if b0.bits < CFF_HINT_ICF_BOTTOM_BITS &&
        t0.bits < CFF_HINT_ICF_BOTTOM_BITS &&
        b1.bits > CFF_HINT_ICF_TOP_BITS &&
        t1.bits > CFF_HINT_ICF_TOP_BITS {
        self.do_em_box_hints = true
        return
      }
    }
    (1, 0) => {
      self.do_em_box_hints = true
      return
    }
    _ => ()
  }
  let zones : Array[BlueZone] = Array::new()
  for _ in 0..<CFF_HINT_MAX_BLUE_ZONES {
    zones.push(BlueZone::default())
  }
  let mut max_zone_height = CffFixed::zero()
  let mut zone_ix = 0
  let blues = params.blues.values()
  let mut b_ix = 0
  while b_ix < blues.length() && b_ix < CFF_HINT_MAX_BLUES {
    let (bottom, top) = blues.at(b_ix)
    let zone_height = top.sub(bottom)
    if zone_height.bits < 0 {
      b_ix = b_ix + 1
      continue
    }
    max_zone_height = max_zone_height.max_with(zone_height)
    let zone = zones.at(zone_ix)
    zone.cs_bottom_edge = bottom
    zone.cs_top_edge = top
    if zone_ix == 0 {
      zone.is_bottom = true
      zone.cs_flat_edge = top
    } else {
      zone.is_bottom = false
      zone.cs_top_edge = zone.cs_top_edge.add(cff_hint_twice(self.darken_y))
      zone.cs_bottom_edge = zone.cs_bottom_edge.add(
        cff_hint_twice(self.darken_y),
      )
      zone.cs_flat_edge = zone.cs_bottom_edge
    }
    zone_ix = zone_ix + 1
    b_ix = b_ix + 1
  }
  let other_blues = params.other_blues.values()
  let mut ob_ix = 0
  while ob_ix < other_blues.length() && ob_ix < CFF_HINT_MAX_OTHER_BLUES {
    let (bottom, top) = other_blues.at(ob_ix)
    let zone_height = top.sub(bottom)
    if zone_height.bits < 0 {
      ob_ix = ob_ix + 1
      continue
    }
    max_zone_height = max_zone_height.max_with(zone_height)
    let zone = zones.at(zone_ix)
    zone.is_bottom = true
    zone.cs_bottom_edge = bottom
    zone.cs_top_edge = top
    zone.cs_flat_edge = top
    zone_ix = zone_ix + 1
    ob_ix = ob_ix + 1
  }

  // Adjust for family blues.
  let units_per_pixel = CffFixed::one().div(self.scale)
  for z in 0..<zone_ix {
    let zone = zones.at(z)
    let flat0 = zone.cs_flat_edge
    let mut min_diff = CffFixed::max()
    if zone.is_bottom {
      let fam_other = params.family_other_blues.values()
      for j in 0..<fam_other.length() {
        let (_b, t) = fam_other.at(j)
        let family_flat = t
        let diff = flat0.sub(family_flat).abs()
        if diff.bits < min_diff.bits && diff.bits < units_per_pixel.bits {
          zone.cs_flat_edge = family_flat
          min_diff = diff
          if diff.bits == 0 {
            break
          }
        }
      }
      let fam_blues = params.family_blues.values()
      if fam_blues.length() > 0 {
        let (_, family_top) = fam_blues.at(0)
        let diff = flat0.sub(family_top).abs()
        if diff.bits < min_diff.bits && diff.bits < units_per_pixel.bits {
          zone.cs_flat_edge = family_top
        }
      }
    } else {
      let fam_blues = params.family_blues.values()
      for j in 1..<fam_blues.length() {
        let (bottom, _top) = fam_blues.at(j)
        let family_flat = bottom.add(cff_hint_twice(self.darken_y))
        let diff = flat0.sub(family_flat).abs()
        if diff.bits < min_diff.bits && diff.bits < units_per_pixel.bits {
          zone.cs_flat_edge = family_flat
          min_diff = diff
          if diff.bits == 0 {
            break
          }
        }
      }
    }
  }
  if max_zone_height.bits > 0 {
    let max_scale = CffFixed::one().div(max_zone_height)
    if self.blue_scale.bits > max_scale.bits {
      self.blue_scale = max_scale
    }
  }
  if self.scale.bits < self.blue_scale.bits {
    self.suppress_overshoot = true
    let c06 = CffFixed::from_f64(0.6)
    self.boost = c06.sub(c06.mul_div(self.scale, self.blue_scale))
    self.boost = self.boost.min_with(CffFixed::from_bits(0x7FFF))
  }
  if self.darken_y.bits != 0 {
    self.boost = CffFixed::zero()
  }
  let scale = self.scale
  let boost0 = self.boost
  for z in 0..<zone_ix {
    let zone = zones.at(z)
    let boost = if zone.is_bottom { boost0.neg() } else { boost0 }
    zone.ds_flat_edge = zone.cs_flat_edge.mul(scale).add(boost).round()
  }
  self.zones = zones
  self.zone_count = zone_ix
}

///|
// Hint flags
const CFF_HINT_GHOST_BOTTOM : Int = 0x1

///|
const CFF_HINT_GHOST_TOP : Int = 0x2

///|
const CFF_HINT_PAIR_BOTTOM : Int = 0x4

///|
const CFF_HINT_PAIR_TOP : Int = 0x8

///|
const CFF_HINT_LOCKED : Int = 0x10

///|
const CFF_HINT_SYNTHETIC : Int = 0x20

///|
priv struct StemHint {
  mut is_used : Bool
  mut min : CffFixed
  mut max : CffFixed
  mut ds_min : CffFixed
  mut ds_max : CffFixed
}

///|
fn StemHint::default() -> StemHint {
  StemHint::{
    is_used: false,
    min: CffFixed::zero(),
    max: CffFixed::zero(),
    ds_min: CffFixed::zero(),
    ds_max: CffFixed::zero(),
  }
}

///|
priv struct Hint {
  mut flags : Int
  mut index : Int
  mut cs_coord : CffFixed
  mut ds_coord : CffFixed
  mut scale : CffFixed
}

///|
fn Hint::default() -> Hint {
  Hint::{
    flags: 0,
    index: 0,
    cs_coord: CffFixed::zero(),
    ds_coord: CffFixed::zero(),
    scale: CffFixed::zero(),
  }
}

///|
fn Hint::is_valid(self : Hint) -> Bool {
  self.flags != 0
}

///|
fn Hint::is_bottom(self : Hint) -> Bool {
  (self.flags & (CFF_HINT_GHOST_BOTTOM | CFF_HINT_PAIR_BOTTOM)) != 0
}

///|
fn Hint::is_top(self : Hint) -> Bool {
  (self.flags & (CFF_HINT_GHOST_TOP | CFF_HINT_PAIR_TOP)) != 0
}

///|
fn Hint::is_pair(self : Hint) -> Bool {
  (self.flags & (CFF_HINT_PAIR_BOTTOM | CFF_HINT_PAIR_TOP)) != 0
}

///|
fn Hint::is_pair_top(self : Hint) -> Bool {
  (self.flags & CFF_HINT_PAIR_TOP) != 0
}

///|
fn Hint::is_locked(self : Hint) -> Bool {
  (self.flags & CFF_HINT_LOCKED) != 0
}

///|
fn Hint::is_synthetic(self : Hint) -> Bool {
  (self.flags & CFF_HINT_SYNTHETIC) != 0
}

///|
fn Hint::lock(self : Hint) -> Unit {
  self.flags = self.flags | CFF_HINT_LOCKED
}

///|
fn Hint::setup(
  self : Hint,
  stem : StemHint,
  index : Int,
  origin : CffFixed,
  scale : CffFixed,
  darken_y : CffFixed,
  is_bottom : Bool,
) -> Unit {
  // "Ghost hints" have special widths -21 (bottom) and -20 (top).
  let ghost_bottom_width = CffFixed::from_i32(-21)
  let ghost_top_width = CffFixed::from_i32(-20)
  let width = stem.max.sub(stem.min)
  if width.bits == ghost_bottom_width.bits {
    if is_bottom {
      self.cs_coord = stem.max
      self.flags = CFF_HINT_GHOST_BOTTOM
    } else {
      self.flags = 0
    }
  } else if width.bits == ghost_top_width.bits {
    if !is_bottom {
      self.cs_coord = stem.min
      self.flags = CFF_HINT_GHOST_TOP
    } else {
      self.flags = 0
    }
  } else if width.bits < 0 {
    if is_bottom {
      self.cs_coord = stem.max
      self.flags = CFF_HINT_PAIR_BOTTOM
    } else {
      self.cs_coord = stem.min
      self.flags = CFF_HINT_PAIR_TOP
    }
  } else if is_bottom {
    self.cs_coord = stem.min
    self.flags = CFF_HINT_PAIR_BOTTOM
  } else {
    self.cs_coord = stem.max
    self.flags = CFF_HINT_PAIR_TOP
  }
  if Hint::is_top(self) {
    self.cs_coord = self.cs_coord.add(cff_hint_twice(darken_y))
  }
  self.cs_coord = self.cs_coord.add(origin)
  self.scale = scale
  self.index = index
  if self.flags != 0 && stem.is_used {
    self.ds_coord = if Hint::is_top(self) { stem.ds_max } else { stem.ds_min }
    Hint::lock(self)
  } else {
    self.ds_coord = self.cs_coord.mul(scale)
  }
}

///|
fn HintState::capture(
  self : HintState,
  bottom_edge : Hint,
  top_edge : Hint,
) -> Bool {
  let fuzz = self.blue_fuzz
  let mut captured = false
  let mut adjustment = CffFixed::zero()
  for zone in HintState::zones(self).iter() {
    if zone.is_bottom &&
      Hint::is_bottom(bottom_edge) &&
      zone.cs_bottom_edge.wrapping_sub(fuzz).bits <= bottom_edge.cs_coord.bits &&
      bottom_edge.cs_coord.bits <= zone.cs_top_edge.wrapping_add(fuzz).bits {
      adjustment = if self.suppress_overshoot {
        zone.ds_flat_edge
      } else if zone.cs_top_edge.wrapping_sub(bottom_edge.cs_coord).bits >=
        self.blue_shift.bits {
        bottom_edge.ds_coord
        .round()
        .min_with(zone.ds_flat_edge.sub(CffFixed::one()))
      } else {
        bottom_edge.ds_coord.round()
      }
      adjustment = adjustment.sub(bottom_edge.ds_coord)
      captured = true
      break
    }
    if !zone.is_bottom &&
      Hint::is_top(top_edge) &&
      zone.cs_bottom_edge.wrapping_sub(fuzz).bits <= top_edge.cs_coord.bits &&
      top_edge.cs_coord.bits <= zone.cs_top_edge.wrapping_add(fuzz).bits {
      adjustment = if self.suppress_overshoot {
        zone.ds_flat_edge
      } else if top_edge.cs_coord.wrapping_sub(zone.cs_bottom_edge).bits >=
        self.blue_shift.bits {
        top_edge.ds_coord
        .round()
        .max_with(zone.ds_flat_edge.add(CffFixed::one()))
      } else {
        top_edge.ds_coord.round()
      }
      adjustment = adjustment.sub(top_edge.ds_coord)
      captured = true
      break
    }
  }
  if captured {
    if Hint::is_valid(bottom_edge) {
      bottom_edge.ds_coord = bottom_edge.ds_coord.add(adjustment)
      Hint::lock(bottom_edge)
    }
    if Hint::is_valid(top_edge) {
      top_edge.ds_coord = top_edge.ds_coord.add(adjustment)
      Hint::lock(top_edge)
    }
  }
  captured
}

///|
priv struct HintMap {
  edges : Array[Hint]
  mut len : Int
  mut is_valid : Bool
  scale : CffFixed
}

///|
fn HintMap::new(scale : CffFixed) -> HintMap {
  let edges : Array[Hint] = Array::new()
  for _ in 0..<CFF_HINT_MAX_HINTS {
    edges.push(Hint::default())
  }
  HintMap::{ edges, len: 0, is_valid: false, scale }
}

///|
fn HintMap::clear(self : HintMap) -> Unit {
  self.len = 0
  self.is_valid = false
}

///|
fn HintMap::transform(self : HintMap, coord : CffFixed) -> CffFixed {
  if self.len == 0 {
    return coord.mul(self.scale)
  }
  let limit = self.len - 1
  let mut i = 0
  while i < limit && coord.bits >= self.edges.at(i + 1).cs_coord.bits {
    i = i + 1
  }
  while i > 0 && coord.bits < self.edges.at(i).cs_coord.bits {
    i = i - 1
  }
  let first_edge = self.edges.at(0)
  if i == 0 && coord.bits < first_edge.cs_coord.bits {
    coord.sub(first_edge.cs_coord).mul(self.scale).add(first_edge.ds_coord)
  } else {
    let edge = self.edges.at(i)
    coord.sub(edge.cs_coord).mul(edge.scale).add(edge.ds_coord)
  }
}

///|
fn HintMap::insert(
  self : HintMap,
  bottom : Hint,
  top : Hint,
  initial : HintMap?,
) -> Unit {
  let mut is_pair = false
  let mut first_edge = Hint::default()
  if !Hint::is_valid(bottom) {
    is_pair = false
    first_edge = top
  } else if !Hint::is_valid(top) {
    is_pair = false
    first_edge = bottom
  } else {
    is_pair = true
    first_edge = bottom
  }
  let second_edge = top
  if is_pair && top.cs_coord.bits < bottom.cs_coord.bits {
    return
  }
  let edge_count = if is_pair { 2 } else { 1 }
  if self.len + edge_count > CFF_HINT_MAX_HINTS {
    return
  }
  let mut insert_ix = 0
  while insert_ix < self.len {
    if self.edges.at(insert_ix).cs_coord.bits >= first_edge.cs_coord.bits {
      break
    }
    insert_ix = insert_ix + 1
  }
  if insert_ix < self.len {
    let current = self.edges.at(insert_ix)
    if current.cs_coord.bits == first_edge.cs_coord.bits ||
      (is_pair && current.cs_coord.bits <= second_edge.cs_coord.bits) ||
      Hint::is_pair_top(current) {
      return
    }
  }
  if !Hint::is_locked(first_edge) && initial is Some(init) {
    if is_pair {
      let mid = HintMap::transform(
        init,
        cff_hint_midpoint(first_edge.cs_coord, second_edge.cs_coord),
      )
      let half_width = cff_hint_half(
        second_edge.cs_coord.sub(first_edge.cs_coord),
      ).mul(self.scale)
      first_edge.ds_coord = mid.sub(half_width)
      second_edge.ds_coord = mid.add(half_width)
    } else {
      first_edge.ds_coord = HintMap::transform(init, first_edge.cs_coord)
    }
  }
  if insert_ix > 0 &&
    first_edge.ds_coord.bits < self.edges.at(insert_ix - 1).ds_coord.bits {
    return
  }
  if insert_ix < self.len &&
    (
      (
        is_pair &&
        second_edge.ds_coord.bits > self.edges.at(insert_ix).ds_coord.bits
      ) ||
      first_edge.ds_coord.bits > self.edges.at(insert_ix).ds_coord.bits
    ) {
    return
  }
  if insert_ix != self.len {
    let mut src = self.len - 1
    let mut dst = self.len + edge_count - 1
    while src > insert_ix {
      self.edges.set(dst, self.edges.at(src))
      src = src - 1
      dst = dst - 1
    }
    self.edges.set(dst, self.edges.at(src))
  }
  self.edges.set(insert_ix, first_edge)
  if is_pair {
    self.edges.set(insert_ix + 1, second_edge)
  }
  self.len = self.len + edge_count
}

///|
fn HintMap::adjust(self : HintMap) -> Unit {
  let saved : Array[(Int, CffFixed)] = Array::new()
  for _ in 0..<CFF_HINT_MAX_HINTS {
    saved.push((0, CffFixed::zero()))
  }
  let mut saved_count = 0
  let mut i = 0
  let limit = self.len
  while i < limit {
    let is_pair = Hint::is_pair(self.edges.at(i))
    let j = if is_pair { i + 1 } else { i }
    if !Hint::is_locked(self.edges.at(i)) {
      let frac_down = self.edges.at(i).ds_coord.fract()
      let frac_up = self.edges.at(j).ds_coord.fract()
      let down_move_down = CffFixed::zero().sub(frac_down)
      let up_move_down = CffFixed::zero().sub(frac_up)
      let down_move_up = if frac_down.bits == 0 {
        CffFixed::zero()
      } else {
        CffFixed::one().sub(frac_down)
      }
      let up_move_up = if frac_up.bits == 0 {
        CffFixed::zero()
      } else {
        CffFixed::one().sub(frac_up)
      }
      let move_up = down_move_up.min_with(up_move_up)
      let move_down = down_move_down.max_with(up_move_down)
      let mut save_edge = false
      let adjustment = if j >= self.len - 1 ||
        self.edges.at(j + 1).ds_coord.bits >=
        self.edges.at(j).ds_coord
        .add(move_up)
        .add(CffFixed::from_bits(CFF_HINT_MIN_COUNTER_BITS)).bits {
        if i == 0 ||
          self.edges.at(i - 1).ds_coord.bits <=
          self.edges.at(i).ds_coord
          .add(move_down)
          .sub(CffFixed::from_bits(CFF_HINT_MIN_COUNTER_BITS)).bits {
          if move_down.neg().bits < move_up.bits {
            move_down
          } else {
            move_up
          }
        } else {
          move_up
        }
      } else if i == 0 ||
        self.edges.at(i - 1).ds_coord.bits <=
        self.edges.at(i).ds_coord
        .add(move_down)
        .sub(CffFixed::from_bits(CFF_HINT_MIN_COUNTER_BITS)).bits {
        save_edge = move_up.bits < move_down.neg().bits
        move_down
      } else {
        save_edge = true
        CffFixed::zero()
      }
      if save_edge && j < self.len - 1 && !Hint::is_locked(self.edges.at(j + 1)) {
        saved.set(saved_count, (j, move_up.sub(adjustment)))
        saved_count = saved_count + 1
      }
      self.edges.at(i).ds_coord = self.edges.at(i).ds_coord.add(adjustment)
      if is_pair {
        self.edges.at(j).ds_coord = self.edges.at(j).ds_coord.add(adjustment)
      }
    }
    if i > 0 &&
      self.edges.at(i).cs_coord.bits != self.edges.at(i - 1).cs_coord.bits {
      let a = self.edges.at(i)
      let b = self.edges.at(i - 1)
      self.edges.at(i - 1).scale = a.ds_coord
        .sub(b.ds_coord)
        .div(a.cs_coord.sub(b.cs_coord))
    }
    if is_pair {
      if self.edges.at(j).cs_coord.bits != self.edges.at(j - 1).cs_coord.bits {
        let a = self.edges.at(j)
        let b = self.edges.at(j - 1)
        self.edges.at(j - 1).scale = a.ds_coord
          .sub(b.ds_coord)
          .div(a.cs_coord.sub(b.cs_coord))
      }
      i = i + 1
    }
    i = i + 1
  }
  let mut k = saved_count - 1
  while k >= 0 {
    let (j, adjustment) = saved.at(k)
    if self.edges.at(j + 1).ds_coord.bits >=
      self.edges.at(j).ds_coord
      .add(adjustment)
      .add(CffFixed::from_bits(CFF_HINT_MIN_COUNTER_BITS)).bits {
      self.edges.at(j).ds_coord = self.edges.at(j).ds_coord.add(adjustment)
      if Hint::is_pair(self.edges.at(j)) {
        self.edges.at(j - 1).ds_coord = self.edges.at(j - 1).ds_coord.add(
          adjustment,
        )
      }
    }
    if k == 0 {
      break
    }
    k = k - 1
  }
}

///|
priv struct HintMask {
  mask : Array[Byte]
  mut is_valid : Bool
}

///|
fn HintMask::default() -> HintMask {
  let mask : Array[Byte] = Array::new()
  for _ in 0..<CFF_HINT_MASK_SIZE {
    mask.push((0).to_byte())
  }
  HintMask::{ mask, is_valid: false }
}

///|
fn HintMask::all() -> HintMask {
  let mask : Array[Byte] = Array::new()
  for _ in 0..<CFF_HINT_MASK_SIZE {
    mask.push((0xFF).to_byte())
  }
  HintMask::{ mask, is_valid: true }
}

///|
fn cff_hint_msb_mask(bit : Int) -> Int {
  1 << (7 - (bit & 0x7))
}

///|
fn HintMask::new(bytes : ArrayView[Byte]) -> HintMask? {
  let len = bytes.length()
  if len > CFF_HINT_MASK_SIZE {
    return None
  }
  let m = HintMask::default()
  for i in 0..<len {
    m.mask.set(i, bytes.at(i))
  }
  m.is_valid = true
  Some(m)
}

///|
fn HintMask::copy(self : HintMask) -> HintMask {
  let m = HintMask::default()
  for i in 0..<CFF_HINT_MASK_SIZE {
    m.mask.set(i, self.mask.at(i))
  }
  m.is_valid = self.is_valid
  m
}

///|
fn HintMask::clear(self : HintMask, bit : Int) -> Unit {
  let ix = bit >> 3
  let m = cff_hint_msb_mask(bit)
  self.mask.set(ix, (self.mask.at(ix).to_int() & (m |> Int::lnot)).to_byte())
}

///|
fn HintMask::get(self : HintMask, bit : Int) -> Bool {
  let ix = bit >> 3
  let m = cff_hint_msb_mask(bit)
  (self.mask.at(ix).to_int() & m) != 0
}

///|
fn HintMap::build(
  self : HintMap,
  state : HintState,
  mask0 : HintMask?,
  initial_map_opt : HintMap?,
  stems : Array[StemHint],
  stem_count : Int,
  origin : CffFixed,
  is_initial : Bool,
) -> Unit {
  let scale = state.scale
  let darken_y = CffFixed::zero()
  if !is_initial && initial_map_opt is Some(initial_map) {
    if !initial_map.is_valid {
      HintMap::build(
        initial_map,
        state,
        Some(HintMask::all()),
        None,
        stems,
        stem_count,
        origin,
        true,
      )
    }
  }
  let initial_map = initial_map_opt
  HintMap::clear(self)
  let mut mask = match mask0 {
    None => HintMask::all()
    Some(m) => m
  }
  if !mask.is_valid {
    mask = HintMask::all()
  }
  if state.do_em_box_hints {
    let bottom = Hint::default()
    bottom.cs_coord = CffFixed::from_bits(CFF_HINT_ICF_BOTTOM_BITS).sub(
      CffFixed::from_bits(CFF_HINT_EPSILON_BITS),
    )
    bottom.ds_coord = bottom.cs_coord
      .mul(scale)
      .round()
      .sub(CffFixed::from_bits(CFF_HINT_MIN_COUNTER_BITS))
    bottom.scale = scale
    bottom.flags = CFF_HINT_GHOST_BOTTOM | CFF_HINT_LOCKED | CFF_HINT_SYNTHETIC
    let top = Hint::default()
    top.cs_coord = CffFixed::from_bits(CFF_HINT_ICF_TOP_BITS)
      .add(CffFixed::from_bits(CFF_HINT_EPSILON_BITS))
      .add(cff_hint_twice(state.darken_y))
    top.ds_coord = top.cs_coord
      .mul(scale)
      .round()
      .add(CffFixed::from_bits(CFF_HINT_MIN_COUNTER_BITS))
    top.scale = scale
    top.flags = CFF_HINT_GHOST_TOP | CFF_HINT_LOCKED | CFF_HINT_SYNTHETIC
    let invalid = Hint::default()
    HintMap::insert(self, bottom, invalid, initial_map)
    HintMap::insert(self, invalid, top, initial_map)
  }
  // HintMask uses an Array internally; make a deep copy so that clearing bits
  // for the two-pass build doesn't mutate the caller's mask.
  let tmp_mask = HintMask::copy(mask)
  for i in 0..<stem_count {
    if !HintMask::get(tmp_mask, i) {
      continue
    }
    let hint_ix = i
    let bottom = Hint::default()
    let top = Hint::default()
    Hint::setup(bottom, stems.at(i), hint_ix, origin, scale, darken_y, true)
    Hint::setup(top, stems.at(i), hint_ix, origin, scale, darken_y, false)
    if Hint::is_locked(bottom) ||
      Hint::is_locked(top) ||
      HintState::capture(state, bottom, top) {
      if is_initial {
        HintMap::insert(self, bottom, top, None)
      } else {
        HintMap::insert(self, bottom, top, initial_map)
      }
      HintMask::clear(tmp_mask, i)
    }
  }
  if is_initial {
    if self.len == 0 ||
      self.edges.at(0).cs_coord.bits > 0 ||
      self.edges.at(self.len - 1).cs_coord.bits < 0 {
      let edge = Hint::default()
      edge.flags = CFF_HINT_GHOST_BOTTOM | CFF_HINT_LOCKED | CFF_HINT_SYNTHETIC
      edge.scale = scale
      let invalid = Hint::default()
      HintMap::insert(self, edge, invalid, None)
    }
  } else {
    for i in 0..<stem_count {
      if !HintMask::get(tmp_mask, i) {
        continue
      }
      let hint_ix = i
      let bottom = Hint::default()
      let top = Hint::default()
      Hint::setup(bottom, stems.at(i), hint_ix, origin, scale, darken_y, true)
      Hint::setup(top, stems.at(i), hint_ix, origin, scale, darken_y, false)
      HintMap::insert(self, bottom, top, initial_map)
    }
  }
  HintMap::adjust(self)
  if !is_initial {
    for e in 0..<self.len {
      let edge = self.edges.at(e)
      if Hint::is_synthetic(edge) {
        continue
      }
      let stem = stems.at(edge.index)
      if Hint::is_top(edge) {
        stem.ds_max = edge.ds_coord
      } else {
        stem.ds_min = edge.ds_coord
      }
      stem.is_used = true
    }
  }
  self.is_valid = true
}

///|
fn cff_hint_fixed_to_double(v : CffFixed) -> Double {
  v.bits.to_double() / 65536.0
}

///|
fn HintMask::equals(self : HintMask, other : HintMask) -> Bool {
  if self.is_valid != other.is_valid {
    return false
  }
  for i in 0..<CFF_HINT_MASK_SIZE {
    if self.mask.at(i) != other.mask.at(i) {
      return false
    }
  }
  true
}

///|
priv struct CffHintingSink {
  state : HintState
  out : Array[PathElement]
  stem_hints : Array[StemHint]
  mut stem_count : Int
  mut mask : HintMask
  initial_map : HintMap
  map : HintMap
  mut start_point : (CffFixed, CffFixed)?
  mut pending_line : (CffFixed, CffFixed, CffFixed, CffFixed)?
}

///|
fn CffHintingSink::new(
  state : HintState,
  out : Array[PathElement],
) -> CffHintingSink {
  let stem_hints : Array[StemHint] = Array::new()
  for _ in 0..<CFF_HINT_MAX_HINTS {
    stem_hints.push(StemHint::default())
  }
  CffHintingSink::{
    state,
    out,
    stem_hints,
    stem_count: 0,
    mask: HintMask::all(),
    initial_map: HintMap::new(state.scale),
    map: HintMap::new(state.scale),
    start_point: None,
    pending_line: None,
  }
}

///|
fn CffHintingSink::finish(self : CffHintingSink) -> Unit {
  CffHintingSink::maybe_close_subpath(self)
}

///|
fn CffHintingSink::maybe_close_subpath(self : CffHintingSink) -> Unit {
  match (self.start_point, self.pending_line) {
    (Some((sx, sy)), Some((cs_x, cs_y, ds_x, ds_y))) => {
      if sx.bits != cs_x.bits || sy.bits != cs_y.bits {
        self.out.push(
          LineTo(cff_hint_fixed_to_double(ds_x), cff_hint_fixed_to_double(ds_y)),
        )
      }
      self.out.push(Close)
    }
    (Some(_), None) => self.out.push(Close)
    _ => ()
  }
  self.start_point = None
  self.pending_line = None
}

///|
fn CffHintingSink::flush_pending_line(self : CffHintingSink) -> Unit {
  match self.pending_line {
    None => ()
    Some((_cs_x, _cs_y, ds_x, ds_y)) => {
      self.pending_line = None
      self.out.push(
        LineTo(cff_hint_fixed_to_double(ds_x), cff_hint_fixed_to_double(ds_y)),
      )
    }
  }
}

///|
fn CffHintingSink::build_hint_map(
  self : CffHintingSink,
  mask : HintMask?,
  origin : CffFixed,
) -> Unit {
  HintMap::build(
    self.map,
    self.state,
    mask,
    Some(self.initial_map),
    self.stem_hints,
    self.stem_count,
    origin,
    false,
  )
}

///|
fn CffHintingSink::hint(self : CffHintingSink, coord : CffFixed) -> CffFixed {
  if !self.map.is_valid {
    CffHintingSink::build_hint_map(self, Some(self.mask), CffFixed::zero())
  }
  cff_hint_trunc(HintMap::transform(self.map, coord))
}

///|
fn CffHintingSink::scale(self : CffHintingSink, coord : CffFixed) -> CffFixed {
  cff_hint_trunc(coord.mul(self.state.scale))
}

///|
fn CffHintingSink::add_stem(
  self : CffHintingSink,
  min : CffFixed,
  max : CffFixed,
) -> Unit {
  let index = self.stem_count
  if index >= CFF_HINT_MAX_HINTS || self.map.is_valid {
    return
  }
  let stem = self.stem_hints.at(index)
  stem.min = min
  stem.max = max
  stem.is_used = false
  stem.ds_min = CffFixed::zero()
  stem.ds_max = CffFixed::zero()
  self.stem_count = index + 1
}

///|
fn CffHintingSink::hstem(
  self : CffHintingSink,
  min : CffFixed,
  max : CffFixed,
) -> Unit {
  CffHintingSink::add_stem(self, min, max)
}

///|
fn HintMask::from_bytes_view(bytes : BytesView) -> HintMask? {
  let a : Array[Byte] = Array::new()
  for b in bytes.iter() {
    a.push(b)
  }
  HintMask::new(a.op_as_view())
}

///|
fn CffHintingSink::hint_mask(
  self : CffHintingSink,
  mask_bytes : BytesView,
) -> Unit {
  let mask = match HintMask::from_bytes_view(mask_bytes) {
    None => HintMask::all()
    Some(m) => m
  }
  if !HintMask::equals(mask, self.mask) {
    self.mask = mask
    self.map.is_valid = false
  }
}

///|
fn CffHintingSink::counter_mask(
  self : CffHintingSink,
  mask_bytes : BytesView,
) -> Unit {
  let mask = match HintMask::from_bytes_view(mask_bytes) {
    None => HintMask::all()
    Some(m) => m
  }
  let map = HintMap::new(self.state.scale)
  HintMap::build(
    map,
    self.state,
    Some(mask),
    Some(self.initial_map),
    self.stem_hints,
    self.stem_count,
    CffFixed::zero(),
    false,
  )
}

///|
fn CffHintingSink::move_to(
  self : CffHintingSink,
  x : CffFixed,
  y : CffFixed,
) -> Unit {
  CffHintingSink::maybe_close_subpath(self)
  self.start_point = Some((x, y))
  let x1 = CffHintingSink::scale(self, x)
  let y1 = CffHintingSink::hint(self, y)
  self.out.push(
    MoveTo(cff_hint_fixed_to_double(x1), cff_hint_fixed_to_double(y1)),
  )
}

///|
fn CffHintingSink::line_to(
  self : CffHintingSink,
  x : CffFixed,
  y : CffFixed,
) -> Unit {
  CffHintingSink::flush_pending_line(self)
  let ds_x = CffHintingSink::scale(self, x)
  let ds_y = CffHintingSink::hint(self, y)
  self.pending_line = Some((x, y, ds_x, ds_y))
}

///|
fn CffHintingSink::curve_to(
  self : CffHintingSink,
  cx1 : CffFixed,
  cy1 : CffFixed,
  cx2 : CffFixed,
  cy2 : CffFixed,
  x : CffFixed,
  y : CffFixed,
) -> Unit {
  CffHintingSink::flush_pending_line(self)
  let cx1 = CffHintingSink::scale(self, cx1)
  let cy1 = CffHintingSink::hint(self, cy1)
  let cx2 = CffHintingSink::scale(self, cx2)
  let cy2 = CffHintingSink::hint(self, cy2)
  let x = CffHintingSink::scale(self, x)
  let y = CffHintingSink::hint(self, y)
  self.out.push(
    CurveTo(
      cff_hint_fixed_to_double(cx1),
      cff_hint_fixed_to_double(cy1),
      cff_hint_fixed_to_double(cx2),
      cff_hint_fixed_to_double(cy2),
      cff_hint_fixed_to_double(x),
      cff_hint_fixed_to_double(y),
    ),
  )
}

///|
fn CffHintingSink::close(_self : CffHintingSink) -> Unit {
  // Close emitted based on moves; see maybe_close_subpath.
}
