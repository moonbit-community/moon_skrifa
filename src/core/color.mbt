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
const COLOR_CPAL_VERSION_1 : Int = 1

///|
const COLOR_CPAL_PALETTE_USABLE_WITH_LIGHT_BACKGROUND : UInt = 0x00000001

///|
const COLOR_CPAL_PALETTE_USABLE_WITH_DARK_BACKGROUND : UInt = 0x00000002

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
pub struct ColorPaletteType {
  bits : UInt
}

///|
pub fn ColorPaletteType::raw(self : ColorPaletteType) -> UInt {
  self.bits
}

///|
pub fn ColorPaletteType::usable_with_light_background(
  self : ColorPaletteType,
) -> Bool {
  (self.bits & COLOR_CPAL_PALETTE_USABLE_WITH_LIGHT_BACKGROUND) != 0
}

///|
pub fn ColorPaletteType::usable_with_dark_background(
  self : ColorPaletteType,
) -> Bool {
  (self.bits & COLOR_CPAL_PALETTE_USABLE_WITH_DARK_BACKGROUND) != 0
}

///|
pub struct ColorPalettes {
  priv cpal : BytesView?
  priv version : Int
  priv num_entries : Int
  priv num_palettes : Int
  priv num_records : Int
  priv color_records_off : Int
  priv indices_off : Int
  priv palette_types_off : Int?
  priv palette_labels_off : Int?
  priv palette_entry_labels_off : Int?
}

///|
pub struct ColorPalette {
  priv palettes : ColorPalettes
  priv index : Int
}

///|
fn ColorPalettes::empty() -> ColorPalettes {
  {
    cpal: None,
    version: 0,
    num_entries: 0,
    num_palettes: 0,
    num_records: 0,
    color_records_off: 0,
    indices_off: 0,
    palette_types_off: None,
    palette_labels_off: None,
    palette_entry_labels_off: None,
  }
}

///|
pub fn ColorPalettes::ColorPalettes(font : FontRef) -> ColorPalettes {
  match font.table(COLOR_TAG_CPAL) {
    None => ColorPalettes::empty()
    Some(cpal) => {
      if cpal.length() < 12 {
        return ColorPalettes::empty()
      }
      let version = color_read_u16_be(cpal, 0).unwrap_or(-1)
      if version < 0 || version > COLOR_CPAL_VERSION_1 {
        return ColorPalettes::empty()
      }
      let num_entries = color_read_u16_be(cpal, 2).unwrap_or(-1)
      let num_palettes = color_read_u16_be(cpal, 4).unwrap_or(-1)
      let num_records = color_read_u16_be(cpal, 6).unwrap_or(-1)
      let records_off = color_read_u32_be_int(cpal, 8).unwrap_or(-1)
      if num_entries < 0 ||
        num_palettes < 0 ||
        num_records < 0 ||
        records_off < 0 {
        return ColorPalettes::empty()
      }
      let indices_off = if version >= COLOR_CPAL_VERSION_1 { 24 } else { 12 }
      if indices_off > cpal.length() {
        return ColorPalettes::empty()
      }
      let indices_end = indices_off + num_palettes * 2
      let records_end = records_off + num_records * 4
      if indices_end < indices_off || indices_end > cpal.length() {
        return ColorPalettes::empty()
      }
      if records_end < records_off || records_end > cpal.length() {
        return ColorPalettes::empty()
      }
      let mut palette_types_off : Int? = None
      let mut palette_labels_off : Int? = None
      let mut palette_entry_labels_off : Int? = None
      if version >= COLOR_CPAL_VERSION_1 {
        if cpal.length() < 24 {
          return ColorPalettes::empty()
        }
        let types_off = color_read_u32_be_int(cpal, 12).unwrap_or(0)
        let labels_off = color_read_u32_be_int(cpal, 16).unwrap_or(0)
        let entry_labels_off = color_read_u32_be_int(cpal, 20).unwrap_or(0)
        if types_off > 0 {
          let end = types_off + num_palettes * 4
          if end >= types_off && end <= cpal.length() {
            palette_types_off = Some(types_off)
          }
        }
        if labels_off > 0 {
          let end = labels_off + num_palettes * 2
          if end >= labels_off && end <= cpal.length() {
            palette_labels_off = Some(labels_off)
          }
        }
        if entry_labels_off > 0 {
          let end = entry_labels_off + num_entries * 2
          if end >= entry_labels_off && end <= cpal.length() {
            palette_entry_labels_off = Some(entry_labels_off)
          }
        }
      }
      {
        cpal: Some(cpal),
        version,
        num_entries,
        num_palettes,
        num_records,
        color_records_off: records_off,
        indices_off,
        palette_types_off,
        palette_labels_off,
        palette_entry_labels_off,
      }
    }
  }
}

