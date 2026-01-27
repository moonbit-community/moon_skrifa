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
/// Mapping of characters (codepoints, not graphemes) to nominal glyph ids.
///
/// Ported from `fontations/skrifa/src/charmap.rs` (Apache-2.0 OR MIT).
const TAG_CMAP : UInt = 0x636D6170 // "cmap"

///|
const CMAP_TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
const CMAP_PLATFORM_UNICODE : Int = 0

///|
const CMAP_PLATFORM_ISO : Int = 2

///|
const CMAP_PLATFORM_WINDOWS : Int = 3

///|
const CMAP_ENCODING_MS_SYMBOL : Int = 0

///|
const CMAP_ENCODING_MS_UNICODE_CS : Int = 1

///|
const CMAP_ENCODING_APPLE_UNICODE_32 : Int = 4

///|
const CMAP_ENCODING_APPLE_VARIANT_SELECTOR : Int = 5

///|
const CMAP_ENCODING_MS_UCS_4 : Int = 10

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
fn cmap_read_u8(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 1 > view.length() {
    None
  } else {
    Some(view.at(offset).to_int())
  }
}

///|
fn cmap_read_u24_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 3 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    let b2 = view.at(offset + 2).to_int()
    Some((b0 << 16) | (b1 << 8) | b2)
  }
}

///|
fn add_delta_u16(value : Int, delta : Int) -> Int {
  (value + delta) & 0xFFFF
}

///|
pub(all) enum MapVariant {
  UseDefault
  Variant(GlyphId)
}

///|
priv struct CmapIterLimits {
  max_mappings : Int
}

///|
fn CmapIterLimits::default_for_font(font : FontRef) -> CmapIterLimits {
  let num_glyphs = match font.table(CMAP_TAG_MAXP) {
    None => 0
    Some(maxp) => cmap_read_u16_be(maxp, 4).unwrap_or(0)
  }
  // A conservative upper bound that still allows iteration over most
  // real-world cmaps while preventing pathological tables from producing
  // huge allocations.
  let cap = if num_glyphs <= 0 { 65536 } else { num_glyphs * 256 }
  CmapIterLimits::{ max_mappings: cap }
}

///|
fn CmapIterLimits::default() -> CmapIterLimits {
  CmapIterLimits::{ max_mappings: 65536 }
}

///|
priv struct CodepointSubtable {
  off : Int
  format : Int
  is_symbol : Bool
}

///|
fn CodepointSubtable::map(
  self : CodepointSubtable,
  cmap : BytesView,
  codepoint : UInt,
) -> GlyphId? {
  match self.map_impl(cmap, codepoint) {
    Some(gid) => Some(gid)
    None =>
      if self.is_symbol && codepoint <= (0x00FF |> Int::reinterpret_as_uint) {
        self.map_impl(cmap, codepoint + (0xF000 |> Int::reinterpret_as_uint))
      } else {
        None
      }
  }
}

///|
fn CodepointSubtable::map_impl(
  self : CodepointSubtable,
  cmap : BytesView,
  codepoint : UInt,
) -> GlyphId? {
  let gid = if self.format == 12 {
    cmap_map_format12(cmap, self.off, codepoint)
  } else if self.format == 4 {
    // format 4 only covers BMP.
    if codepoint > (0xFFFF |> Int::reinterpret_as_uint) {
      None
    } else {
      cmap_map_format4(cmap, self.off, codepoint.to_uint64().to_int())
    }
  } else {
    None
  }
  match gid {
    None => None
    Some(g) => if g.to_u16() == 0 { None } else { Some(g) }
  }
}

///|
pub struct Charmap {
  priv cmap : BytesView?
  priv codepoint_subtable : CodepointSubtable?
  priv variant_off : Int?
  priv cmap12_limits : CmapIterLimits
}

///|
pub fn Charmap::default() -> Charmap {
  Charmap::{
    cmap: None,
    codepoint_subtable: None,
    variant_off: None,
    cmap12_limits: CmapIterLimits::default(),
  }
}

