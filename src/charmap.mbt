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
/// Minimal cmap parsing (format 4 / 12).
///
/// Ported from `fontations/skrifa/src/charmap.rs` (Apache-2.0 OR MIT).
const TAG_CMAP : UInt = 0x636D6170 // "cmap"

///|
fn cmap_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn cmap_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match cmap_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
fn cmap_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn cmap_read_u32_be_int(view : BytesView, offset : Int) -> Int? {
  match cmap_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.to_uint64().to_int())
  }
}

///|
fn add_delta_u16(value : Int, delta : Int) -> Int {
  (value + delta) & 0xFFFF
}

///|
pub struct Charmap {
  priv cmap : BytesView
  priv sub_off : Int
  priv format : Int
}

///|
/// Create a charmap from the font's `cmap` table by selecting a subtable.
///
/// Selection strategy (minimal):
/// - Prefer format 12, else format 4, else None.
pub fn Charmap::new(font : FontRef) -> Charmap? {
  match font.table(TAG_CMAP) {
    None => None
    Some(cmap) => {
      let num_tables = match cmap_read_u16_be(cmap, 2) {
        None => return None
        Some(n) => n
      }
      let records_base = 4
      let mut fmt4_off : Int? = None
      for i in 0..<num_tables {
        let rec = records_base + i * 8
        let off = match cmap_read_u32_be_int(cmap, rec + 4) {
          None => return None
          Some(v) => v
        }
        match cmap_read_u16_be(cmap, off) {
          Some(12) => return Some(Charmap::{ cmap, sub_off: off, format: 12 })
          Some(4) => fmt4_off = Some(off)
          _ => ()
        }
      }
      match fmt4_off {
        None => None
        Some(off) => Some(Charmap::{ cmap, sub_off: off, format: 4 })
      }
    }
  }
}

///|
/// Returns the glyph id for a Unicode codepoint.
///
/// Returns `None` when unmapped.
pub fn Charmap::glyph_id(self : Charmap, codepoint : UInt) -> GlyphId? {
  if self.format == 12 {
    self.glyph_id_format12(codepoint)
  } else if self.format == 4 {
    // format 4 only covers BMP.
    if codepoint > (0xFFFF |> Int::reinterpret_as_uint) {
      None
    } else {
      self.glyph_id_format4(codepoint.to_uint64().to_int())
    }
  } else {
    None
  }
}

///|
pub fn FontRef::charmap(self : FontRef) -> Charmap? {
  Charmap::new(self)
}

///|
fn Charmap::glyph_id_format12(self : Charmap, codepoint : UInt) -> GlyphId? {
  let base = self.sub_off
  let length = match cmap_read_u32_be_int(self.cmap, base + 4) {
    None => return None
    Some(v) => v
  }
  if length < 0 || base + length > self.cmap.length() {
    return None
  }
  let n_groups = match cmap_read_u32_be_int(self.cmap, base + 12) {
    None => return None
    Some(v) => v
  }
  let groups_base = base + 16
  let mut lo = 0
  let mut hi = n_groups - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let g = groups_base + mid * 12
    let start = match cmap_read_u32_be(self.cmap, g) {
      None => return None
      Some(v) => v
    }
    let end = match cmap_read_u32_be(self.cmap, g + 4) {
      None => return None
      Some(v) => v
    }
    if codepoint < start {
      hi = mid - 1
    } else if codepoint > end {
      lo = mid + 1
    } else {
      let start_gid = match cmap_read_u32_be(self.cmap, g + 8) {
        None => return None
        Some(v) => v
      }
      let gid = start_gid + (codepoint - start)
      let gidi = gid.to_uint64().to_int()
      if gidi <= 0 || gidi > 0xFFFF {
        return None
      }
      return Some(gidi.to_uint16())
    }
  }
  None
}

///|
fn Charmap::glyph_id_format4(self : Charmap, codepoint : Int) -> GlyphId? {
  let base = self.sub_off
  let length = match cmap_read_u16_be(self.cmap, base + 2) {
    None => return None
    Some(v) => v
  }
  if length < 0 || base + length > self.cmap.length() {
    return None
  }
  let seg_count = match cmap_read_u16_be(self.cmap, base + 6) {
    None => return None
    Some(v) => v / 2
  }
  let end_codes_base = base + 14
  let start_codes_base = end_codes_base + 2 * seg_count + 2
  let id_delta_base = start_codes_base + 2 * seg_count
  let id_range_off_base = id_delta_base + 2 * seg_count
  for i in 0..<seg_count {
    let end_code = match cmap_read_u16_be(self.cmap, end_codes_base + i * 2) {
      None => return None
      Some(v) => v
    }
    if codepoint > end_code {
      continue
    }
    let start_code = match
      cmap_read_u16_be(self.cmap, start_codes_base + i * 2) {
      None => return None
      Some(v) => v
    }
    if codepoint < start_code {
      return None
    }
    let delta = match cmap_read_i16_be(self.cmap, id_delta_base + i * 2) {
      None => return None
      Some(v) => v
    }
    let range_off = match
      cmap_read_u16_be(self.cmap, id_range_off_base + i * 2) {
      None => return None
      Some(v) => v
    }
    if range_off == 0 {
      let gid = add_delta_u16(codepoint, delta)
      if gid == 0 {
        return None
      } else {
        return Some(gid.to_uint16())
      }
    } else {
      let ro_pos = id_range_off_base + i * 2
      let glyph_pos = ro_pos + range_off + 2 * (codepoint - start_code)
      let raw_gid = match cmap_read_u16_be(self.cmap, glyph_pos) {
        None => return None
        Some(v) => v
      }
      if raw_gid == 0 {
        return None
      } else {
        let gid = add_delta_u16(raw_gid, delta)
        if gid == 0 {
          return None
        } else {
          return Some(gid.to_uint16())
        }
      }
    }
  }
  None
}