///|
pub fn ColorPalettes::len(self : ColorPalettes) -> Int {
  self.num_palettes
}

///|
pub fn ColorPalettes::version(self : ColorPalettes) -> Int {
  self.version
}

///|
pub fn ColorPalettes::is_empty(self : ColorPalettes) -> Bool {
  self.num_palettes == 0
}

///|
pub fn ColorPalettes::entries_per_palette(self : ColorPalettes) -> Int {
  self.num_entries
}

///|
fn ColorPalettes::palette_start_index(
  self : ColorPalettes,
  palette : Int,
) -> Int? {
  let cpal = match self.cpal {
    None => return None
    Some(v) => v
  }
  if palette < 0 || palette >= self.num_palettes {
    return None
  }
  color_read_u16_be(cpal, self.indices_off + palette * 2)
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
  if entry < 0 || entry >= self.num_entries {
    return None
  }
  let start_index = match self.palette_start_index(palette) {
    None => return None
    Some(v) => v
  }
  if start_index < 0 {
    return None
  }
  let rec = start_index + entry
  if rec < 0 || rec >= self.num_records {
    return None
  }
  let pos = self.color_records_off + rec * 4
  let b = cpal.at(pos)
  let g = cpal.at(pos + 1)
  let r = cpal.at(pos + 2)
  let a = cpal.at(pos + 3)
  Some({ r, g, b, a, })
}

///|
pub fn ColorPalettes::get(self : ColorPalettes, index : Int) -> ColorPalette? {
  let start_index = match self.palette_start_index(index) {
    None => return None
    Some(v) => v
  }
  if start_index < 0 || start_index + self.num_entries > self.num_records {
    return None
  }
  Some({ palettes: self, index, })
}

///|
pub fn ColorPalettes::color_label(
  self : ColorPalettes,
  color_index : Int,
) -> StringId? {
  let cpal = match self.cpal {
    None => return None
    Some(v) => v
  }
  let off = match self.palette_entry_labels_off {
    None => return None
    Some(v) => v
  }
  if color_index < 0 || color_index >= self.num_entries {
    return None
  }
  let name_id = color_read_u16_be(cpal, off + color_index * 2).unwrap_or(-1)
  if name_id < 0 || name_id == 0xFFFF {
    None
  } else {
    Some(name_id.to_uint16())
  }
}

///|
pub fn ColorPalette::index(self : ColorPalette) -> Int {
  self.index
}

///|
pub fn ColorPalette::colors(self : ColorPalette) -> Array[Color] {
  let count = self.palettes.entries_per_palette()
  let out : Array[Color] = Array(capacity=count)
  for i in 0..<count {
    if self.color(i) is Some(c) {
      out.push(c)
    } else {
      break
    }
  }
  out
}

///|
pub fn ColorPalette::color(self : ColorPalette, entry : Int) -> Color? {
  self.palettes.color(self.index, entry)
}

///|
pub fn ColorPalette::palette_type(self : ColorPalette) -> ColorPaletteType? {
  let cpal = match self.palettes.cpal {
    None => return None
    Some(v) => v
  }
  let off = match self.palettes.palette_types_off {
    None => return None
    Some(v) => v
  }
  let raw = color_read_u32_be(cpal, off + self.index * 4).unwrap_or(0)
  Some({ bits: raw, })
}

///|
pub fn ColorPalette::label(self : ColorPalette) -> StringId? {
  let cpal = match self.palettes.cpal {
    None => return None
    Some(v) => v
  }
  let off = match self.palettes.palette_labels_off {
    None => return None
    Some(v) => v
  }
  let name_id = color_read_u16_be(cpal, off + self.index * 2).unwrap_or(-1)
  if name_id < 0 || name_id == 0xFFFF {
    None
  } else {
    Some(name_id.to_uint16())
  }
}

///|
pub fn FontRef::color_palettes(self : FontRef) -> ColorPalettes {
  ColorPalettes(self)
}