///|
pub fn Charmap::new(font : FontRef) -> Charmap {
  let limits = CmapIterLimits::default_for_font(font)
  match font.table(TAG_CMAP) {
    None =>
      Charmap::{
        cmap: None,
        codepoint_subtable: None,
        variant_off: None,
        cmap12_limits: limits,
      }
    Some(cmap) => {
      let (codepoint_subtable, variant_off) = cmap_select_mappings(font, cmap)
      Charmap::{
        cmap: Some(cmap),
        codepoint_subtable,
        variant_off,
        cmap12_limits: limits,
      }
    }
  }
}

///|
pub fn Charmap::has_map(self : Charmap) -> Bool {
  self.codepoint_subtable is Some(_)
}

///|
pub fn Charmap::is_symbol(self : Charmap) -> Bool {
  match self.codepoint_subtable {
    None => false
    Some(sub) => sub.is_symbol
  }
}

///|
pub fn Charmap::has_variant_map(self : Charmap) -> Bool {
  self.variant_off is Some(_)
}

///|
pub fn Charmap::map(self : Charmap, codepoint : UInt) -> GlyphId? {
  match (self.cmap, self.codepoint_subtable) {
    (Some(cmap), Some(sub)) => sub.map(cmap, codepoint)
    _ => None
  }
}

///|
pub fn Charmap::glyph_id(self : Charmap, codepoint : UInt) -> GlyphId? {
  self.map(codepoint)
}

///|
pub fn Charmap::mappings(self : Charmap) -> Array[(UInt, GlyphId)] {
  match (self.cmap, self.codepoint_subtable) {
    (Some(cmap), Some(sub)) =>
      if sub.format == 4 {
        cmap_iter_format4(cmap, sub.off)
      } else if sub.format == 12 {
        cmap_iter_format12(cmap, sub.off, self.cmap12_limits)
      } else {
        Array::new()
      }
    _ => Array::new()
  }
}

///|
pub fn Charmap::map_variant(
  self : Charmap,
  codepoint : UInt,
  selector : UInt,
) -> MapVariant? {
  match (self.cmap, self.variant_off) {
    (Some(cmap), Some(off)) => cmap_map_variant(cmap, off, codepoint, selector)
    _ => None
  }
}

///|
pub fn Charmap::variant_mappings(
  self : Charmap,
) -> Array[(UInt, UInt, MapVariant)] {
  match (self.cmap, self.variant_off) {
    (Some(cmap), Some(off)) => cmap_iter_variants(cmap, off)
    _ => Array::new()
  }
}

///|
pub fn FontRef::charmap(self : FontRef) -> Charmap {
  Charmap::new(self)
}

///|
pub struct MappingIndex {
  priv codepoint_index : Int?
  priv codepoint_is_symbol : Bool
  priv variant_index : Int?
  priv cmap12_limits : CmapIterLimits
}

///|
pub fn MappingIndex::default() -> MappingIndex {
  MappingIndex::{
    codepoint_index: None,
    codepoint_is_symbol: false,
    variant_index: None,
    cmap12_limits: CmapIterLimits::default(),
  }
}

///|
pub fn MappingIndex::new(font : FontRef) -> MappingIndex {
  let limits = CmapIterLimits::default_for_font(font)
  match font.table(TAG_CMAP) {
    None =>
      MappingIndex::{
        codepoint_index: None,
        codepoint_is_symbol: false,
        variant_index: None,
        cmap12_limits: limits,
      }
    Some(cmap) => {
      let (cp_index, cp_is_symbol, var_index) = cmap_select_mapping_indices(
        font, cmap,
      )
      MappingIndex::{
        codepoint_index: cp_index,
        codepoint_is_symbol: cp_is_symbol,
        variant_index: var_index,
        cmap12_limits: limits,
      }
    }
  }
}

