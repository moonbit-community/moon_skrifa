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
/// CFF (OpenType `CFF ` table) outline extraction (MVP).
///
/// This supports a single-font CFF FontSet and Type2 charstrings.

///|
const CFF_HEADER_MIN_SIZE : Int = 4

///|
fn cff_index1_total_size(ix : Type2Index) -> Int? {
  if ix.count == 0 {
    Some(2)
  } else {
    match type2_index_read_offset(ix, ix.count) {
      None => None
      Some(end_off) => Some(ix.objects_base + end_off)
    }
  }
}

///|
fn cff_slice(view : BytesView, start : Int) -> BytesView? {
  if start < 0 || start > view.length() {
    None
  } else {
    Some(view.sub(start~, end=view.length()))
  }
}

///|
fn cff_outline_path(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> Array[PathElement]? {
  let cff = match font.table(TAG_CFF) {
    None => return None
    Some(v) => v
  }
  if cff.length() < CFF_HEADER_MIN_SIZE {
    return None
  }
  let hdr_size = cff.at(2).to_int()
  if hdr_size < CFF_HEADER_MIN_SIZE || hdr_size > cff.length() {
    return None
  }
  // Name INDEX
  let name_ix = match cff_slice(cff, hdr_size) {
    None => return None
    Some(s) =>
      match type2_index1_read(s) {
        None => return None
        Some(ix) => ix
      }
  }
  let mut pos = hdr_size
  let name_size = match cff_index1_total_size(name_ix) {
    None => return None
    Some(v) => v
  }
  pos = pos + name_size
  // Top DICT INDEX
  let top_ix = match cff_slice(cff, pos) {
    None => return None
    Some(s) =>
      match type2_index1_read(s) {
        None => return None
        Some(ix) => ix
      }
  }
  let top_size = match cff_index1_total_size(top_ix) {
    None => return None
    Some(v) => v
  }
  let top_dict = match type2_index_get(top_ix, 0) {
    None => return None
    Some(v) => v
  }
  pos = pos + top_size
  // String INDEX
  let str_ix = match cff_slice(cff, pos) {
    None => return None
    Some(s) =>
      match type2_index1_read(s) {
        None => return None
        Some(ix) => ix
      }
  }
  let str_size = match cff_index1_total_size(str_ix) {
    None => return None
    Some(v) => v
  }
  pos = pos + str_size
  // Global Subrs INDEX
  let global_ix = match cff_slice(cff, pos) {
    None => return None
    Some(s) =>
      match type2_index1_read(s) {
        None => return None
        Some(ix) => ix
      }
  }

  // Parse Top DICT for CharStrings and Private DICT.
  let dict = cff_dict_parse(top_dict)
  let charstrings_off = match dict.charstrings_offset {
    None => return None
    Some(v) => v
  }
  let charstrings_ix = match cff_slice(cff, charstrings_off) {
    None => return None
    Some(s) =>
      match type2_index1_read(s) {
        None => return None
        Some(ix) => ix
      }
  }
  let glyph_index = gid.to_uint64().to_int()
  if glyph_index < 0 || glyph_index >= charstrings_ix.count {
    return None
  }
  let charstring = match type2_index_get(charstrings_ix, glyph_index) {
    None => return None
    Some(v) => v
  }
  if charstring.length() == 0 {
    return Some(Array::new())
  }

  // Optional local Subrs.
  let local_ix : Type2Index? = match (dict.private_size, dict.private_offset) {
    (Some(size), Some(off)) =>
      if size <= 0 || off < 0 || off + size > cff.length() {
        None
      } else {
        let end = off + size
        let private = cff.sub(start=off, end~)
        let priv_dict = cff_dict_parse(private)
        match priv_dict.subrs_offset {
          None => None
          Some(subrs_off) => {
            let subrs_abs = off + subrs_off
            match cff_slice(cff, subrs_abs) {
              None => None
              Some(s) => type2_index1_read(s)
            }
          }
        }
      }
    _ => None
  }
  type2_path(charstring, Some(global_ix), local_ix)
}
