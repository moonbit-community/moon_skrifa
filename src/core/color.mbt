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
/// Color palettes (OpenType `CPAL` table) MVP.
///
/// Ported from `fontations/skrifa/src/color/*` (Apache-2.0 OR MIT).
const COLOR_TAG_CPAL : UInt = 0x4350414C // "CPAL"

///|
fn color_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn color_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn color_read_u32_be_int(view : BytesView, offset : Int) -> Int? {
  match color_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.to_uint64().to_int())
  }
}

///|
pub struct Color {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
}

///|
pub fn Color::r(self : Color) -> Byte {
  self.r
}

///|
pub fn Color::g(self : Color) -> Byte {
  self.g
}

///|
pub fn Color::b(self : Color) -> Byte {
  self.b
}

///|
pub fn Color::a(self : Color) -> Byte {
  self.a
}

///|
pub struct ColorPalettes {
  priv cpal : BytesView?
  priv num_entries : Int
  priv num_palettes : Int
  priv num_records : Int
  priv color_records_off : Int
  priv indices_off : Int
}

///|
pub fn ColorPalettes::new(font : FontRef) -> ColorPalettes {
  match font.table(COLOR_TAG_CPAL) {
    None =>
      ColorPalettes::{
        cpal: None,
        num_entries: 0,
        num_palettes: 0,
        num_records: 0,
        color_records_off: 0,
        indices_off: 0,
      }
    Some(cpal) => {
      if cpal.length() < 12 {
        return ColorPalettes::{
          cpal: None,
          num_entries: 0,
          num_palettes: 0,
          num_records: 0,
          color_records_off: 0,
          indices_off: 0,
        }
      }
      let num_entries = color_read_u16_be(cpal, 2).unwrap_or(-1)
      let num_palettes = color_read_u16_be(cpal, 4).unwrap_or(-1)
      let num_records = color_read_u16_be(cpal, 6).unwrap_or(-1)
      let records_off = color_read_u32_be_int(cpal, 8).unwrap_or(-1)
      if num_entries < 0 ||
        num_palettes < 0 ||
        num_records < 0 ||
        records_off < 0 {
        return ColorPalettes::{
          cpal: None,
          num_entries: 0,
          num_palettes: 0,
          num_records: 0,
          color_records_off: 0,
          indices_off: 0,
        }
      }
      let indices_off = 12
      let indices_end = indices_off + num_palettes * 2
      let records_end = records_off + num_records * 4
      if indices_end < indices_off || indices_end > cpal.length() {
        return ColorPalettes::{
          cpal: None,
          num_entries: 0,
          num_palettes: 0,
          num_records: 0,
          color_records_off: 0,
          indices_off: 0,
        }
      }
      if records_end < records_off || records_end > cpal.length() {
        return ColorPalettes::{
          cpal: None,
          num_entries: 0,
          num_palettes: 0,
          num_records: 0,
          color_records_off: 0,
          indices_off: 0,
        }
      }
      ColorPalettes::{
        cpal: Some(cpal),
        num_entries,
        num_palettes,
        num_records,
        color_records_off: records_off,
        indices_off,
      }
    }
  }
}

///|
pub fn ColorPalettes::len(self : ColorPalettes) -> Int {
  self.num_palettes
}

///|
pub fn ColorPalettes::entries_per_palette(self : ColorPalettes) -> Int {
  self.num_entries
}

///|
pub fn ColorPalettes::color(
  self : ColorPalettes,
  palette : Int,
  entry : Int,
) -> Color? {
  let cpal = match self.cpal {
    None => return None
    Some(v) => v
  }
  if palette < 0 || palette >= self.num_palettes {
    return None
  }
  if entry < 0 || entry >= self.num_entries {
    return None
  }
  let idx = color_read_u16_be(cpal, self.indices_off + palette * 2).unwrap_or(
    -1,
  )
  if idx < 0 {
    return None
  }
  let rec = idx + entry
  if rec < 0 || rec >= self.num_records {
    return None
  }
  let pos = self.color_records_off + rec * 4
  let b = cpal.at(pos)
  let g = cpal.at(pos + 1)
  let r = cpal.at(pos + 2)
  let a = cpal.at(pos + 3)
  Some(Color::{ r, g, b, a })
}

///|
pub fn FontRef::color_palettes(self : FontRef) -> ColorPalettes {
  ColorPalettes::new(self)
}