///|
pub fn MappingIndex::charmap(self : MappingIndex, font : FontRef) -> Charmap {
  match font.table(TAG_CMAP) {
    None =>
      Charmap::{
        cmap: None,
        codepoint_subtable: None,
        variant_off: None,
        cmap12_limits: self.cmap12_limits,
      }
    Some(cmap) => {
      let codepoint_subtable = match self.codepoint_index {
        None => None
        Some(index) =>
          match cmap_encoding_record(cmap, index) {
            None => None
            Some((_, _, off)) => {
              let format = cmap_read_u16_be(cmap, off).unwrap_or(-1)
              if format == 4 || format == 12 {
                Some(CodepointSubtable::{
                  off,
                  format,
                  is_symbol: self.codepoint_is_symbol,
                })
              } else {
                None
              }
            }
          }
      }
      let variant_off = match self.variant_index {
        None => None
        Some(index) =>
          match cmap_encoding_record(cmap, index) {
            None => None
            Some((_, _, off)) =>
              if cmap_read_u16_be(cmap, off).unwrap_or(-1) == 14 {
                Some(off)
              } else {
                None
              }
          }
      }
      Charmap::{
        cmap: Some(cmap),
        codepoint_subtable,
        variant_off,
        cmap12_limits: self.cmap12_limits,
      }
    }
  }
}

///|
fn cmap_select_mappings(
  font : FontRef,
  cmap : BytesView,
) -> (CodepointSubtable?, Int?) {
  let (cp_index, cp_is_symbol, var_index) = cmap_select_mapping_indices(
    font, cmap,
  )
  let codepoint_subtable = match cp_index {
    None => None
    Some(index) =>
      match cmap_encoding_record(cmap, index) {
        None => None
        Some((_, _, off)) => {
          let format = cmap_read_u16_be(cmap, off).unwrap_or(-1)
          if format == 4 || format == 12 {
            Some(CodepointSubtable::{ off, format, is_symbol: cp_is_symbol })
          } else {
            None
          }
        }
      }
  }
  let variant_off = match var_index {
    None => None
    Some(index) =>
      match cmap_encoding_record(cmap, index) {
        None => None
        Some((_, _, off)) =>
          if cmap_read_u16_be(cmap, off).unwrap_or(-1) == 14 {
            Some(off)
          } else {
            None
          }
      }
  }
  (codepoint_subtable, variant_off)
}

///|
fn cmap_select_mapping_indices(
  _font : FontRef,
  cmap : BytesView,
) -> (Int?, Bool, Int?) {
  let num_tables = cmap_read_u16_be(cmap, 2).unwrap_or(0)
  let mut best_kind = 0
  let mut best_index : Int? = None
  let mut best_is_symbol = false
  let mut variant_index : Int? = None
  // Search encoding records in reverse, prioritizing UCS-4 over UCS-2, and
  // preferring symbol over all others (HarfBuzz behavior).
  for i in 0..<num_tables {
    let index = num_tables - 1 - i
    match cmap_encoding_record(cmap, index) {
      None => ()
      Some((platform, encoding, off)) => {
        let format = cmap_read_u16_be(cmap, off).unwrap_or(-1)
        if platform == CMAP_PLATFORM_UNICODE &&
          encoding == CMAP_ENCODING_APPLE_VARIANT_SELECTOR {
          if variant_index is None && format == 14 {
            variant_index = Some(index)
          }
          continue
        }
        if format != 4 && format != 12 {
          continue
        }
        let kind = if platform == CMAP_PLATFORM_WINDOWS &&
          encoding == CMAP_ENCODING_MS_SYMBOL {
          3
        } else if (
            platform == CMAP_PLATFORM_WINDOWS &&
            encoding == CMAP_ENCODING_MS_UCS_4
          ) ||
          (
            platform == CMAP_PLATFORM_UNICODE &&
            encoding == CMAP_ENCODING_APPLE_UNICODE_32
          ) {
          2
        } else if platform == CMAP_PLATFORM_ISO ||
          platform == CMAP_PLATFORM_UNICODE ||
          (
            platform == CMAP_PLATFORM_WINDOWS &&
            encoding == CMAP_ENCODING_MS_UNICODE_CS
          ) {
          1
        } else {
          0
        }
        if kind > best_kind {
          best_kind = kind
          best_index = Some(index)
          best_is_symbol = kind == 3
        }
      }
    }
  }
  (best_index, best_is_symbol, variant_index)
}

