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
/// Support for accessing glyph names.
///
/// Ported from `fontations/skrifa/src/glyph_name.rs` (Apache-2.0 OR MIT).
const GLYPH_TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
const GLYPH_TAG_POST : UInt = 0x706F7374 // "post"

///|
const GLYPH_TAG_CFF : UInt = 0x43464620 // "CFF "

///|
const MAX_GLYPH_NAME_LEN : Int = 63

///|
pub(all) enum GlyphNameSource {
  Post
  Cff
  Synthesized
}

///|
pub struct GlyphName {
  priv name : String
  priv synthesized : Bool
}

///|
pub fn GlyphName::as_str(self : GlyphName) -> String {
  self.name
}

///|
pub fn GlyphName::is_synthesized(self : GlyphName) -> Bool {
  self.synthesized
}

///|
fn glyph_name_truncate(s : String) -> String {
  // Glyph names are expected to be ASCII; truncate by code units.
  let out : Array[Char] = Array::new(capacity=MAX_GLYPH_NAME_LEN)
  let mut n = 0
  for c in s {
    if n >= MAX_GLYPH_NAME_LEN {
      break
    }
    out.push(c)
    n = n + 1
  }
  String::from_array(out.op_as_view())
}

///|
fn glyph_name_synthesize(gid : GlyphId) -> GlyphName {
  GlyphName::{
    name: glyph_name_truncate("gid" + gid.to_string()),
    synthesized: true,
  }
}

///|
fn glyph_name_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn glyph_name_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn glyph_name_read_maxp_num_glyphs(font : FontRef) -> Int {
  match font.table(GLYPH_TAG_MAXP) {
    None => 0
    Some(maxp) => glyph_name_read_u16_be(maxp, 4).unwrap_or(0)
  }
}

///|
fn glyph_name_post_v2_get(post : BytesView, gid : Int) -> String? {
  // post v2.0: version(4) .. header(32) numberOfGlyphs(u16) glyphNameIndex[u16] stringData[]
  if post.length() < 34 {
    return None
  }
  let version = glyph_name_read_u32_be(post, 0).unwrap_or(0)
  if version != 0x00020000 {
    return None
  }
  let number_of_glyphs = glyph_name_read_u16_be(post, 32).unwrap_or(-1)
  if number_of_glyphs <= 0 || gid < 0 || gid >= number_of_glyphs {
    return None
  }
  let names_base = 34
  let names_end = names_base + number_of_glyphs * 2
  if names_end < names_base || names_end > post.length() {
    return None
  }
  let name_index = glyph_name_read_u16_be(post, names_base + gid * 2).unwrap_or(
    -1,
  )
  if name_index < 0 {
    return None
  }
  // Mac standard name 0 => ".notdef" (good enough for MVP).
  if name_index == 0 {
    return Some(".notdef")
  }
  // Custom strings start at index 258.
  if name_index < 258 {
    return None
  }
  let mut want = name_index - 258
  let mut off = names_end
  while off < post.length() {
    let len = post.at(off).to_int()
    off = off + 1
    if len < 0 || off + len > post.length() {
      return None
    }
    if want == 0 {
      let bytes = post.sub(start=off, end=off + len)
      // ASCII only for MVP.
      let chars : Array[Char] = Array::new()
      for b in bytes.iter() {
        chars.push(b.to_int().unsafe_to_char())
      }
      return Some(glyph_name_truncate(String::from_array(chars.op_as_view())))
    }
    want = want - 1
    off = off + len
  }
  None
}

///|
priv struct CffIndex1 {
  data : BytesView
  count : Int
  off_size : Int
  offsets_base : Int
  objects_base : Int
}

///|
fn cff_index1_read(data : BytesView) -> CffIndex1? {
  let count = glyph_name_read_u16_be(data, 0).unwrap_or(-1)
  if count < 0 {
    return None
  }
  if count == 0 {
    Some(CffIndex1::{
      data,
      count: 0,
      off_size: 0,
      offsets_base: 2,
      objects_base: 2,
    })
  } else {
    if data.length() < 3 {
      return None
    }
    let off_size = data.at(2).to_int()
    if off_size <= 0 || off_size > 4 {
      return None
    }
    let offsets_base = 3
    let objects_base = offsets_base + (count + 1) * off_size
    if objects_base > data.length() {
      return None
    }
    Some(CffIndex1::{ data, count, off_size, offsets_base, objects_base })
  }
}

