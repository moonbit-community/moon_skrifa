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
/// Localized strings (OpenType `name` table).
///
/// Ported from `fontations/skrifa/src/string.rs` (Apache-2.0 OR MIT).
const TAG_NAME : UInt = 0x6E616D65 // "name"

///|
/// OpenType name identifier (NameID).
///
/// This is a `UInt16` in the OpenType spec.
pub type StringId = UInt16

///|
pub const STRING_ID_FAMILY_NAME : StringId = 1

///|
pub const STRING_ID_SUBFAMILY_NAME : StringId = 2

///|
fn string_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn string_decode_utf16be(view : BytesView) -> String? {
  let len = view.length()
  if len < 0 || (len & 1) != 0 {
    return None
  }
  let chars : Array[Char] = Array::new()
  let mut i = 0
  while i + 1 < len {
    let u = string_read_u16_be(view, i).unwrap_or(-1)
    if u < 0 {
      return None
    }
    if u >= 0xD800 && u <= 0xDBFF {
      if i + 3 >= len {
        return None
      }
      let u2 = string_read_u16_be(view, i + 2).unwrap_or(-1)
      if u2 < 0xDC00 || u2 > 0xDFFF {
        return None
      }
      let hi = u - 0xD800
      let lo = u2 - 0xDC00
      let code_point = 0x10000 + (hi << 10) + lo
      if code_point > 0x10FFFF {
        return None
      }
      chars.push(code_point.unsafe_to_char())
      i = i + 4
    } else if u >= 0xDC00 && u <= 0xDFFF {
      return None
    } else {
      chars.push(u.unsafe_to_char())
      i = i + 2
    }
  }
  Some(String::from_array(chars.op_as_view()))
}

///|
fn string_decode_bytes_latin1(view : BytesView) -> String {
  let chars : Array[Char] = Array::new()
  for b in view.iter() {
    chars.push(b.to_int().unsafe_to_char())
  }
  String::from_array(chars.op_as_view())
}

///|
fn string_decode_name_string(
  platform_id : Int,
  _encoding_id : Int,
  view : BytesView,
) -> String? {
  match platform_id {
    // Unicode
    0 => string_decode_utf16be(view)
    // Macintosh (decode as Latin-1 for now; sufficient for ASCII).
    1 => Some(string_decode_bytes_latin1(view))
    // Windows
    3 => string_decode_utf16be(view)
    _ => None
  }
}

///|
fn string_is_ascii(s : String) -> Bool {
  for ch in s {
    if !ch.is_ascii() {
      return false
    }
  }
  true
}

///|
fn string_language_id_to_bcp47(language_id : Int) -> String? {
  // Minimal mapping needed for the reference tests.
  // (Skia/SkOTTable_name.cpp has a much larger mapping.)
  match language_id {
    0x0000 => Some("en")
    0x0401 => Some("ar-SA")
    0x0408 => Some("el-GR")
    0x0409 => Some("en")
    0x0415 => Some("pl-PL")
    0x042D => Some("eu-ES")
    0x0804 => Some("zh-Hans")
    _ => None
  }
}

///|

///|
pub struct LocalizedString {
  priv language : String?
  priv value : String
}

///|
pub fn LocalizedString::language(self : LocalizedString) -> String? {
  self.language
}

///|
pub fn LocalizedString::to_string(self : LocalizedString) -> String {
  self.value
}

///|
pub struct LocalizedStrings {
  priv id : StringId
  priv strings : Array[LocalizedString]
}

///|
pub fn LocalizedStrings::id(self : LocalizedStrings) -> StringId {
  self.id
}

///|
pub fn LocalizedStrings::strings(
  self : LocalizedStrings,
) -> ArrayView[LocalizedString] {
  self.strings.op_as_view()
}

