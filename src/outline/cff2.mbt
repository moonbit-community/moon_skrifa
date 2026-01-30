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
/// - Variation operators (vsindex/blend) are supported when VarStore is present.

///|
fn cff2_read_u16_be(view : BytesView, offset : Int) -> Int? {
  type2_read_u16_be(view, offset)
}

///|
fn cff2_fdselect_index(
  data : BytesView,
  offset : Int,
  glyph_index : Int,
) -> Int? {
  if offset < 0 || offset >= data.length() {
    return None
  }
  let select = data.sub(start=offset, end=data.length())
  if select.length() < 1 {
    return None
  }
  let format = select.at(0).to_int()
  match format {
    0 =>
      if glyph_index < 0 || 1 + glyph_index >= select.length() {
        None
      } else {
        Some(select.at(1 + glyph_index).to_int())
      }
    3 =>
      if select.length() < 3 {
        None
      } else {
        let n_ranges = cff2_read_u16_be(select, 1).unwrap_or(0)
        if n_ranges <= 0 {
          return None
        }
        let ranges_base = 3
        let rec_size = 3
        let sentinel_off = ranges_base + n_ranges * rec_size
        if sentinel_off + 2 > select.length() {
          return None
        }
        let sentinel = cff2_read_u16_be(select, sentinel_off).unwrap_or(0)
        if glyph_index < 0 || glyph_index >= sentinel {
          return None
        }
        let mut r = 0
        while r < n_ranges {
          let rec = ranges_base + r * rec_size
          if rec + 3 > select.length() {
            break
          }
          let first = cff2_read_u16_be(select, rec).unwrap_or(0)
          let fd = select.at(rec + 2).to_int()
          let next_first = if r + 1 < n_ranges {
            cff2_read_u16_be(select, rec + rec_size).unwrap_or(sentinel)
          } else {
            sentinel
          }
          if glyph_index >= first && glyph_index < next_first {
            return Some(fd)
          }
          r = r + 1
        }
        None
      }
    _ => None
  }
}

///|
fn cff2_outline_path_hinted(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  size : @moon_skrifa.Size,
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
  let blend_state = match dict.var_store_offset {
    None => None
    Some(off0) => {
      // ItemVariationStore is preceded by a 2-byte length.
      let off = off0 + 2
      if off < 0 || off > cff2.length() {
        None
      } else {
        type2_blend_state_new(cff2, off, coords)
      }
    }
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
  let upem = outline_units_per_em(font).to_int()
  let hint_scale = match cff_hint_scale_for_hinting(size, upem) {
    None => return None
    Some(v) => v
  }

  // Resolve private dict from FDArray/FDSelect if present, else use top dict.
  let mut private_size : Int? = dict.private_size
  let mut private_off : Int? = dict.private_offset
  if dict.fd_array_offset is Some(fd_array_off) {
    let fd_ix = match
      type2_index2_read(cff2.sub(start=fd_array_off, end=cff2.length())) {
      None => return None
      Some(ix) => ix
    }
    let fd_select_ix = match dict.fd_select_offset {
      None => 0
      Some(sel_off) =>
        cff2_fdselect_index(cff2, sel_off, glyph_index).unwrap_or(0)
    }
    let fd_data = match type2_index_get(fd_ix, fd_select_ix) {
      None => return None
      Some(v) => v
    }
    let fd_dict = cff_dict_parse(fd_data)
    private_size = fd_dict.private_size
    private_off = fd_dict.private_offset
  }
  // Private DICT + local Subrs (optional). Note: Private DICT may be present
  // with size==0 (valid; means all defaults).
  let mut poff : Int? = None
  let mut priv_info = CffPrivateDictHintInfo::default()
  match (private_size, private_off) {
    (Some(psize), Some(poff0)) => {
      poff = Some(poff0)
      if psize < 0 || poff0 < 0 || poff0 + psize > cff2.length() {
        return None
      }
      let private_dict = cff2.sub(start=poff0, end=poff0 + psize)
      priv_info = cff_private_dict_hint_info(private_dict, blend_state)
    }
    _ => ()
  }
  match blend_state {
    None => ()
    Some(bs) =>
      if priv_info.store_index != 0 {
        Type2BlendState::set_store_index(bs, priv_info.store_index) |> ignore
      }
  }
  let local_ix : Type2Index? = match (poff, priv_info.subrs_offset) {
    (Some(poff0), Some(subrs_off)) => {
      let subrs_abs = poff0 + subrs_off
      if subrs_abs < 0 || subrs_abs > cff2.length() {
        None
      } else {
        type2_index2_read(cff2.sub(start=subrs_abs, end=cff2.length()))
      }
    }
    _ => None
  }
  let hint_state = HintState::new(priv_info.hint_params, hint_scale)
  type2_path_hinted(
    charstring,
    Some(global_ix),
    local_ix,
    blend_state,
    hint_state,
    None,
  )
}

///|

///|
fn cff2_outline_path(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
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
  let blend_state = match dict.var_store_offset {
    None => None
    Some(off) =>
      if off < 0 || off > cff2.length() {
        None
      } else {
        type2_blend_state_new(cff2, off, coords)
      }
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
  type2_path(charstring, Some(global_ix), None, blend_state)
}

///|
fn cff2_glyph_count(font : @moon_skrifa.FontRef) -> Int? {
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
  let char_ix = match
    type2_index2_read(cff2.sub(start=charstrings_off, end=cff2.length())) {
    None => return None
    Some(ix) => ix
  }
  Some(char_ix.count)
}
