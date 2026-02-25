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
fn cff_read_u16_be(view : BytesView, offset : Int) -> Int? {
  type2_read_u16_be(view, offset)
}

///|
fn cff_fdselect_index(
  data : BytesView,
  offset : Int,
  glyph_index : Int,
) -> Int? {
  // Same as CFF2 FDSelect formats 0 and 3.
  if offset < 0 || offset >= data.length() {
    return None
  }
  let select = data[offset:data.length()]
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
        let n_ranges = cff_read_u16_be(select, 1).unwrap_or(0)
        if n_ranges <= 0 {
          return None
        }
        let ranges_base = 3
        let rec_size = 3
        let sentinel_off = ranges_base + n_ranges * rec_size
        if sentinel_off + 2 > select.length() {
          return None
        }
        let sentinel = cff_read_u16_be(select, sentinel_off).unwrap_or(0)
        if glyph_index < 0 || glyph_index >= sentinel {
          return None
        }
        let mut r = 0
        while r < n_ranges {
          let rec = ranges_base + r * rec_size
          if rec + 3 > select.length() {
            break
          }
          let first = cff_read_u16_be(select, rec).unwrap_or(0)
          let fd = select.at(rec + 2).to_int()
          let next_first = if r + 1 < n_ranges {
            cff_read_u16_be(select, rec + rec_size).unwrap_or(sentinel)
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
    Some(view[start:view.length()])
  }
}

///|
fn cff_scale_for_size(size : @moon_skrifa.Size, upem : Int) -> CffFixed? {
  match size.ppem() {
    None => None
    Some(ppem) =>
      if upem <= 0 {
        None
      } else {
        // Match fontations: intermediate 26.6 scale in 16.16.
        let ppem_26_6 = (ppem * 64.0).round().to_int()
        Some(CffFixed::from_bits(ppem_26_6 * 65536 / upem))
      }
  }
}

///|
fn cff_scale_for_hinting(scale : CffFixed) -> CffFixed {
  // Ported from `scale_for_hinting`.
  CffFixed::from_bits((scale.bits + 32) / 64)
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
  //
  // For CID-keyed CFF, Private DICT/Subrs may come from FDArray+FDSelect
  // instead of Top DICT.
  let mut private_size : Int? = dict.private_size
  let mut private_off : Int? = dict.private_offset
  if dict.fd_array_offset is Some(fd_array_off) {
    let fd_select_ix = match dict.fd_select_offset {
      None => 0
      Some(sel_off) =>
        cff_fdselect_index(cff, sel_off, glyph_index).unwrap_or(0)
    }
    let fd_ix = match cff_slice(cff, fd_array_off) {
      None => return None
      Some(s) =>
        match type2_index1_read(s) {
          None => return None
          Some(ix) => ix
        }
    }
    let fd_data = match type2_index_get(fd_ix, fd_select_ix) {
      None => return None
      Some(v) => v
    }
    let fd_dict = cff_dict_parse(fd_data)
    private_size = fd_dict.private_size
    private_off = fd_dict.private_offset
  }

  let local_ix : Type2Index? = match (private_size, private_off) {
    (Some(size), Some(off)) =>
      if size <= 0 || off < 0 || off + size > cff.length() {
        None
      } else {
        let end = off + size
        let private = cff[off:end]
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
  type2_path(charstring, Some(global_ix), local_ix, None)
}

///|
fn cff_hint_scale_for_hinting(
  size : @moon_skrifa.Size,
  upem : Int,
) -> CffFixed? {
  match cff_scale_for_size(size, upem) {
    None => None
    Some(scale) => Some(cff_scale_for_hinting(scale))
  }
}

///|
fn cff_outline_path_hinted(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  size : @moon_skrifa.Size,
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

  // Resolve private dict + optional font dict matrix for CID-keyed CFF.
  let mut private_size : Int? = dict.private_size
  let mut private_off : Int? = dict.private_offset
  let mut sub_matrix : CffMatrix? = None
  let mut sub_matrix_upem : Int? = None
  if dict.fd_array_offset is Some(fd_array_off) {
    let fd_select_ix = match dict.fd_select_offset {
      None => 0
      Some(sel_off) =>
        cff_fdselect_index(cff, sel_off, glyph_index).unwrap_or(0)
    }
    let fd_ix = match cff_slice(cff, fd_array_off) {
      None => return None
      Some(s) =>
        match type2_index1_read(s) {
          None => return None
          Some(ix) => ix
        }
    }
    let fd_data = match type2_index_get(fd_ix, fd_select_ix) {
      None => return None
      Some(v) => v
    }
    let fd_dict = cff_dict_parse(fd_data)
    private_size = fd_dict.private_size
    private_off = fd_dict.private_offset
    sub_matrix = fd_dict.font_matrix
    sub_matrix_upem = fd_dict.font_matrix_upem
  }

  // Compute font matrix + adjusted UPEM per FreeType (via fontations).
  let upem = outline_units_per_em(font).to_int()
  let mut matrix : CffMatrix? = None
  let mut matrix_upem = upem
  let top_norm : (CffMatrix, Int)? = match
    (dict.font_matrix, dict.font_matrix_upem) {
    (Some(m), Some(u)) => Some(cff_normalize_font_matrix(m, u))
    _ => None
  }
  match (top_norm, sub_matrix, sub_matrix_upem) {
    (Some((top_m, top_u)), Some(sub_m), Some(sub_u)) => {
      let scaling = if top_u > 1 && sub_u > 1 { top_u.min(sub_u) } else { 1 }
      let combined = cff_matrix_mul_scaled(top_m, sub_m, scaling)
      let upem_bits = CffFixed::from_bits(sub_u).mul_div(
          CffFixed::from_bits(top_u),
          CffFixed::from_bits(scaling),
        ).bits
      let (norm_m, norm_u) = cff_normalize_font_matrix(combined, upem_bits)
      if !CffMatrix::is_identity(norm_m) {
        matrix = Some(norm_m)
      }
      matrix_upem = norm_u
    }
    (Some((top_m, top_u)), _, _) => {
      if !CffMatrix::is_identity(top_m) {
        matrix = Some(top_m)
      }
      matrix_upem = top_u
    }
    (None, Some(sub_m), Some(sub_u)) => {
      let (norm_m, norm_u) = cff_normalize_font_matrix(sub_m, sub_u)
      if !CffMatrix::is_identity(norm_m) {
        matrix = Some(norm_m)
      }
      matrix_upem = norm_u
    }
    _ => ()
  }

  // Compute hint scale, adjusting for matrix-derived UPEM if needed.
  let scale = match cff_scale_for_size(size, upem) {
    None => return None
    Some(v) => v
  }
  let scale = if matrix_upem != upem && upem > 0 && matrix_upem > 0 {
    scale.mul_div(CffFixed::from_bits(upem), CffFixed::from_bits(matrix_upem))
  } else {
    scale
  }
  let hint_scale = cff_scale_for_hinting(scale)

  // Private DICT + local Subrs (optional). Note: Private DICT may be present
  // with size==0 (valid; means all defaults).
  let mut priv_info = CffPrivateDictHintInfo::default()
  match (private_size, private_off) {
    (Some(size), Some(off)) => {
      if size < 0 || off < 0 || off + size > cff.length() {
        return None
      }
      let private_dict = cff[off:off + size]
      priv_info = cff_private_dict_hint_info(private_dict, None)
    }
    _ => ()
  }
  let local_ix : Type2Index? = match (private_off, priv_info.subrs_offset) {
    (Some(off), Some(subrs_off)) => {
      let subrs_abs = off + subrs_off
      match cff_slice(cff, subrs_abs) {
        None => None
        Some(s) => type2_index1_read(s)
      }
    }
    _ => None
  }
  let hint_state = HintState::new(priv_info.hint_params, hint_scale)
  type2_path_hinted(
    charstring,
    Some(global_ix),
    local_ix,
    None,
    hint_state,
    matrix,
  )
}

///|
fn cff_glyph_count(font : @moon_skrifa.FontRef) -> Int? {
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
  let name_size = match cff_index1_total_size(name_ix) {
    None => return None
    Some(v) => v
  }
  let mut pos = hdr_size + name_size
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
  // Global Subrs INDEX (skip over it, but validate)
  match cff_slice(cff, pos) {
    None => return None
    Some(s) =>
      match type2_index1_read(s) {
        None => return None
        Some(_) => ()
      }
  }
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
  Some(charstrings_ix.count)
}