///|
fn cmap_encoding_record(cmap : BytesView, index : Int) -> (Int, Int, Int)? {
  if index < 0 {
    return None
  }
  let num_tables = cmap_read_u16_be(cmap, 2).unwrap_or(-1)
  if num_tables < 0 || index >= num_tables {
    return None
  }
  let rec = 4 + index * 8
  let platform = cmap_read_u16_be(cmap, rec).unwrap_or(-1)
  let encoding = cmap_read_u16_be(cmap, rec + 2).unwrap_or(-1)
  let off = cmap_read_u32_be_int(cmap, rec + 4).unwrap_or(-1)
  if off < 0 || off >= cmap.length() {
    None
  } else {
    Some((platform, encoding, off))
  }
}

///|
fn cmap_map_format12(
  cmap : BytesView,
  base : Int,
  codepoint : UInt,
) -> GlyphId? {
  let length = cmap_read_u32_be_int(cmap, base + 4).unwrap_or(-1)
  if length < 0 || base + length > cmap.length() {
    return None
  }
  let n_groups = cmap_read_u32_be_int(cmap, base + 12).unwrap_or(-1)
  if n_groups <= 0 {
    return None
  }
  let groups_base = base + 16
  let mut lo = 0
  let mut hi = n_groups - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let g = groups_base + mid * 12
    let start = cmap_read_u32_be(cmap, g).unwrap_or(0)
    let end = cmap_read_u32_be(cmap, g + 4).unwrap_or(0)
    if codepoint < start {
      hi = mid - 1
    } else if codepoint > end {
      lo = mid + 1
    } else {
      let start_gid = cmap_read_u32_be(cmap, g + 8).unwrap_or(0)
      let gid = start_gid + (codepoint - start)
      let gidi = gid.to_uint64().to_int()
      if gidi < 0 || gidi > 0xFFFF {
        return None
      }
      return Some(GlyphId::new(gidi.to_uint16()))
    }
  }
  None
}

///|
fn cmap_map_format4(cmap : BytesView, base : Int, codepoint : Int) -> GlyphId? {
  let length = cmap_read_u16_be(cmap, base + 2).unwrap_or(-1)
  if length < 0 || base + length > cmap.length() {
    return None
  }
  let seg_count = cmap_read_u16_be(cmap, base + 6).unwrap_or(-1) / 2
  if seg_count <= 0 {
    return None
  }
  let end_codes_base = base + 14
  let start_codes_base = end_codes_base + 2 * seg_count + 2
  let id_delta_base = start_codes_base + 2 * seg_count
  let id_range_off_base = id_delta_base + 2 * seg_count
  for i in 0..<seg_count {
    let end_code = cmap_read_u16_be(cmap, end_codes_base + i * 2).unwrap_or(-1)
    if end_code < 0 {
      return None
    }
    if codepoint > end_code {
      continue
    }
    let start_code = cmap_read_u16_be(cmap, start_codes_base + i * 2).unwrap_or(
      -1,
    )
    if start_code < 0 {
      return None
    }
    if codepoint < start_code {
      return None
    }
    let delta = cmap_read_i16_be(cmap, id_delta_base + i * 2).unwrap_or(0)
    let range_off = cmap_read_u16_be(cmap, id_range_off_base + i * 2).unwrap_or(
      -1,
    )
    if range_off < 0 {
      return None
    }
    if range_off == 0 {
      let gid = add_delta_u16(codepoint, delta)
      return Some(GlyphId::new(gid.to_uint16()))
    } else {
      let ro_pos = id_range_off_base + i * 2
      let glyph_pos = ro_pos + range_off + 2 * (codepoint - start_code)
      let raw_gid = cmap_read_u16_be(cmap, glyph_pos).unwrap_or(-1)
      if raw_gid < 0 {
        return None
      }
      if raw_gid == 0 {
        return Some(GlyphId::default())
      } else {
        let gid = add_delta_u16(raw_gid, delta)
        return Some(GlyphId::new(gid.to_uint16()))
      }
    }
  }
  None
}

