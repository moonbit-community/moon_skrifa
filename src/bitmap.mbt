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
const BITMAP_TAG_MAXP : UInt = 0x6D617870 // "maxp"

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
fn bitmap_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match bitmap_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
pub(all) enum BitmapFormat {
  Sbix
  Cbdt
  Ebdt
}

///|
pub(all) enum BitmapImageFormat {
  Png
  Jpeg
  Unknown(UInt)
}

///|
pub struct BitmapGlyph {
  priv format : BitmapImageFormat
  priv data : BytesView
  priv ppem_x : Int
  priv ppem_y : Int
  priv origin_x : Int
  priv origin_y : Int
  priv width : Int?
  priv height : Int?
}

///|
pub fn BitmapGlyph::format(self : BitmapGlyph) -> BitmapImageFormat {
  self.format
}

///|
pub fn BitmapGlyph::data(self : BitmapGlyph) -> BytesView {
  self.data
}

///|
pub fn BitmapGlyph::ppem_x(self : BitmapGlyph) -> Int {
  self.ppem_x
}

///|
pub fn BitmapGlyph::ppem_y(self : BitmapGlyph) -> Int {
  self.ppem_y
}

///|
pub fn BitmapGlyph::origin_x(self : BitmapGlyph) -> Int {
  self.origin_x
}

///|
pub fn BitmapGlyph::origin_y(self : BitmapGlyph) -> Int {
  self.origin_y
}

///|
pub fn BitmapGlyph::width(self : BitmapGlyph) -> Int? {
  self.width
}

///|
pub fn BitmapGlyph::height(self : BitmapGlyph) -> Int? {
  self.height
}

///|
pub struct BitmapStrike {
  priv format : BitmapFormat
  priv ppem_x : Int
  priv ppem_y : Int
  priv sbix : BytesView?
  priv sbix_strike_off : Int
  priv num_glyphs : Int
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
/// Returns the bitmap glyph for `gid` if present.
///
/// Currently only supports `sbix` strikes. For other formats this returns `None`.
pub fn BitmapStrike::get(self : BitmapStrike, gid : GlyphId) -> BitmapGlyph? {
  match self.format {
    BitmapFormat::Sbix =>
      match self.sbix {
        None => None
        Some(sbix) =>
          bitmap_sbix_strike_glyph(
            sbix,
            self.sbix_strike_off,
            self.num_glyphs,
            self.ppem_x,
            gid,
          )
      }
    _ => None
  }
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
  priv num_glyphs : Int
}

///|
fn bitmap_num_glyphs(font : FontRef) -> Int {
  match font.table(BITMAP_TAG_MAXP) {
    None => 0
    Some(maxp) => bitmap_read_u16_be(maxp, 4).unwrap_or(0)
  }
}

///|
pub fn BitmapStrikes::new(font : FontRef) -> BitmapStrikes {
  let num_glyphs = bitmap_num_glyphs(font)
  match BitmapStrikes::with_format(font, BitmapFormat::Sbix) {
    None =>
      match BitmapStrikes::with_format(font, BitmapFormat::Cbdt) {
        None =>
          match BitmapStrikes::with_format(font, BitmapFormat::Ebdt) {
            None => BitmapStrikes::{ kind: NoStrikes, font, num_glyphs }
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
  let num_glyphs = bitmap_num_glyphs(font)
  match format {
    BitmapFormat::Sbix =>
      match font.table(TAG_SBIX) {
        None => None
        Some(sbix) =>
          Some(BitmapStrikes::{ kind: Sbix(sbix), font, num_glyphs })
      }
    BitmapFormat::Cbdt =>
      match (font.table(TAG_CBLC), font.table(TAG_CBDT)) {
        (Some(cblc), Some(_)) =>
          Some(BitmapStrikes::{ kind: Cbdt(cblc), font, num_glyphs })
        _ => None
      }
    BitmapFormat::Ebdt =>
      match (font.table(TAG_EBLC), font.table(TAG_EBDT)) {
        (Some(eblc), Some(_)) =>
          Some(BitmapStrikes::{ kind: Ebdt(eblc), font, num_glyphs })
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
          sbix: Some(sbix),
          sbix_strike_off: strike_off,
          num_glyphs: self.num_glyphs,
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
  Some(BitmapStrike::{
    format,
    ppem_x,
    ppem_y,
    sbix: None,
    sbix_strike_off: -1,
    num_glyphs: 0,
  })
}

///|
fn bitmap_sbix_strike_glyph(
  sbix : BytesView,
  strike_off : Int,
  num_glyphs : Int,
  ppem : Int,
  gid : GlyphId,
) -> BitmapGlyph? {
  let idx = gid.to_uint64().to_int()
  if num_glyphs <= 0 || idx < 0 || idx >= num_glyphs {
    return None
  }
  // Strike header: ppem u16, resolution u16, glyphDataOffsets[numGlyphs+1] u32
  let offsets_off = strike_off + 4
  let offsets_len = (num_glyphs + 1) * 4
  let offsets_end = offsets_off + offsets_len
  if offsets_off < 0 || offsets_end < offsets_off || offsets_end > sbix.length() {
    return None
  }
  let off0 = bitmap_read_u32_be_int(sbix, offsets_off + idx * 4).unwrap_or(-1)
  let off1 = bitmap_read_u32_be_int(sbix, offsets_off + (idx + 1) * 4).unwrap_or(
    -1,
  )
  if off0 < 0 || off1 < off0 {
    return None
  }
  if off0 == off1 {
    return None
  }
  let glyph_off = strike_off + off0
  let glyph_end = strike_off + off1
  if glyph_off < 0 || glyph_end < glyph_off || glyph_end > sbix.length() {
    return None
  }
  let origin_x = bitmap_read_i16_be(sbix, glyph_off).unwrap_or(0)
  let origin_y = bitmap_read_i16_be(sbix, glyph_off + 2).unwrap_or(0)
  let graphic_type = bitmap_read_u32_be(sbix, glyph_off + 4).unwrap_or(0)
  let data_off = glyph_off + 8
  if data_off > glyph_end {
    return None
  }
  let start = data_off
  let end = glyph_end
  let data = sbix.sub(start~, end~)
  let format = if graphic_type == 0x706E6720 { // "png "
    BitmapImageFormat::Png
  } else if graphic_type == 0x6A706720 { // "jpg "
    BitmapImageFormat::Jpeg
  } else {
    BitmapImageFormat::Unknown(graphic_type)
  }
  let mut width : Int? = None
  let mut height : Int? = None
  if format is BitmapImageFormat::Png {
    if data.length() >= 24 {
      let w = bitmap_read_u32_be_int(data, 16).unwrap_or(-1)
      let h = bitmap_read_u32_be_int(data, 20).unwrap_or(-1)
      if w >= 0 && h >= 0 {
        width = Some(w)
        height = Some(h)
      }
    }
  }
  Some(BitmapGlyph::{
    format,
    data,
    ppem_x: ppem,
    ppem_y: ppem,
    origin_x,
    origin_y,
    width,
    height,
  })
}

///|
pub fn FontRef::bitmap_strikes(self : FontRef) -> BitmapStrikes {
  BitmapStrikes::new(self)
}
