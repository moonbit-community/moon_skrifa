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
/// CFF2 (OpenType `CFF2` table) outline extraction (MVP).
///
/// This parses the header/top-dict and evaluates Type2 charstrings.
///
/// Notes:
/// - Variation operators (vsindex/blend) are currently unsupported.
/// - Font DICT / FDSelect are ignored for now; local subrs are therefore unsupported.

///|
fn cff2_read_u16_be(view : BytesView, offset : Int) -> Int? {
  type2_read_u16_be(view, offset)
}

///|

///|
fn cff2_outline_path(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> Array[PathElement]? {
  let cff2 = match font.table(TAG_CFF2) {
    None => return None
    Some(v) => v
  }
  if cff2.length() < 5 {
    return None
  }
  let major = cff2.at(0).to_int()
  let minor = cff2.at(1).to_int()
  if major != 2 || minor != 0 {
    return None
  }
  let header_size = cff2.at(2).to_int()
  let top_len = match cff2_read_u16_be(cff2, 3) {
    None => return None
    Some(v) => v
  }
  if header_size < 5 || header_size > cff2.length() {
    return None
  }
  let top_start = header_size
  let top_end = top_start + top_len
  if top_len < 0 || top_end < top_start || top_end > cff2.length() {
    return None
  }
  let top_dict = cff2.sub(start=top_start, end=top_end)
  let dict = cff_dict_parse(top_dict)
  let charstrings_off = match dict.charstrings_offset {
    None => return None
    Some(v) => v
  }
  if charstrings_off < 0 || charstrings_off > cff2.length() {
    return None
  }
  let global_off = top_end
  if global_off > cff2.length() {
    return None
  }
  let global_ix = match
    type2_index2_read(cff2.sub(start=global_off, end=cff2.length())) {
    None => return None
    Some(ix) => ix
  }
  // CharStrings INDEX2 is at the offset from Top DICT.
  let char_ix = match
    type2_index2_read(cff2.sub(start=charstrings_off, end=cff2.length())) {
    None => return None
    Some(ix) => ix
  }
  let glyph_index = gid.to_uint64().to_int()
  if glyph_index < 0 || glyph_index >= char_ix.count {
    return None
  }
  let charstring = match type2_index_get(char_ix, glyph_index) {
    None => return None
    Some(v) => v
  }
  if charstring.length() == 0 {
    return Some(Array::new())
  }
  type2_path(charstring, Some(global_ix), None)
}