///|
fn cmap_iter_format12(
  cmap : BytesView,
  base : Int,
  limits : CmapIterLimits,
) -> Array[(UInt, GlyphId)] {
  let out : Array[(UInt, GlyphId)] = Array::new()
  let length = cmap_read_u32_be_int(cmap, base + 4).unwrap_or(-1)
  if length < 0 || base + length > cmap.length() {
    return out
  }
  let n_groups = cmap_read_u32_be_int(cmap, base + 12).unwrap_or(-1)
  if n_groups <= 0 {
    return out
  }
  let groups_base = base + 16
  let mut produced = 0
  for i in 0..<n_groups {
    let g = groups_base + i * 12
    let start = cmap_read_u32_be(cmap, g).unwrap_or(0)
    let end = cmap_read_u32_be(cmap, g + 4).unwrap_or(0)
    let start_gid = cmap_read_u32_be(cmap, g + 8).unwrap_or(0)
    if end < start {
      continue
    }
    let mut cp = start
    while cp <= end {
      let gid = start_gid + (cp - start)
      let gidi = gid.to_uint64().to_int()
      if gidi > 0 && gidi <= 0xFFFF {
        out.push((cp, GlyphId::new(gidi.to_uint16())))
        produced = produced + 1
        if produced >= limits.max_mappings {
          return out
        }
      }
      cp = cp + (1 |> Int::reinterpret_as_uint)
    }
  }
  out
}

///|
fn cmap_iter_format4(cmap : BytesView, base : Int) -> Array[(UInt, GlyphId)] {
  let out : Array[(UInt, GlyphId)] = Array::new()
  // BMP only; iterate over all BMP codepoints and query the mapping. This is
  // simpler than a faithful port of read-fonts' iterator and is bounded.
  for cp in 0..<0x10000 {
    match cmap_map_format4(cmap, base, cp) {
      None => ()
      Some(gid) =>
        if gid.to_u16() != 0 {
          out.push((cp.reinterpret_as_uint(), gid))
        }
    }
  }
  out
}

///|
fn cmap_map_variant(
  cmap : BytesView,
  base : Int,
  codepoint : UInt,
  selector : UInt,
) -> MapVariant? {
  if cmap_read_u16_be(cmap, base).unwrap_or(-1) != 14 {
    return None
  }
  let length = cmap_read_u32_be_int(cmap, base + 2).unwrap_or(-1)
  if length < 0 || base + length > cmap.length() {
    return None
  }
  let n_records = cmap_read_u32_be_int(cmap, base + 6).unwrap_or(-1)
  if n_records <= 0 {
    return None
  }
  let records_base = base + 10
  let want = selector.to_uint64().to_int()
  for i in 0..<n_records {
    let rec = records_base + i * 11
    let var_selector = cmap_read_u24_be(cmap, rec).unwrap_or(-1)
    if var_selector != want {
      continue
    }
    let default_off = cmap_read_u32_be_int(cmap, rec + 3).unwrap_or(0)
    let non_default_off = cmap_read_u32_be_int(cmap, rec + 7).unwrap_or(0)
    let cp = codepoint.to_uint64().to_int()
    if non_default_off != 0 {
      match cmap_map_non_default_uvs(cmap, base + non_default_off, cp) {
        None => ()
        Some(gid) => return Some(Variant(gid))
      }
    }
    if default_off != 0 {
      if cmap_in_default_uvs(cmap, base + default_off, cp) {
        return Some(UseDefault)
      }
    }
    return None
  }
  None
}

