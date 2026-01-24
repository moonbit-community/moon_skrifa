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
/// Minimal horizontal metrics (maxp/hhea/hmtx).
///
/// Ported from `fontations/skrifa/src/metrics.rs` (Apache-2.0 OR MIT).
const TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
const TAG_HHEA : UInt = 0x68686561 // "hhea"

///|
const TAG_HMTX : UInt = 0x686D7478 // "hmtx"

///|
const METRICS_TAG_HEAD : UInt = 0x68656164 // "head"

///|
const METRICS_TAG_OS2 : UInt = 0x4F532F32 // "OS/2"

///|
const METRICS_TAG_POST : UInt = 0x706F7374 // "post"

///|
const METRICS_TAG_HVAR : UInt = 0x48564152 // "HVAR"

///|
const METRICS_F2DOT14_SCALE : Double = 16384.0

///|
fn metrics_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn metrics_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match metrics_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
fn metrics_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn metrics_read_u32_be_int(view : BytesView, offset : Int) -> Int? {
  match metrics_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.to_uint64().to_int())
  }
}

///|
fn metrics_read_i32_be(view : BytesView, offset : Int) -> Int? {
  match metrics_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.reinterpret_as_int())
  }
}

///|
fn metrics_read_u8(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 1 > view.length() {
    None
  } else {
    Some(view.at(offset).to_int())
  }
}

///|
fn metrics_read_i8(view : BytesView, offset : Int) -> Int? {
  match metrics_read_u8(view, offset) {
    None => None
    Some(u) => if u >= 0x80 { Some(u - 0x100) } else { Some(u) }
  }
}

