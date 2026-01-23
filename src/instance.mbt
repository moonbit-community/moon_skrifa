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
/// Instance-related types.
///
/// Ported from `fontations/skrifa` (Apache-2.0 OR MIT).
pub type NormalizedCoord = Int

///|
pub struct Size {
  ppem : Double?
}

///|
pub fn Size::new(size : Double) -> Size {
  Size::{ ppem: Some(size) }
}

///|
pub fn Size::unscaled() -> Size {
  Size::{ ppem: None }
}

///|
pub fn Size::ppem(self : Size) -> Double? {
  self.ppem
}

///|
/// Computes a linear scale factor for this font size and the given units-per-em.
///
/// Returns 1.0 for an unscaled size or when `units_per_em` is 0.
pub fn Size::linear_scale(self : Size, units_per_em : UInt16) -> Double {
  match self.ppem {
    Some(ppem) => {
      let upem = units_per_em.to_int()
      if upem != 0 {
        ppem / upem.to_double()
      } else {
        1.0
      }
    }
    None => 1.0
  }
}

///|
/// Legacy helper for the earlier skeleton API.
pub fn Size::value(self : Size) -> Double {
  match self.ppem {
    Some(ppem) => ppem
    None => 0.0
  }
}

///|
/// Maximum number of coords to store inline in a `Location` object.
const MAX_INLINE_COORDS : Int = 8

///|
/// Reference to an ordered sequence of normalized variation coordinates.
///
/// This is a minimal port of `LocationRef` from upstream.
pub struct LocationRef {
  coords : ArrayView[NormalizedCoord]
}

///|
pub fn LocationRef::new(coords : ArrayView[NormalizedCoord]) -> LocationRef {
  LocationRef::{ coords, }
}

///|
pub fn LocationRef::coords(self : LocationRef) -> ArrayView[NormalizedCoord] {
  self.coords
}

///|
pub fn LocationRef::is_default(self : LocationRef) -> Bool {
  self.coords.is_empty() || self.coords.all(fn(coord) { coord == 0 })
}

///|
/// Returns the underlying coordinate array if any entries are non-zero.
///
/// Otherwise returns an empty view (to bypass downstream variation logic).
pub fn LocationRef::effective_coords(
  self : LocationRef,
) -> ArrayView[NormalizedCoord] {
  if self.is_default() {
    let empty : Array[NormalizedCoord] = Array::new()
    empty.op_as_view()
  } else {
    self.coords
  }
}

///|
/// Owned ordered sequence of normalized variation coordinates.
pub struct Location {
  coords : SmallVec[NormalizedCoord]
}

///|
pub fn Location::new(len : Int) -> Location {
  Location::{ coords: SmallVec::with_len(len, 0, MAX_INLINE_COORDS) }
}

///|
pub fn Location::coords(self : Location) -> ArrayView[NormalizedCoord] {
  self.coords.as_view()
}

///|
pub fn Location::as_ref(self : Location) -> LocationRef {
  LocationRef::new(self.coords.as_view())
}