///|
fn cmap_in_default_uvs(cmap : BytesView, base : Int, codepoint : Int) -> Bool {
  let n_ranges = cmap_read_u32_be_int(cmap, base).unwrap_or(-1)
  if n_ranges <= 0 {
    return false
  }
  let ranges_base = base + 4
  for i in 0..<n_ranges {
    let r = ranges_base + i * 4
    let start = cmap_read_u24_be(cmap, r).unwrap_or(-1)
    let addl = cmap_read_u8(cmap, r + 3).unwrap_or(-1)
    if start < 0 || addl < 0 {
      continue
    }
    let end = start + addl
    if codepoint >= start && codepoint <= end {
      return true
    }
  }
  false
}

///|
fn cmap_map_non_default_uvs(
  cmap : BytesView,
  base : Int,
  codepoint : Int,
) -> GlyphId? {
  let n_maps = cmap_read_u32_be_int(cmap, base).unwrap_or(-1)
  if n_maps <= 0 {
    return None
  }
  let maps_base = base + 4
  for i in 0..<n_maps {
    let m = maps_base + i * 5
    let cp = cmap_read_u24_be(cmap, m).unwrap_or(-1)
    if cp != codepoint {
      continue
    }
    let gid = cmap_read_u16_be(cmap, m + 3).unwrap_or(-1)
    if gid <= 0 || gid > 0xFFFF {
      return None
    }
    return Some(GlyphId::new(gid.to_uint16()))
  }
  None
}

///|
fn cmap_iter_variants(
  cmap : BytesView,
  base : Int,
) -> Array[(UInt, UInt, MapVariant)] {
  let out : Array[(UInt, UInt, MapVariant)] = Array::new()
  if cmap_read_u16_be(cmap, base).unwrap_or(-1) != 14 {
    return out
  }
  let length = cmap_read_u32_be_int(cmap, base + 2).unwrap_or(-1)
  if length < 0 || base + length > cmap.length() {
    return out
  }
  let n_records = cmap_read_u32_be_int(cmap, base + 6).unwrap_or(-1)
  if n_records <= 0 {
    return out
  }
  let records_base = base + 10
  for i in 0..<n_records {
    let rec = records_base + i * 11
    let selector = cmap_read_u24_be(cmap, rec).unwrap_or(-1)
    if selector < 0 {
      continue
    }
    let default_off = cmap_read_u32_be_int(cmap, rec + 3).unwrap_or(0)
    let non_default_off = cmap_read_u32_be_int(cmap, rec + 7).unwrap_or(0)
    let sel_u = selector.reinterpret_as_uint()
    if default_off != 0 {
      let def_base = base + default_off
      let n_ranges = cmap_read_u32_be_int(cmap, def_base).unwrap_or(-1)
      if n_ranges > 0 {
        let ranges_base = def_base + 4
        for j in 0..<n_ranges {
          let r = ranges_base + j * 4
          let start = cmap_read_u24_be(cmap, r).unwrap_or(-1)
          let addl = cmap_read_u8(cmap, r + 3).unwrap_or(-1)
          if start < 0 || addl < 0 {
            continue
          }
          let mut cp = start.reinterpret_as_uint()
          let end = (start + addl).reinterpret_as_uint()
          while cp <= end {
            out.push((cp, sel_u, UseDefault))
            cp = cp + (1 |> Int::reinterpret_as_uint)
          }
        }
      }
    }
    if non_default_off != 0 {
      let non_base = base + non_default_off
      let n_maps = cmap_read_u32_be_int(cmap, non_base).unwrap_or(-1)
      if n_maps > 0 {
        let maps_base = non_base + 4
        for j in 0..<n_maps {
          let m = maps_base + j * 5
          let cp = cmap_read_u24_be(cmap, m).unwrap_or(-1)
          let gid = cmap_read_u16_be(cmap, m + 3).unwrap_or(-1)
          if cp >= 0 && gid > 0 && gid <= 0xFFFF {
            out.push(
              (
                cp.reinterpret_as_uint(),
                sel_u,
                Variant(GlyphId::new(gid.to_uint16())),
              ),
            )
          }
        }
      }
    }
  }
  out
}
