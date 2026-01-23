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
/// Bitmap strikes (sbix/CBDT/EBDT).
///
/// This is an incremental port of `fontations/skrifa/src/bitmap.rs`.
/// For now it supports format detection and strike enumeration (ppem only).
const TAG_SBIX : UInt = 0x73626978 // "sbix"

///|
const TAG_CBLC : UInt = 0x43424C43 // "CBLC"

///|
const TAG_CBDT : UInt = 0x43424454 // "CBDT"

///|
const TAG_EBLC : UInt = 0x45424C43 // "EBLC"

///|
const TAG_EBDT : UInt = 0x45424454 // "EBDT"

///|
fn bitmap_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn bitmap_read_u32_be(view : BytesView, offset : Int) -> UInt? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_uint()
    let b1 = view.at(offset + 1).to_uint()
    let b2 = view.at(offset + 2).to_uint()
    let b3 = view.at(offset + 3).to_uint()
    Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
}

///|
fn bitmap_read_u32_be_int(view : BytesView, offset : Int) -> Int? {
  match bitmap_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.to_uint64().to_int())
  }
}

///|
pub(all) enum BitmapFormat {
  Sbix
  Cbdt
  Ebdt
}

///|
pub struct BitmapStrike {
  priv format : BitmapFormat
  priv ppem_x : Int
  priv ppem_y : Int
}

///|
pub fn BitmapStrike::format(self : BitmapStrike) -> BitmapFormat {
  self.format
}

///|
pub fn BitmapStrike::ppem_x(self : BitmapStrike) -> Int {
  self.ppem_x
}

///|
pub fn BitmapStrike::ppem_y(self : BitmapStrike) -> Int {
  self.ppem_y
}

///|
priv enum BitmapStrikesKind {
  NoStrikes
  Sbix(BytesView)
  Cbdt(BytesView)
  Ebdt(BytesView)
}

///|
pub struct BitmapStrikes {
  priv kind : BitmapStrikesKind
  priv font : FontRef
}

///|
pub fn BitmapStrikes::new(font : FontRef) -> BitmapStrikes {
  match BitmapStrikes::with_format(font, BitmapFormat::Sbix) {
    None =>
      match BitmapStrikes::with_format(font, BitmapFormat::Cbdt) {
        None =>
          match BitmapStrikes::with_format(font, BitmapFormat::Ebdt) {
            None => BitmapStrikes::{ kind: NoStrikes, font }
            Some(v) => v
          }
        Some(v) => v
      }
    Some(v) => v
  }
}

///|
pub fn BitmapStrikes::with_format(
  font : FontRef,
  format : BitmapFormat,
) -> BitmapStrikes? {
  match format {
    BitmapFormat::Sbix =>
      match font.table(TAG_SBIX) {
        None => None
        Some(sbix) => Some(BitmapStrikes::{ kind: Sbix(sbix), font })
      }
    BitmapFormat::Cbdt =>
      match (font.table(TAG_CBLC), font.table(TAG_CBDT)) {
        (Some(cblc), Some(_)) => Some(BitmapStrikes::{ kind: Cbdt(cblc), font })
        _ => None
      }
    BitmapFormat::Ebdt =>
      match (font.table(TAG_EBLC), font.table(TAG_EBDT)) {
        (Some(eblc), Some(_)) => Some(BitmapStrikes::{ kind: Ebdt(eblc), font })
        _ => None
      }
  }
}

///|
pub fn BitmapStrikes::format(self : BitmapStrikes) -> BitmapFormat? {
  match self.kind {
    NoStrikes => None
    Sbix(_) => Some(BitmapFormat::Sbix)
    Cbdt(_) => Some(BitmapFormat::Cbdt)
    Ebdt(_) => Some(BitmapFormat::Ebdt)
  }
}

///|
pub fn BitmapStrikes::len(self : BitmapStrikes) -> Int {
  match self.kind {
    NoStrikes => 0
    Sbix(sbix) => bitmap_read_u32_be_int(sbix, 4).unwrap_or(0)
    Cbdt(loc) | Ebdt(loc) => bitmap_read_u32_be_int(loc, 4).unwrap_or(0)
  }
}

///|
pub fn BitmapStrikes::is_empty(self : BitmapStrikes) -> Bool {
  self.len() == 0
}

///|
pub fn BitmapStrikes::get(self : BitmapStrikes, index : Int) -> BitmapStrike? {
  if index < 0 || index >= self.len() {
    return None
  }
  match self.kind {
    NoStrikes => None
    Sbix(sbix) => {
      // sbix header: version u16, flags u16, numStrikes u32, strikeOffsets[numStrikes] u32
      let strike_off = bitmap_read_u32_be_int(sbix, 8 + index * 4).unwrap_or(-1)
      if strike_off < 0 || strike_off + 4 > sbix.length() {
        return None
      }
      let ppem = bitmap_read_u16_be(sbix, strike_off).unwrap_or(-1)
      if ppem < 0 {
        None
      } else {
        Some(BitmapStrike::{
          format: BitmapFormat::Sbix,
          ppem_x: ppem,
          ppem_y: ppem,
        })
      }
    }
    Cbdt(loc) => bitmap_loc_get_size(loc, index, BitmapFormat::Cbdt)
    Ebdt(loc) => bitmap_loc_get_size(loc, index, BitmapFormat::Ebdt)
  }
}

///|
fn bitmap_loc_get_size(
  loc : BytesView,
  index : Int,
  format : BitmapFormat,
) -> BitmapStrike? {
  // EBLC/CBLC: major u16, minor u16, numSizes u32, BitmapSizeTable[numSizes]
  // BitmapSizeTable has ppemX/ppemY at offsets 44/45.
  let base = 8 + index * 48
  if base < 0 || base + 48 > loc.length() {
    return None
  }
  let ppem_x = loc.at(base + 44).to_int()
  let ppem_y = loc.at(base + 45).to_int()
  Some(BitmapStrike::{ format, ppem_x, ppem_y })
}

///|
pub fn FontRef::bitmap_strikes(self : FontRef) -> BitmapStrikes {
  BitmapStrikes::new(self)
}