///|
fn cff_index1_offset(ix : CffIndex1, index : Int) -> Int? {
  if ix.count == 0 {
    if index == 0 {
      Some(0)
    } else {
      None
    }
  } else {
    if index < 0 || index > ix.count {
      return None
    }
    let pos = ix.offsets_base + index * ix.off_size
    if pos < 0 || pos + ix.off_size > ix.data.length() {
      return None
    }
    let mut v = 0
    for i in 0..<ix.off_size {
      v = (v << 8) | ix.data.at(pos + i).to_int()
    }
    Some(v - 1)
  }
}

///|
fn cff_index1_total_size(ix : CffIndex1) -> Int? {
  if ix.count == 0 {
    Some(2)
  } else {
    match cff_index1_offset(ix, ix.count) {
      None => None
      Some(end_off) => Some(ix.objects_base + end_off)
    }
  }
}

///|
fn cff_index1_get(ix : CffIndex1, index : Int) -> BytesView? {
  if index < 0 || index >= ix.count {
    return None
  }
  let start = cff_index1_offset(ix, index).unwrap_or(-1)
  let end = cff_index1_offset(ix, index + 1).unwrap_or(-1)
  let s = ix.objects_base + start
  let e = ix.objects_base + end
  if start < 0 || end < start || s < 0 || e > ix.data.length() {
    None
  } else {
    Some(ix.data.sub(start=s, end=e))
  }
}

///|
priv struct CffDictOffsets {
  mut charset_offset : Int?
  mut charstrings_offset : Int?
}

///|
fn cff_dict_parse_offsets(data : BytesView) -> CffDictOffsets {
  // Minimal DICT parsing: only integer operands and ops 15 (charset), 17 (charstrings).
  let info = CffDictOffsets::{ charset_offset: None, charstrings_offset: None }
  let stack : Array[Int] = Array::new()
  let mut pos = 0
  while pos < data.length() {
    let b0 = data.at(pos).to_int()
    pos = pos + 1
    if b0 == 28 || b0 == 29 || (b0 >= 32 && b0 <= 254) {
      let parsed : (Int, Int)? = match b0 {
        28 =>
          match glyph_name_read_u16_be(data, pos) {
            None => None
            Some(u) =>
              Some((if u >= 0x8000 { u - 0x10000 } else { u }, pos + 2))
          }
        29 =>
          match glyph_name_read_u32_be(data, pos) {
            None => None
            Some(u) => Some((u.reinterpret_as_int(), pos + 4))
          }
        32..=246 => Some((b0 - 139, pos))
        247..=250 =>
          if pos >= data.length() {
            None
          } else {
            let b1 = data.at(pos).to_int()
            Some(((b0 - 247) * 256 + b1 + 108, pos + 1))
          }
        251..=254 =>
          if pos >= data.length() {
            None
          } else {
            let b1 = data.at(pos).to_int()
            Some((-(b0 - 251) * 256 - b1 - 108, pos + 1))
          }
        _ => None
      }
      match parsed {
        None => break
        Some((v, p)) => {
          stack.push(v)
          pos = p
        }
      }
      continue
    }
    let op = if b0 == 12 {
      if pos >= data.length() {
        break
      }
      let b1 = data.at(pos).to_int()
      pos = pos + 1
      1200 + b1
    } else {
      b0
    }
    match op {
      15 =>
        if stack.length() >= 1 {
          info.charset_offset = Some(stack.at(stack.length() - 1))
        }
      17 =>
        if stack.length() >= 1 {
          info.charstrings_offset = Some(stack.at(stack.length() - 1))
        }
      _ => ()
    }
    stack.clear()
  }
  info
}

