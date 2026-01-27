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
/// Basic representation of an in-memory font resource.
///
/// Ported from `fontations/skrifa/src/font.rs` (Apache-2.0 OR MIT).
pub struct GlyphId {
  priv value : UInt16
}

///|
pub fn GlyphId::new(value : UInt16) -> GlyphId {
  GlyphId::{ value, }
}

///|
pub fn GlyphId::default() -> GlyphId {
  GlyphId::new(0)
}

///|
pub fn GlyphId::notdef() -> GlyphId {
  GlyphId::default()
}

///|
pub fn GlyphId::to_u16(self : GlyphId) -> UInt16 {
  self.value
}

///|
pub fn GlyphId::to_int(self : GlyphId) -> Int {
  self.value.to_int()
}

///|
pub fn GlyphId::to_uint64(self : GlyphId) -> UInt64 {
  self.value.to_uint64()
}

///|
pub fn GlyphId::to_string(self : GlyphId) -> String {
  self.value.to_string()
}

///|
pub impl Show for GlyphId with output(self, logger) {
  logger.write_string(self.value.to_string())
}

///|
pub impl Eq for GlyphId with equal(self, other) {
  self.value == other.value
}

///|
pub impl Compare for GlyphId with compare(self, other) {
  self.value.to_int() - other.value.to_int()
}

///|
const TAG_TTCF : UInt = 0x74746366

///|
const SFNT_1_0 : UInt = 0x00010000

///|
const SFNT_OTTO : UInt = 0x4F54544F

///|
const SFNT_TRUE : UInt = 0x74727565

///|
const SFNT_TYP1 : UInt = 0x74797031

///|
fn read_u16_be(data : Bytes, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > data.length() {
    None
  } else {
    let b0 = data.at(offset).to_int()
    let b1 = data.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn read_u32_be(data : Bytes, offset : Int) -> UInt? {
  if offset < 0 || offset + 4 > data.length() {
    None
  } else {
    let b0 = data.at(offset).to_uint()
    let b1 = data.at(offset + 1).to_uint()
    let b2 = data.at(offset + 2).to_uint()
    let b3 = data.at(offset + 3).to_uint()
    Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
}

///|
fn read_u32_be_int(data : Bytes, offset : Int) -> Int? {
  match read_u32_be(data, offset) {
    None => None
    Some(u) => Some(u.to_uint64().to_int())
  }
}

///|
fn is_supported_sfnt_version(sfnt_version : UInt) -> Bool {
  sfnt_version == SFNT_1_0 ||
  sfnt_version == SFNT_OTTO ||
  sfnt_version == SFNT_TRUE ||
  sfnt_version == SFNT_TYP1
}

///|
fn validate_sfnt(data : Bytes, base : Int) -> Bool {
  match read_u32_be(data, base) {
    None => false
    Some(sfnt_version) => {
      if !is_supported_sfnt_version(sfnt_version) {
        return false
      }
      match read_u16_be(data, base + 4) {
        None => false
        Some(num_tables) =>
          // offset table (12 bytes) + table records (16 bytes each)
          if num_tables < 0 {
            false
          } else {
            let dir_end = base + 12 + num_tables * 16
            dir_end <= data.length()
          }
      }
    }
  }
}

///|
pub struct FontRef {
  data : Bytes
  index : UInt
}

///|
pub fn FontRef::new(data : Bytes) -> FontRef? {
  match read_u32_be(data, 0) {
    None => None
    Some(TAG_TTCF) => FontRef::from_index(data, 0)
    Some(_) => FontRef::from_index(data, 0)
  }
}

///|
pub fn FontRef::from_index(data : Bytes, index : UInt) -> FontRef? {
  match read_u32_be(data, 0) {
    None => None
    Some(TAG_TTCF) => {
      let idx = index.to_uint64().to_int()
      match read_u32_be_int(data, 8) {
        None => None
        Some(num_fonts) => {
          if idx < 0 || idx >= num_fonts {
            return None
          }
          let offsets_base = 12
          let off_pos = offsets_base + idx * 4
          match read_u32_be_int(data, off_pos) {
            None => None
            Some(sfnt_off) =>
              if sfnt_off < 0 || sfnt_off >= data.length() {
                None
              } else if validate_sfnt(data, sfnt_off) {
                Some(FontRef::{ data, index })
              } else {
                None
              }
          }
        }
      }
    }
    Some(_) =>
      if index != 0 {
        None
      } else if validate_sfnt(data, 0) {
        Some(FontRef::{ data, index: 0 })
      } else {
        None
      }
  }
}

///|
pub fn FontRef::data(self : FontRef) -> Bytes {
  self.data
}

///|
pub fn FontRef::index(self : FontRef) -> UInt {
  self.index
}

///|
fn FontRef::sfnt_offset(self : FontRef) -> Int? {
  match read_u32_be(self.data, 0) {
    None => None
    Some(TAG_TTCF) => {
      let idx = self.index.to_uint64().to_int()
      match read_u32_be_int(self.data, 8) {
        None => None
        Some(num_fonts) =>
          if idx < 0 || idx >= num_fonts {
            None
          } else {
            read_u32_be_int(self.data, 12 + idx * 4)
          }
      }
    }
    Some(_) => Some(0)
  }
}

///|
/// Returns the table data as a `BytesView` (slice into the original font bytes).
///
/// `tag` is a big-endian 4-byte OpenType table tag (e.g. `0x636D6170` for "cmap").
pub fn FontRef::table(self : FontRef, tag : UInt) -> BytesView? {
  match self.sfnt_offset() {
    None => None
    Some(base) => {
      if !validate_sfnt(self.data, base) {
        return None
      }
      match read_u16_be(self.data, base + 4) {
        None => None
        Some(num_tables) => {
          let dir_base = base + 12
          for i in 0..<num_tables {
            let rec = dir_base + i * 16
            match read_u32_be(self.data, rec) {
              None => return None
              Some(rec_tag) =>
                if rec_tag == tag {
                  let off = match read_u32_be_int(self.data, rec + 8) {
                    None => return None
                    Some(v) => v
                  }
                  let len = match read_u32_be_int(self.data, rec + 12) {
                    None => return None
                    Some(v) => v
                  }
                  let start = base + off
                  let end = start + len
                  if off < 0 || len < 0 || start < 0 || end > self.data.length() {
                    return None
                  }
                  return Some(self.data.sub(start~, end~))
                }
            }
          }
          None
        }
      }
    }
  }
}

///|
/// Tag-based table lookup adapter for parity with upstream `TableProvider`.
pub fn FontRef::table_tag(self : FontRef, tag : Tag) -> BytesView? {
  self.table(tag.to_uint())
}