///|
pub fn LocalizedStrings::english_or_first(
  self : LocalizedStrings,
) -> LocalizedString? {
  let mut best_rank = -1
  let mut best : LocalizedString? = None
  let n = self.strings.length()
  for i in 0..<n {
    let s = self.strings.at(i)
    let rank = match s.language {
      Some(lang) =>
        if lang == "en-US" {
          return Some(s)
        } else if lang == "en" {
          2
        } else if i == 0 {
          0
        } else {
          continue
        }
      None => 1
    }
    if rank > best_rank {
      best_rank = rank
      best = Some(s)
    }
  }
  best
}

///|
pub fn FontRef::localized_strings(
  self : FontRef,
  id : StringId,
) -> LocalizedStrings {
  let name = match self.table(TAG_NAME) {
    None => return LocalizedStrings::{ id, strings: Array::new() }
    Some(v) => v
  }
  let format = string_read_u16_be(name, 0).unwrap_or(-1)
  let count = string_read_u16_be(name, 2).unwrap_or(-1)
  let string_offset = string_read_u16_be(name, 4).unwrap_or(-1)
  if format < 0 || count < 0 || string_offset < 0 {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  let records_base = 6
  let records_end = records_base + count * 12
  if records_end < records_base || records_end > name.length() {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  let lang_tags : Array[(Int, Int)] = Array::new()
  if format == 1 {
    if records_end + 2 > name.length() {
      return LocalizedStrings::{ id, strings: Array::new() }
    }
    let tag_count = string_read_u16_be(name, records_end).unwrap_or(-1)
    if tag_count < 0 {
      return LocalizedStrings::{ id, strings: Array::new() }
    }
    let tags_base = records_end + 2
    let tags_end = tags_base + tag_count * 4
    if tags_end < tags_base || tags_end > name.length() {
      return LocalizedStrings::{ id, strings: Array::new() }
    }
    for i in 0..<tag_count {
      let pos = tags_base + i * 4
      let len = string_read_u16_be(name, pos).unwrap_or(-1)
      let off = string_read_u16_be(name, pos + 2).unwrap_or(-1)
      if len < 0 || off < 0 {
        continue
      }
      lang_tags.push((len, off))
    }
  } else if format != 0 {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  if string_offset > name.length() {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  let strings : Array[LocalizedString] = Array::new()
  for i in 0..<count {
    let pos = records_base + i * 12
    let platform_id = string_read_u16_be(name, pos).unwrap_or(-1)
    let encoding_id = string_read_u16_be(name, pos + 2).unwrap_or(-1)
    let language_id = string_read_u16_be(name, pos + 4).unwrap_or(-1)
    let name_id = string_read_u16_be(name, pos + 6).unwrap_or(-1)
    let len = string_read_u16_be(name, pos + 8).unwrap_or(-1)
    let off = string_read_u16_be(name, pos + 10).unwrap_or(-1)
    if platform_id < 0 ||
      encoding_id < 0 ||
      language_id < 0 ||
      name_id < 0 ||
      len < 0 ||
      off < 0 {
      continue
    }
    if name_id != id.to_uint64().to_int() {
      continue
    }
    let start = string_offset + off
    let end = start + len
    if start < 0 || end < start || end > name.length() {
      continue
    }
    let view = name.sub(start~, end~)
    let value = match
      string_decode_name_string(platform_id, encoding_id, view) {
      None => continue
      Some(s) => s
    }
    let language = if format == 1 && language_id >= 0x8000 {
      let index = language_id - 0x8000
      if index < 0 || index >= lang_tags.length() {
        None
      } else {
        let (tlen, toff) = lang_tags.at(index)
        let start = string_offset + toff
        let end = start + tlen
        if start < 0 || end < start || end > name.length() {
          None
        } else {
          match string_decode_utf16be(name.sub(start~, end~)) {
            None => None
            Some(tag) => if string_is_ascii(tag) { Some(tag) } else { None }
          }
        }
      }
    } else {
      match platform_id {
        1 | 3 => string_language_id_to_bcp47(language_id)
        _ => None
      }
    }
    strings.push(LocalizedString::{ language, value })
  }
  LocalizedStrings::{ id, strings }
}