///|
fn glyph_name_cff_get(cff : BytesView, gid : Int) -> String? {
  if cff.length() < 4 {
    return None
  }
  let hdr_size = cff.at(2).to_int()
  if hdr_size < 4 || hdr_size > cff.length() {
    return None
  }
  let name_ix = cff_index1_read(cff.sub(start=hdr_size, end=cff.length())).unwrap_or(CffIndex1::{
      data: cff,
      count: 0,
      off_size: 0,
      offsets_base: 0,
      objects_base: 0,
    },
  )
  let name_size = cff_index1_total_size(name_ix).unwrap_or(-1)
  if name_size < 0 {
    return None
  }
  let top_base = hdr_size + name_size
  let top_ix = cff_index1_read(cff.sub(start=top_base, end=cff.length())).unwrap_or(CffIndex1::{
      data: cff,
      count: 0,
      off_size: 0,
      offsets_base: 0,
      objects_base: 0,
    },
  )
  let top_size = cff_index1_total_size(top_ix).unwrap_or(-1)
  if top_ix.count <= 0 || top_size < 0 {
    return None
  }
  let top_dict = cff_index1_get(top_ix, 0).unwrap_or(cff.sub(start=0, end=0))
  let dict = cff_dict_parse_offsets(top_dict)
  let charset_off = dict.charset_offset.unwrap_or(-1)
  let charstrings_off = dict.charstrings_offset.unwrap_or(-1)
  if charset_off < 0 || charstrings_off < 0 || charstrings_off >= cff.length() {
    return None
  }
  // Skip String INDEX, but parse it to resolve custom SIDs.
  let string_base = top_base + top_size
  let str_ix = match
    cff_index1_read(cff.sub(start=string_base, end=cff.length())) {
    None => return None
    Some(ix) => ix
  }
  let str_size = match cff_index1_total_size(str_ix) {
    None => return None
    Some(v) => v
  }
  let global_base = string_base + str_size
  let global_ix = match
    cff_index1_read(cff.sub(start=global_base, end=cff.length())) {
    None => return None
    Some(ix) => ix
  }
  let global_size = match cff_index1_total_size(global_ix) {
    None => return None
    Some(v) => v
  }
  global_size |> ignore
  let char_ix = match
    cff_index1_read(cff.sub(start=charstrings_off, end=cff.length())) {
    None => return None
    Some(ix) => ix
  }
  let glyph_count = char_ix.count
  if gid < 0 || gid >= glyph_count {
    return None
  }
  // Only support custom charset format 0 for MVP (charset_off >= 3).
  if charset_off < 3 || charset_off >= cff.length() {
    return None
  }
  let format = cff.at(charset_off).to_int()
  if format != 0 {
    return None
  }
  if gid == 0 {
    return Some(".notdef")
  }
  let sid_pos = charset_off + 1 + (gid - 1) * 2
  if sid_pos + 2 > cff.length() {
    return None
  }
  let sid = glyph_name_read_u16_be(cff, sid_pos).unwrap_or(-1)
  if sid < 391 {
    return None
  }
  let custom_idx = sid - 391
  let bytes = match cff_index1_get(str_ix, custom_idx) {
    None => return None
    Some(v) => v
  }
  let chars : Array[Char] = Array::new()
  for b in bytes.iter() {
    chars.push(b.to_int().unsafe_to_char())
  }
  Some(glyph_name_truncate(String::from_array(chars.op_as_view())))
}

///|
priv enum GlyphNamesInner {
  Post(BytesView, Int)
  Cff(BytesView, Int)
  Synthesized(Int)
}

///|
pub struct GlyphNames {
  priv inner : GlyphNamesInner
}

///|
pub fn GlyphNames::new(font : FontRef) -> GlyphNames {
  let num_glyphs = glyph_name_read_maxp_num_glyphs(font)
  match font.table(GLYPH_TAG_POST) {
    None => ()
    Some(post) =>
      // Prefer post if it looks like v2.0 with names.
      if glyph_name_post_v2_get(post, 0) is Some(_) {
        return GlyphNames::{ inner: Post(post, num_glyphs) }
      }
  }
  match font.table(GLYPH_TAG_CFF) {
    None => ()
    Some(cff) =>
      if glyph_name_cff_get(cff, 0) is Some(_) {
        return GlyphNames::{ inner: Cff(cff, num_glyphs) }
      }
  }
  GlyphNames::{ inner: Synthesized(num_glyphs) }
}

///|
pub fn GlyphNames::source(self : GlyphNames) -> GlyphNameSource {
  match self.inner {
    Post(_, _) => GlyphNameSource::Post
    Cff(_, _) => GlyphNameSource::Cff
    Synthesized(_) => GlyphNameSource::Synthesized
  }
}

///|
pub fn GlyphNames::num_glyphs(self : GlyphNames) -> Int {
  match self.inner {
    Post(_, n) | Cff(_, n) | Synthesized(n) => n
  }
}

///|
pub fn GlyphNames::get(self : GlyphNames, glyph_id : GlyphId) -> GlyphName? {
  let gid = glyph_id.to_uint64().to_int()
  if gid < 0 || gid >= self.num_glyphs() {
    return None
  }
  let name : String? = match self.inner {
    Post(post, _) => glyph_name_post_v2_get(post, gid)
    Cff(cff, _) => glyph_name_cff_get(cff, gid)
    Synthesized(_) => None
  }
  match name {
    None => Some(glyph_name_synthesize(glyph_id))
    Some(s) =>
      if s.is_empty() {
        Some(glyph_name_synthesize(glyph_id))
      } else {
        Some(GlyphName::{ name: s, synthesized: false })
      }
  }
}

///|
pub fn FontRef::glyph_names(self : FontRef) -> GlyphNames {
  GlyphNames::new(self)
}