///|
fn metrics_read_u24_be(view : BytesView, offset : Int) -> Int? {
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
pub struct Metrics {
  priv num_glyphs : Int
  priv num_hmetrics : Int
  priv hmtx : BytesView
}

///|
/// Parses required tables (maxp/hhea/hmtx) from the font.
pub fn Metrics::new(font : FontRef) -> Metrics? {
  let maxp = match font.table(TAG_MAXP) {
    None => return None
    Some(v) => v
  }
  let hhea = match font.table(TAG_HHEA) {
    None => return None
    Some(v) => v
  }
  let hmtx = match font.table(TAG_HMTX) {
    None => return None
    Some(v) => v
  }
  let num_glyphs = match metrics_read_u16_be(maxp, 4) {
    None => return None
    Some(v) => v
  }
  let num_hmetrics = match metrics_read_u16_be(hhea, 34) {
    None => return None
    Some(v) => v
  }
  if num_glyphs <= 0 || num_hmetrics <= 0 || num_hmetrics > num_glyphs {
    return None
  }
  let need = num_hmetrics * 4 + (num_glyphs - num_hmetrics) * 2
  if need < 0 || hmtx.length() < need {
    return None
  }
  Some(Metrics::{ num_glyphs, num_hmetrics, hmtx })
}

///|
pub fn Metrics::num_glyphs(self : Metrics) -> Int {
  self.num_glyphs
}

///|
pub fn Metrics::number_of_hmetrics(self : Metrics) -> Int {
  self.num_hmetrics
}

///|
fn Metrics::glyph_index(self : Metrics, gid : GlyphId) -> Int? {
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= self.num_glyphs {
    None
  } else {
    Some(idx)
  }
}

///|
/// Returns advance width for a glyph in font units.
pub fn Metrics::advance_width(self : Metrics, gid : GlyphId) -> UInt? {
  match self.glyph_index(gid) {
    None => None
    Some(idx) => {
      let pos = if idx < self.num_hmetrics {
        idx * 4
      } else {
        (self.num_hmetrics - 1) * 4
      }
      match metrics_read_u16_be(self.hmtx, pos) {
        None => None
        Some(v) => Some(v.reinterpret_as_uint())
      }
    }
  }
}

///|
/// Returns left side bearing for a glyph in font units.
pub fn Metrics::lsb(self : Metrics, gid : GlyphId) -> Int? {
  match self.glyph_index(gid) {
    None => None
    Some(idx) =>
      if idx < self.num_hmetrics {
        metrics_read_i16_be(self.hmtx, idx * 4 + 2)
      } else {
        let extra = idx - self.num_hmetrics
        metrics_read_i16_be(self.hmtx, self.num_hmetrics * 4 + extra * 2)
      }
  }
}

///|
pub fn FontRef::metrics(self : FontRef) -> Metrics? {
  Metrics::new(self)
}

///|
pub struct Decoration {
  offset : Double
  thickness : Double
}

///|
pub fn Decoration::offset(self : Decoration) -> Double {
  self.offset
}

///|
pub fn Decoration::thickness(self : Decoration) -> Double {
  self.thickness
}

///|
pub struct FontMetrics {
  units_per_em : UInt16
  is_monospace : Bool
  italic_angle : Double
  ascent : Double
  descent : Double
  leading : Double
  underline : Decoration?
}

///|
pub fn FontMetrics::units_per_em(self : FontMetrics) -> UInt16 {
  self.units_per_em
}

///|
pub fn FontMetrics::is_monospace(self : FontMetrics) -> Bool {
  self.is_monospace
}

///|
pub fn FontMetrics::italic_angle(self : FontMetrics) -> Double {
  self.italic_angle
}

///|
pub fn FontMetrics::ascent(self : FontMetrics) -> Double {
  self.ascent
}

///|
pub fn FontMetrics::descent(self : FontMetrics) -> Double {
  self.descent
}

///|
pub fn FontMetrics::leading(self : FontMetrics) -> Double {
  self.leading
}

///|
pub fn FontMetrics::underline(self : FontMetrics) -> Decoration? {
  self.underline
}

///|
pub fn FontMetrics::new(font : FontRef, size : Size) -> FontMetrics {
  let mut units_per_em : UInt16 = 0
  match font.table(METRICS_TAG_HEAD) {
    None => ()
    Some(head) => {
      let upem = metrics_read_u16_be(head, 18).unwrap_or(0)
      units_per_em = upem.to_uint16()
    }
  }
  let scale = size.linear_scale(units_per_em)
  let mut is_monospace = false
  let mut italic_angle = 0.0
  let mut underline : Decoration? = None
  match font.table(METRICS_TAG_POST) {
    None => ()
    Some(post) => {
      let fixed_pitch = match metrics_read_u32_be(post, 12) {
        None => 0
        Some(v) => v.reinterpret_as_int()
      }
      is_monospace = fixed_pitch != 0
      italic_angle = metrics_read_i32_be(post, 4).unwrap_or(0).to_double() /
        65536.0
      let ul_pos = metrics_read_i16_be(post, 8).unwrap_or(0).to_double() * scale
      let ul_thick = metrics_read_i16_be(post, 10).unwrap_or(0).to_double() *
        scale
      underline = Some(Decoration::{ offset: ul_pos, thickness: ul_thick })
    }
  }
  let mut ascent = 0.0
  let mut descent = 0.0
  let mut leading = 0.0
  let os2 = font.table(METRICS_TAG_OS2)
  let mut used_typo_metrics = false
  match os2 {
    None => ()
    Some(os2_tbl) => {
      // fsSelection at offset 62, USE_TYPO_METRICS = 0x0080.
      let fs_selection = metrics_read_u16_be(os2_tbl, 62).unwrap_or(0)
      if (fs_selection & 0x0080) != 0 {
        ascent = metrics_read_i16_be(os2_tbl, 68).unwrap_or(0).to_double() *
          scale
        descent = metrics_read_i16_be(os2_tbl, 70).unwrap_or(0).to_double() *
          scale
        leading = metrics_read_i16_be(os2_tbl, 72).unwrap_or(0).to_double() *
          scale
        used_typo_metrics = true
      }
    }
  }
  if !used_typo_metrics {
    match font.table(TAG_HHEA) {
      None => ()
      Some(hhea) => {
        ascent = metrics_read_i16_be(hhea, 4).unwrap_or(0).to_double() * scale
        descent = metrics_read_i16_be(hhea, 6).unwrap_or(0).to_double() * scale
        leading = metrics_read_i16_be(hhea, 8).unwrap_or(0).to_double() * scale
      }
    }
    if ascent == 0.0 && descent == 0.0 {
      match os2 {
        None => ()
        Some(os2_tbl) => {
          let typo_a = metrics_read_i16_be(os2_tbl, 68).unwrap_or(0)
          let typo_d = metrics_read_i16_be(os2_tbl, 70).unwrap_or(0)
          if typo_a != 0 || typo_d != 0 {
            ascent = typo_a.to_double() * scale
            descent = typo_d.to_double() * scale
            leading = metrics_read_i16_be(os2_tbl, 72).unwrap_or(0).to_double() *
              scale
          } else {
            let win_a = metrics_read_u16_be(os2_tbl, 74)
              .unwrap_or(0)
              .to_double() *
              scale
            let win_d = metrics_read_u16_be(os2_tbl, 76)
              .unwrap_or(0)
              .to_double() *
              scale
            ascent = win_a
            descent = -win_d
          }
        }
      }
    }
  }
  FontMetrics::{
    units_per_em,
    is_monospace,
    italic_angle,
    ascent,
    descent,
    leading,
    underline,
  }
}

///|
pub fn FontRef::font_metrics(self : FontRef, size : Size) -> FontMetrics {
  FontMetrics::new(self, size)
}

///|
/// Glyph specific metrics for a particular size and variation location.
///
/// This is a partial port of `skrifa::metrics::GlyphMetrics`. Currently supports:
/// - advance width + left side bearing from `hmtx`
/// - optional metric deltas from `HVAR` + `ItemVariationStore`
pub struct GlyphMetrics {
  priv base : Metrics
  priv scale : Double
  priv coords : ArrayView[NormalizedCoord]
  priv hvar : BytesView?
  priv hvar_store_off : Int
  priv hvar_aw_map_off : Int?
  priv hvar_lsb_map_off : Int?
}

///|
pub fn GlyphMetrics::new(
  font : FontRef,
  size : Size,
  location : LocationRef,
) -> GlyphMetrics? {
  let base = match Metrics::new(font) {
    None => return None
    Some(m) => m
  }
  let mut upem : UInt16 = 0
  match font.table(METRICS_TAG_HEAD) {
    None => ()
    Some(head) => {
      let v = metrics_read_u16_be(head, 18).unwrap_or(0)
      upem = v.to_uint16()
    }
  }
  let scale = size.linear_scale(upem)
  let coords = location.effective_coords()
  let mut hvar : BytesView? = None
  let mut store_off = -1
  let mut aw_map_off : Int? = None
  let mut lsb_map_off : Int? = None
  match font.table(METRICS_TAG_HVAR) {
    None => ()
    Some(tbl) =>
      // HVAR header is 20 bytes.
      if tbl.length() >= 20 {
        let so = metrics_read_u32_be_int(tbl, 4).unwrap_or(-1)
        let awo = metrics_read_u32_be_int(tbl, 8).unwrap_or(0)
        let lsbo = metrics_read_u32_be_int(tbl, 12).unwrap_or(0)
        if so > 0 && so < tbl.length() {
          hvar = Some(tbl)
          store_off = so
          if awo > 0 && awo < tbl.length() {
            aw_map_off = Some(awo)
          }
          if lsbo > 0 && lsbo < tbl.length() {
            lsb_map_off = Some(lsbo)
          }
        }
      }
  }
  Some(GlyphMetrics::{
    base,
    scale,
    coords,
    hvar,
    hvar_store_off: store_off,
    hvar_aw_map_off: aw_map_off,
    hvar_lsb_map_off: lsb_map_off,
  })
}

///|
pub fn GlyphMetrics::glyph_count(self : GlyphMetrics) -> Int {
  self.base.num_glyphs()
}

///|
fn metrics_hvar_entry_size(entry_format : Int) -> Int {
  ((entry_format & 0x30) >> 4) + 1
}

///|
fn metrics_hvar_bit_count(entry_format : Int) -> Int {
  (entry_format & 0x0F) + 1
}

///|
fn metrics_hvar_delta_set_index_map_get(
  hvar : BytesView,
  map_off : Int,
  index : Int,
) -> (Int, Int)? {
  let format = metrics_read_u8(hvar, map_off).unwrap_or(-1)
  if format != 0 && format != 1 {
    return None
  }
  let entry_format = metrics_read_u8(hvar, map_off + 1).unwrap_or(-1)
  if entry_format < 0 {
    return None
  }
  let entry_size = metrics_hvar_entry_size(entry_format)
  let bit_count = metrics_hvar_bit_count(entry_format)
  if entry_size < 1 || entry_size > 4 || bit_count < 1 || bit_count > 16 {
    return None
  }
  let mut map_count = -1
  let mut data_off = -1
  if format == 0 {
    map_count = metrics_read_u16_be(hvar, map_off + 2).unwrap_or(-1)
    data_off = map_off + 4
  } else {
    map_count = metrics_read_u32_be_int(hvar, map_off + 2).unwrap_or(-1)
    data_off = map_off + 6
  }
  if map_count <= 0 {
    return None
  }
  let idx = if index < map_count { index } else { map_count - 1 }
  let entry_off = data_off + idx * entry_size
  let entry : Int? = match entry_size {
    1 => metrics_read_u8(hvar, entry_off)
    2 => metrics_read_u16_be(hvar, entry_off)
    3 => metrics_read_u24_be(hvar, entry_off)
    _ => metrics_read_u32_be_int(hvar, entry_off)
  }
  match entry {
    None => None
    Some(e) => {
      let outer = (e >> bit_count) & 0xFFFF
      let inner_mask = (1 << bit_count) - 1
      let inner = e & inner_mask
      Some((outer, inner))
    }
  }
}

///|
fn metrics_hvar_region_scalar(
  store : BytesView,
  region_list_off : Int,
  region_index : Int,
  coords : ArrayView[NormalizedCoord],
) -> Double {
  let axis_count = metrics_read_u16_be(store, region_list_off).unwrap_or(-1)
  let region_count = metrics_read_u16_be(store, region_list_off + 2).unwrap_or(
    -1,
  )
  if axis_count <= 0 || region_count <= 0 {
    return 0.0
  }
  if region_index < 0 || region_index >= region_count {
    return 0.0
  }
  let region_rec_len = axis_count * 6
  let region_off = region_list_off + 4 + region_index * region_rec_len
  let mut scalar = 1.0
  for i in 0..<axis_count {
    let ax = region_off + i * 6
    let start = metrics_read_i16_be(store, ax).unwrap_or(0).to_double() /
      METRICS_F2DOT14_SCALE
    let peak = metrics_read_i16_be(store, ax + 2).unwrap_or(0).to_double() /
      METRICS_F2DOT14_SCALE
    let end = metrics_read_i16_be(store, ax + 4).unwrap_or(0).to_double() /
      METRICS_F2DOT14_SCALE
    if peak == 0.0 {
      continue
    }
    if start > peak || peak > end || (start < 0.0 && end > 0.0) {
      continue
    }
    let coord = if i < coords.length() {
      coords.at(i).to_double() / METRICS_F2DOT14_SCALE
    } else {
      0.0
    }
    if coord < start || coord > end {
      return 0.0
    }
    if coord == peak {
      continue
    }
    if coord < peak {
      scalar = scalar * (coord - start) / (peak - start)
    } else {
      scalar = scalar * (end - coord) / (end - peak)
    }
  }
  scalar
}

///|
fn metrics_hvar_item_variation_store_delta(
  store : BytesView,
  store_off : Int,
  outer : Int,
  inner : Int,
  coords : ArrayView[NormalizedCoord],
) -> Int {
  if coords.is_empty() {
    return 0
  }
  // ItemVariationStore header:
  // u16 format, u32 regionListOff, u16 dataCount, u32[dataCount] dataOffsets
  let region_list_rel = metrics_read_u32_be_int(store, store_off + 2).unwrap_or(
    -1,
  )
  let data_count = metrics_read_u16_be(store, store_off + 6).unwrap_or(-1)
  if region_list_rel <= 0 || data_count <= 0 {
    return 0
  }
  if outer < 0 || outer >= data_count {
    return 0
  }
  let offsets_off = store_off + 8
  let data_rel = metrics_read_u32_be_int(store, offsets_off + outer * 4).unwrap_or(
    0,
  )
  if data_rel <= 0 {
    return 0
  }
  let data_off = store_off + data_rel
  // ItemVariationData header:
  // u16 itemCount, u16 shortDeltaCount, u16 regionIndexCount, u16[regionIndexCount] regionIndexes, deltaSets...
  let item_count = metrics_read_u16_be(store, data_off).unwrap_or(-1)
  let short_count = metrics_read_u16_be(store, data_off + 2).unwrap_or(-1)
  let region_index_count = metrics_read_u16_be(store, data_off + 4).unwrap_or(
    -1,
  )
  if item_count <= 0 || region_index_count <= 0 {
    return 0
  }
  if inner < 0 || inner >= item_count {
    return 0
  }
  let region_indexes_off = data_off + 6
  let deltas_off = region_indexes_off + region_index_count * 2
  let short = if short_count < 0 { 0 } else { short_count }
  let row_size = short * 2 + (region_index_count - short)
  if row_size <= 0 {
    return 0
  }
  let row_off = deltas_off + inner * row_size
  let region_list_off = store_off + region_list_rel
  let mut accum = 0.0
  for i in 0..<region_index_count {
    let region_index = metrics_read_u16_be(store, region_indexes_off + i * 2).unwrap_or(
      -1,
    )
    let scalar = metrics_hvar_region_scalar(
      store, region_list_off, region_index, coords,
    )
    if scalar == 0.0 {
      continue
    }
    let delta = if i < short {
      metrics_read_i16_be(store, row_off + i * 2).unwrap_or(0)
    } else {
      let pos = row_off + short * 2 + (i - short)
      metrics_read_i8(store, pos).unwrap_or(0)
    }
    accum = accum + delta.to_double() * scalar
  }
  accum.round().to_int()
}

///|
fn metrics_hvar_delta(
  hvar : BytesView,
  store_off : Int,
  map_off : Int?,
  gid : GlyphId,
  coords : ArrayView[NormalizedCoord],
) -> Int {
  match map_off {
    None => 0
    Some(off) =>
      match
        metrics_hvar_delta_set_index_map_get(
          hvar,
          off,
          gid.to_uint64().to_int(),
        ) {
        None => 0
        Some((outer, inner)) =>
          metrics_hvar_item_variation_store_delta(
            hvar, store_off, outer, inner, coords,
          )
      }
  }
}

///|
pub fn GlyphMetrics::advance_width(
  self : GlyphMetrics,
  gid : GlyphId,
) -> Double? {
  match self.base.advance_width(gid) {
    None => None
    Some(aw_u) => {
      let mut aw = aw_u.to_uint64().to_int()
      if self.hvar is Some(hvar) && !self.coords.is_empty() {
        aw = aw +
          metrics_hvar_delta(
            hvar,
            self.hvar_store_off,
            self.hvar_aw_map_off,
            gid,
            self.coords,
          )
      }
      Some(aw.to_double() * self.scale)
    }
  }
}

///|
pub fn GlyphMetrics::left_side_bearing(
  self : GlyphMetrics,
  gid : GlyphId,
) -> Double? {
  match self.base.lsb(gid) {
    None => None
    Some(lsb0) => {
      let mut lsb = lsb0
      if self.hvar is Some(hvar) && !self.coords.is_empty() {
        lsb = lsb +
          metrics_hvar_delta(
            hvar,
            self.hvar_store_off,
            self.hvar_lsb_map_off,
            gid,
            self.coords,
          )
      }
      Some(lsb.to_double() * self.scale)
    }
  }
}

///|
pub fn FontRef::glyph_metrics(
  self : FontRef,
  size : Size,
  location : LocationRef,
) -> GlyphMetrics? {
  GlyphMetrics::new(self, size, location)
}
