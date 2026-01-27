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
const METRICS_TAG_GVAR : UInt = 0x67564152 // "gvar"

///|
const METRICS_TAG_GLYF : UInt = 0x676C7966 // "glyf"

///|
const METRICS_TAG_LOCA : UInt = 0x6C6F6361 // "loca"

///|
const METRICS_F2DOT14_SCALE : Double = 16384.0

///|
const METRICS_COMPOSITE_ARG_1_AND_2_ARE_WORDS : Int = 0x0001

///|
const METRICS_COMPOSITE_MORE_COMPONENTS : Int = 0x0020

///|
const METRICS_COMPOSITE_WE_HAVE_A_SCALE : Int = 0x0008

///|
const METRICS_COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE : Int = 0x0040

///|
const METRICS_COMPOSITE_WE_HAVE_A_TWO_BY_TWO : Int = 0x0080

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
pub struct HmtxMetrics {
  priv num_glyphs : Int
  priv num_hmetrics : Int
  priv hmtx : BytesView
}

///|
/// Parses required tables (maxp/hhea/hmtx) from the font.
pub fn HmtxMetrics::new(font : FontRef) -> HmtxMetrics? {
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
  Some(HmtxMetrics::{ num_glyphs, num_hmetrics, hmtx })
}

///|
pub fn HmtxMetrics::num_glyphs(self : HmtxMetrics) -> Int {
  self.num_glyphs
}

///|
pub fn HmtxMetrics::number_of_hmetrics(self : HmtxMetrics) -> Int {
  self.num_hmetrics
}

///|
fn HmtxMetrics::glyph_index(self : HmtxMetrics, gid : GlyphId) -> Int? {
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= self.num_glyphs {
    None
  } else {
    Some(idx)
  }
}

///|
/// Returns advance width for a glyph in font units.
pub fn HmtxMetrics::advance_width(self : HmtxMetrics, gid : GlyphId) -> UInt? {
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
pub fn HmtxMetrics::lsb(self : HmtxMetrics, gid : GlyphId) -> Int? {
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
pub fn FontRef::hmtx_metrics(self : FontRef) -> HmtxMetrics? {
  HmtxMetrics::new(self)
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
pub struct Metrics {
  units_per_em : UInt16
  glyph_count : UInt16
  is_monospace : Bool
  italic_angle : Double
  ascent : Double
  descent : Double
  leading : Double
  cap_height : Double?
  x_height : Double?
  average_width : Double?
  max_width : Double?
  underline : Decoration?
  strikeout : Decoration?
  bounds : GlyphBounds?
}

///|
pub fn Metrics::units_per_em(self : Metrics) -> UInt16 {
  self.units_per_em
}

///|
pub fn Metrics::glyph_count(self : Metrics) -> UInt16 {
  self.glyph_count
}

///|
pub fn Metrics::is_monospace(self : Metrics) -> Bool {
  self.is_monospace
}

///|
pub fn Metrics::italic_angle(self : Metrics) -> Double {
  self.italic_angle
}

///|
pub fn Metrics::ascent(self : Metrics) -> Double {
  self.ascent
}

///|
pub fn Metrics::descent(self : Metrics) -> Double {
  self.descent
}

///|
pub fn Metrics::leading(self : Metrics) -> Double {
  self.leading
}

///|
pub fn Metrics::cap_height(self : Metrics) -> Double? {
  self.cap_height
}

///|
pub fn Metrics::x_height(self : Metrics) -> Double? {
  self.x_height
}

///|
pub fn Metrics::average_width(self : Metrics) -> Double? {
  self.average_width
}

///|
pub fn Metrics::max_width(self : Metrics) -> Double? {
  self.max_width
}

///|
pub fn Metrics::underline(self : Metrics) -> Decoration? {
  self.underline
}

///|
pub fn Metrics::strikeout(self : Metrics) -> Decoration? {
  self.strikeout
}

///|
pub fn Metrics::bounds(self : Metrics) -> GlyphBounds? {
  self.bounds
}

///|
pub fn Metrics::new(
  font : FontRef,
  size : Size,
  _location : LocationRef,
) -> Metrics {
  let mut units_per_em : UInt16 = 0
  let mut bounds : GlyphBounds? = None
  match font.table(METRICS_TAG_HEAD) {
    None => ()
    Some(head) => {
      let upem = metrics_read_u16_be(head, 18).unwrap_or(0)
      units_per_em = upem.to_uint16()
      // head bbox: xMin/yMin/xMax/yMax at offsets 36..44.
      if head.length() >= 44 {
        let scale = size.linear_scale(units_per_em)
        let x_min = metrics_read_i16_be(head, 36).unwrap_or(0).to_double() *
          scale
        let y_min = metrics_read_i16_be(head, 38).unwrap_or(0).to_double() *
          scale
        let x_max = metrics_read_i16_be(head, 40).unwrap_or(0).to_double() *
          scale
        let y_max = metrics_read_i16_be(head, 42).unwrap_or(0).to_double() *
          scale
        bounds = Some(GlyphBounds::{ x_min, y_min, x_max, y_max })
      }
    }
  }
  let scale = size.linear_scale(units_per_em)
  let mut glyph_count : UInt16 = 0
  match font.table(TAG_MAXP) {
    None => ()
    Some(maxp) => {
      let n = metrics_read_u16_be(maxp, 4).unwrap_or(0)
      glyph_count = n.to_uint16()
    }
  }
  let mut max_width : Double? = None
  match font.table(TAG_HHEA) {
    None => ()
    Some(hhea) => {
      // advanceWidthMax at offset 10 (u16).
      let aw = metrics_read_u16_be(hhea, 10).unwrap_or(-1)
      if aw >= 0 {
        max_width = Some(aw.to_double() * scale)
      }
    }
  }
  let mut is_monospace = false
  let mut italic_angle = 0.0
  let mut underline : Decoration? = None
  let mut strikeout : Decoration? = None
  let mut cap_height : Double? = None
  let mut x_height : Double? = None
  let mut average_width : Double? = None
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
      // xAvgCharWidth at offset 2 (i16).
      let x_avg = metrics_read_i16_be(os2_tbl, 2).unwrap_or(0).to_double() *
        scale
      average_width = Some(x_avg)
      // Strikeout position/size at offsets 28/30 (i16).
      let so_pos = metrics_read_i16_be(os2_tbl, 28).unwrap_or(0).to_double() *
        scale
      let so_size = metrics_read_i16_be(os2_tbl, 30).unwrap_or(0).to_double() *
        scale
      strikeout = Some(Decoration::{ offset: so_pos, thickness: so_size })
      // sxHeight and sCapHeight are present in OS/2 v2+ (offsets 86/88).
      if os2_tbl.length() >= 90 {
        let xh = metrics_read_i16_be(os2_tbl, 86).unwrap_or(0)
        let ch = metrics_read_i16_be(os2_tbl, 88).unwrap_or(0)
        x_height = Some(xh.to_double() * scale)
        cap_height = Some(ch.to_double() * scale)
      }
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
  Metrics::{
    units_per_em,
    glyph_count,
    is_monospace,
    italic_angle,
    ascent,
    descent,
    leading,
    cap_height,
    x_height,
    average_width,
    max_width,
    underline,
    strikeout,
    bounds,
  }
}

///|
pub fn FontRef::metrics(
  self : FontRef,
  size : Size,
  location : LocationRef,
) -> Metrics {
  Metrics::new(self, size, location)
}

///|
pub fn FontRef::font_metrics(self : FontRef, size : Size) -> Metrics {
  Metrics::new(self, size, LocationRef::default())
}

///|
pub fn FontRef::font_metrics_at(
  self : FontRef,
  size : Size,
  location : LocationRef,
) -> Metrics {
  Metrics::new(self, size, location)
}

///|
/// Glyph specific metrics for a particular size and variation location.
///
/// This is a partial port of `skrifa::metrics::GlyphMetrics`. Currently supports:
/// - advance width + left side bearing from `hmtx`
/// - optional metric deltas from `HVAR` + `ItemVariationStore`
pub struct GlyphMetrics {
  priv font : FontRef
  priv glyph_count : Int
  priv base : HmtxMetrics?
  priv scale : Double
  priv coords : ArrayView[NormalizedCoord]
  priv hvar : BytesView?
  priv hvar_store_off : Int
  priv hvar_aw_map_off : Int?
  priv hvar_lsb_map_off : Int?
  priv gvar : BytesView?
  priv gvar_axis_count : Int
  priv gvar_shared_tuple_count : Int
  priv gvar_shared_tuples_off : Int
  priv gvar_glyph_count : Int
  priv gvar_flags : Int
  priv gvar_data_array_off : Int
}

///|
pub struct GlyphBounds {
  priv x_min : Double
  priv y_min : Double
  priv x_max : Double
  priv y_max : Double
}

///|
pub fn GlyphBounds::x_min(self : GlyphBounds) -> Double {
  self.x_min
}

///|
pub fn GlyphBounds::y_min(self : GlyphBounds) -> Double {
  self.y_min
}

///|
pub fn GlyphBounds::x_max(self : GlyphBounds) -> Double {
  self.x_max
}

///|
pub fn GlyphBounds::y_max(self : GlyphBounds) -> Double {
  self.y_max
}

///|
pub fn GlyphMetrics::new(
  font : FontRef,
  size : Size,
  location : LocationRef,
) -> GlyphMetrics {
  let mut glyph_count = 0
  match font.table(TAG_MAXP) {
    None => ()
    Some(maxp) => glyph_count = metrics_read_u16_be(maxp, 4).unwrap_or(0)
  }
  let base = HmtxMetrics::new(font)
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
  let mut gvar : BytesView? = None
  let mut gvar_axis_count = -1
  let mut gvar_shared_tuple_count = -1
  let mut gvar_shared_tuples_off = -1
  let mut gvar_glyph_count = -1
  let mut gvar_flags = -1
  let mut gvar_data_array_off = -1
  match font.table(METRICS_TAG_GVAR) {
    None => ()
    Some(tbl) =>
      // gvar header is 20 bytes.
      if tbl.length() >= 20 {
        let axis_count = metrics_read_u16_be(tbl, 4).unwrap_or(-1)
        let shared_tuple_count = metrics_read_u16_be(tbl, 6).unwrap_or(-1)
        let shared_tuples_off = metrics_read_u32_be_int(tbl, 8).unwrap_or(-1)
        let glyph_count = metrics_read_u16_be(tbl, 12).unwrap_or(-1)
        let flags = metrics_read_u16_be(tbl, 14).unwrap_or(-1)
        let data_array_off = metrics_read_u32_be_int(tbl, 16).unwrap_or(-1)
        if axis_count >= 0 &&
          shared_tuple_count >= 0 &&
          glyph_count >= 0 &&
          flags >= 0 &&
          data_array_off >= 0 &&
          data_array_off <= tbl.length() {
          gvar = Some(tbl)
          gvar_axis_count = axis_count
          gvar_shared_tuple_count = shared_tuple_count
          gvar_shared_tuples_off = shared_tuples_off
          gvar_glyph_count = glyph_count
          gvar_flags = flags
          gvar_data_array_off = data_array_off
        }
      }
  }
  GlyphMetrics::{
    font,
    glyph_count,
    base,
    scale,
    coords,
    hvar,
    hvar_store_off: store_off,
    hvar_aw_map_off: aw_map_off,
    hvar_lsb_map_off: lsb_map_off,
    gvar,
    gvar_axis_count,
    gvar_shared_tuple_count,
    gvar_shared_tuples_off,
    gvar_glyph_count,
    gvar_flags,
    gvar_data_array_off,
  }
}

///|
pub fn GlyphMetrics::glyph_count(self : GlyphMetrics) -> Int {
  self.glyph_count
}

///|
fn metrics_glyf_simple_bounds(
  glyf : BytesView,
  start : Int,
  end : Int,
) -> (Int, Int, Int, Int)? {
  if start < 0 || end < start || end > glyf.length() || start + 10 > end {
    return None
  }
  let contours = metrics_read_i16_be(glyf, start).unwrap_or(-32768)
  if contours <= 0 {
    return None
  }
  let end_pts_off = start + 10
  let need_end_pts = end_pts_off + contours * 2
  if need_end_pts < end_pts_off || need_end_pts > end {
    return None
  }
  let last = metrics_read_u16_be(glyf, end_pts_off + (contours - 1) * 2).unwrap_or(
    -1,
  )
  if last < 0 {
    return None
  }
  let num_points = last + 1
  let instr_len_off = end_pts_off + contours * 2
  let instr_len = metrics_read_u16_be(glyf, instr_len_off).unwrap_or(-1)
  if instr_len < 0 {
    return None
  }
  let mut pos = instr_len_off + 2 + instr_len
  if pos < instr_len_off || pos > end {
    return None
  }
  // Flags
  let flags : Array[Int] = Array::make(num_points, 0)
  let mut i = 0
  while i < num_points {
    let f = metrics_read_u8(glyf, pos).unwrap_or(-1)
    if f < 0 {
      return None
    }
    pos = pos + 1
    flags.set(i, f)
    i = i + 1
    if (f & 0x08) != 0 {
      let rep = metrics_read_u8(glyf, pos).unwrap_or(-1)
      if rep < 0 {
        return None
      }
      pos = pos + 1
      for _ in 0..<rep {
        if i >= num_points {
          break
        }
        flags.set(i, f)
        i = i + 1
      }
    }
  }
  // Decode X coordinates.
  let xs : Array[Int] = Array::make(num_points, 0)
  let mut x = 0
  for j in 0..<num_points {
    let f = flags.at(j)
    let dx = if (f & 0x02) != 0 {
      let v = metrics_read_u8(glyf, pos).unwrap_or(-1)
      if v < 0 {
        return None
      }
      pos = pos + 1
      if (f & 0x10) != 0 {
        v
      } else {
        -v
      }
    } else if (f & 0x10) != 0 {
      0
    } else {
      let v = metrics_read_i16_be(glyf, pos).unwrap_or(0)
      pos = pos + 2
      v
    }
    x = x + dx
    xs.set(j, x)
  }
  // Decode Y coordinates and compute bounds.
  let mut y = 0
  let mut x_min = 0
  let mut y_min = 0
  let mut x_max = 0
  let mut y_max = 0
  for j in 0..<num_points {
    let f = flags.at(j)
    let dy = if (f & 0x04) != 0 {
      let v = metrics_read_u8(glyf, pos).unwrap_or(-1)
      if v < 0 {
        return None
      }
      pos = pos + 1
      if (f & 0x20) != 0 {
        v
      } else {
        -v
      }
    } else if (f & 0x20) != 0 {
      0
    } else {
      let v = metrics_read_i16_be(glyf, pos).unwrap_or(0)
      pos = pos + 2
      v
    }
    y = y + dy
    let px = xs.at(j)
    if j == 0 {
      x_min = px
      x_max = px
      y_min = y
      y_max = y
    } else {
      if px < x_min {
        x_min = px
      }
      if px > x_max {
        x_max = px
      }
      if y < y_min {
        y_min = y
      }
      if y > y_max {
        y_max = y
      }
    }
  }
  Some((x_min, y_min, x_max, y_max))
}

///|
/// Returns scaled bounds for a glyf glyph (if present).
pub fn GlyphMetrics::bounds(self : GlyphMetrics, gid : GlyphId) -> GlyphBounds? {
  let idx = gid.to_uint64().to_int()
  let (glyf, start, end) = match
    metrics_glyf_glyph_range(self.font, self.glyph_count, idx) {
    None => return None
    Some(v) => v
  }
  if start == end {
    return None
  }
  let (x_min, y_min, x_max, y_max) = match
    metrics_glyf_simple_bounds(glyf, start, end) {
    Some(v) => v
    None => {
      // Fallback to the bbox fields in the glyph header.
      if start + 10 > end {
        return None
      }
      (
        metrics_read_i16_be(glyf, start + 2).unwrap_or(0),
        metrics_read_i16_be(glyf, start + 4).unwrap_or(0),
        metrics_read_i16_be(glyf, start + 6).unwrap_or(0),
        metrics_read_i16_be(glyf, start + 8).unwrap_or(0),
      )
    }
  }
  Some(GlyphBounds::{
    x_min: x_min.to_double() * self.scale,
    y_min: y_min.to_double() * self.scale,
    x_max: x_max.to_double() * self.scale,
    y_max: y_max.to_double() * self.scale,
  })
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
fn metrics_glyf_glyph_range(
  font : FontRef,
  num_glyphs : Int,
  gid : Int,
) -> (BytesView, Int, Int)? {
  if gid < 0 || gid >= num_glyphs {
    return None
  }
  let head = match font.table(METRICS_TAG_HEAD) {
    None => return None
    Some(v) => v
  }
  let loca = match font.table(METRICS_TAG_LOCA) {
    None => return None
    Some(v) => v
  }
  let glyf = match font.table(METRICS_TAG_GLYF) {
    None => return None
    Some(v) => v
  }
  let loca_format = metrics_read_i16_be(head, 50).unwrap_or(-1)
  let idx = gid
  if loca_format == 0 {
    let need = (num_glyphs + 1) * 2
    if need < 0 || loca.length() < need {
      return None
    }
    let o0 = metrics_read_u16_be(loca, idx * 2).unwrap_or(-1)
    let o1 = metrics_read_u16_be(loca, (idx + 1) * 2).unwrap_or(-1)
    if o0 < 0 || o1 < o0 {
      return None
    }
    let start = o0 * 2
    let end = o1 * 2
    if start < 0 || end < start || end > glyf.length() {
      None
    } else {
      Some((glyf, start, end))
    }
  } else if loca_format == 1 {
    let need = (num_glyphs + 1) * 4
    if need < 0 || loca.length() < need {
      return None
    }
    let o0 = metrics_read_u32_be_int(loca, idx * 4).unwrap_or(-1)
    let o1 = metrics_read_u32_be_int(loca, (idx + 1) * 4).unwrap_or(-1)
    if o0 < 0 || o1 < o0 {
      return None
    }
    if o0 < 0 || o1 < 0 || o1 > glyf.length() {
      None
    } else {
      Some((glyf, o0, o1))
    }
  } else {
    None
  }
}

///|
fn metrics_glyf_point_count_idx(
  font : FontRef,
  num_glyphs : Int,
  gid : Int,
  visited : Array[Bool],
) -> Int? {
  if gid < 0 || gid >= num_glyphs {
    return None
  }
  if visited.at(gid) {
    return None
  }
  visited.set(gid, true)
  let (glyf, start, end) = match
    metrics_glyf_glyph_range(font, num_glyphs, gid) {
    None => return None
    Some(v) => v
  }
  if start == end {
    return Some(0)
  }
  if start + 10 > end {
    return None
  }
  let contours = metrics_read_i16_be(glyf, start).unwrap_or(-32768)
  if contours >= 0 {
    if contours == 0 {
      return Some(0)
    }
    let n = contours
    let end_pts_off = start + 10
    let last = metrics_read_u16_be(glyf, end_pts_off + (n - 1) * 2).unwrap_or(
      -1,
    )
    if last < 0 {
      None
    } else {
      Some(last + 1)
    }
  } else {
    // Composite glyph: sum component point counts.
    let mut pos = start + 10
    let mut total = 0
    while true {
      if pos + 4 > end {
        return None
      }
      let flags = metrics_read_u16_be(glyf, pos).unwrap_or(-1)
      let comp_gid = metrics_read_u16_be(glyf, pos + 2).unwrap_or(-1)
      if flags < 0 || comp_gid < 0 {
        return None
      }
      pos = pos + 4
      let arg_words = (flags & METRICS_COMPOSITE_ARG_1_AND_2_ARE_WORDS) != 0
      pos = pos + (if arg_words { 4 } else { 2 })
      if (flags & METRICS_COMPOSITE_WE_HAVE_A_SCALE) != 0 {
        pos = pos + 2
      } else if (flags & METRICS_COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
        pos = pos + 4
      } else if (flags & METRICS_COMPOSITE_WE_HAVE_A_TWO_BY_TWO) != 0 {
        pos = pos + 8
      }
      let pc = match
        metrics_glyf_point_count_idx(font, num_glyphs, comp_gid, visited) {
        None => return None
        Some(v) => v
      }
      total = total + pc
      if (flags & METRICS_COMPOSITE_MORE_COMPONENTS) == 0 {
        break
      }
    }
    Some(total)
  }
}

///|
fn metrics_glyf_point_count(
  font : FontRef,
  num_glyphs : Int,
  gid : GlyphId,
) -> Int? {
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= num_glyphs {
    return None
  }
  let visited : Array[Bool] = Array::make(num_glyphs, false)
  metrics_glyf_point_count_idx(font, num_glyphs, idx, visited)
}

///|
fn metrics_gvar_points(
  gvar : BytesView,
  offset : Int,
  total_points : Int,
) -> (Array[Int]?, Int)? {
  let b0 = metrics_read_u8(gvar, offset).unwrap_or(-1)
  if b0 < 0 {
    return None
  }
  let mut count = 0
  let mut off = offset
  if (b0 & 0x80) == 0 {
    count = b0
    off = off + 1
  } else {
    let b1 = metrics_read_u8(gvar, offset + 1).unwrap_or(-1)
    if b1 < 0 {
      return None
    }
    count = ((b0 & 0x7F) << 8) | b1
    off = off + 2
  }
  if count == 0 {
    return Some((None, off))
  }
  let points : Array[Int] = Array::new()
  let mut last = 0
  while points.length() < count {
    let ctrl = metrics_read_u8(gvar, off).unwrap_or(-1)
    if ctrl < 0 {
      return None
    }
    off = off + 1
    let run_len = (ctrl & 0x7F) + 1
    let words = (ctrl & 0x80) != 0
    for _ in 0..<run_len {
      if points.length() >= count {
        break
      }
      let delta = if words {
        metrics_read_u16_be(gvar, off).unwrap_or(-1)
      } else {
        metrics_read_u8(gvar, off).unwrap_or(-1)
      }
      if delta < 0 {
        return None
      }
      off = off + (if words { 2 } else { 1 })
      last = last + delta
      if last < 0 || last >= total_points {
        return None
      }
      points.push(last)
    }
  }
  Some((Some(points), off))
}

///|
fn metrics_gvar_deltas_capture(
  gvar : BytesView,
  offset : Int,
  count : Int,
  pos0 : Int,
  pos1 : Int,
) -> (Int, Int, Int)? {
  let mut off = offset
  let mut idx = 0
  let mut v0 = 0
  let mut v1 = 0
  while idx < count {
    let ctrl = metrics_read_u8(gvar, off).unwrap_or(-1)
    if ctrl < 0 {
      return None
    }
    off = off + 1
    let run_len = (ctrl & 0x3F) + 1
    if idx + run_len > count {
      return None
    }
    let words = (ctrl & 0x80) != 0
    let zeros = !words && (ctrl & 0x40) != 0
    if zeros {
      for _ in 0..<run_len {
        if idx == pos0 {
          v0 = 0
        }
        if idx == pos1 {
          v1 = 0
        }
        idx = idx + 1
      }
    } else if words {
      for _ in 0..<run_len {
        let v = metrics_read_i16_be(gvar, off).unwrap_or(0)
        off = off + 2
        if idx == pos0 {
          v0 = v
        }
        if idx == pos1 {
          v1 = v
        }
        idx = idx + 1
      }
    } else {
      for _ in 0..<run_len {
        let v = metrics_read_i8(gvar, off).unwrap_or(0)
        off = off + 1
        if idx == pos0 {
          v0 = v
        }
        if idx == pos1 {
          v1 = v
        }
        idx = idx + 1
      }
    }
  }
  Some((v0, v1, off))
}

///|
fn metrics_gvar_tuple_scalar(
  coords : ArrayView[NormalizedCoord],
  peak : Array[Int],
  start : Array[Int]?,
  end : Array[Int]?,
) -> Double {
  let axis_count = peak.length()
  let mut scalar = 1.0
  for i in 0..<axis_count {
    let peak_v = peak.at(i).to_double() / METRICS_F2DOT14_SCALE
    if peak_v == 0.0 {
      continue
    }
    let coord = if i < coords.length() {
      coords.at(i).to_double() / METRICS_F2DOT14_SCALE
    } else {
      0.0
    }
    let (start_v, end_v) = match (start, end) {
      (Some(s), Some(e)) =>
        (
          s.at(i).to_double() / METRICS_F2DOT14_SCALE,
          e.at(i).to_double() / METRICS_F2DOT14_SCALE,
        )
      _ => if peak_v > 0.0 { (0.0, 1.0) } else { (-1.0, 0.0) }
    }
    if start_v > peak_v || peak_v > end_v || (start_v < 0.0 && end_v > 0.0) {
      continue
    }
    if coord < start_v || coord > end_v {
      return 0.0
    }
    if coord == peak_v {
      continue
    }
    if coord < peak_v {
      scalar = scalar * (coord - start_v) / (peak_v - start_v)
    } else {
      scalar = scalar * (end_v - coord) / (end_v - peak_v)
    }
  }
  scalar
}

///|
fn GlyphMetrics::gvar_phantom_deltas(
  self : GlyphMetrics,
  gid : GlyphId,
) -> (Int, Int) {
  if self.gvar is None || self.coords.is_empty() {
    return (0, 0)
  }
  let gvar = self.gvar.unwrap()
  let gid_i = gid.to_uint64().to_int()
  if gid_i < 0 || gid_i >= self.gvar_glyph_count {
    return (0, 0)
  }
  let base_points = match
    metrics_glyf_point_count(self.font, self.glyph_count, gid) {
    None => return (0, 0)
    Some(v) => v
  }
  let total_points = base_points + 4
  if total_points <= 0 {
    return (0, 0)
  }
  let offsets_off = 20
  let long_offsets = (self.gvar_flags & 1) != 0
  let entry_size = if long_offsets { 4 } else { 2 }
  let need = offsets_off + (self.gvar_glyph_count + 1) * entry_size
  if need < 0 || need > gvar.length() {
    return (0, 0)
  }
  let off0 = if long_offsets {
    metrics_read_u32_be_int(gvar, offsets_off + gid_i * 4).unwrap_or(-1)
  } else {
    metrics_read_u16_be(gvar, offsets_off + gid_i * 2).unwrap_or(-1) * 2
  }
  let off1 = if long_offsets {
    metrics_read_u32_be_int(gvar, offsets_off + (gid_i + 1) * 4).unwrap_or(-1)
  } else {
    metrics_read_u16_be(gvar, offsets_off + (gid_i + 1) * 2).unwrap_or(-1) * 2
  }
  if off0 < 0 || off1 < off0 {
    return (0, 0)
  }
  let start = self.gvar_data_array_off + off0
  let end = self.gvar_data_array_off + off1
  if start < 0 || end < start || end > gvar.length() {
    return (0, 0)
  }
  if start == end {
    return (0, 0)
  }
  let tuple_count_flags = metrics_read_u16_be(gvar, start).unwrap_or(0)
  let tuple_count = tuple_count_flags & 0x0FFF
  let shared_points = (tuple_count_flags & 0x8000) != 0
  let data_rel = metrics_read_u16_be(gvar, start + 2).unwrap_or(-1)
  if tuple_count <= 0 || data_rel < 0 {
    return (0, 0)
  }
  let headers_off = start + 4
  let headers_end = headers_off + tuple_count * 4
  if headers_end < headers_off || headers_end > end {
    return (0, 0)
  }
  let sizes : Array[Int] = Array::new()
  let tuple_indexes : Array[Int] = Array::new()
  for i in 0..<tuple_count {
    let h = headers_off + i * 4
    let s = metrics_read_u16_be(gvar, h).unwrap_or(-1)
    let ti = metrics_read_u16_be(gvar, h + 2).unwrap_or(-1)
    if s < 0 || ti < 0 {
      return (0, 0)
    }
    sizes.push(s)
    tuple_indexes.push(ti)
  }
  // Tuple coordinate data (peak/start/end tuples) immediately follows the headers.
  let mut tuple_coords_off = headers_end
  let axis_count = self.gvar_axis_count
  if axis_count <= 0 {
    return (0, 0)
  }
  let scalars : Array[Double] = Array::new()
  for i in 0..<tuple_count {
    let ti = tuple_indexes.at(i)
    // Flags used by gvar tupleIndex.
    let embedded = (ti & 0x8000) != 0
    let intermediate = (ti & 0x4000) != 0
    let shared_ix = ti & 0x0FFF
    let peak : Array[Int] = Array::make(axis_count, 0)
    if embedded {
      let need = tuple_coords_off + axis_count * 2
      if need < tuple_coords_off || need > end {
        return (0, 0)
      }
      for ax in 0..<axis_count {
        peak.set(
          ax,
          metrics_read_i16_be(gvar, tuple_coords_off + ax * 2).unwrap_or(0),
        )
      }
      tuple_coords_off = tuple_coords_off + axis_count * 2
    } else {
      if shared_ix < 0 || shared_ix >= self.gvar_shared_tuple_count {
        return (0, 0)
      }
      let base = self.gvar_shared_tuples_off + shared_ix * axis_count * 2
      let need = base + axis_count * 2
      if base < 0 || need < base || need > gvar.length() {
        return (0, 0)
      }
      for ax in 0..<axis_count {
        peak.set(ax, metrics_read_i16_be(gvar, base + ax * 2).unwrap_or(0))
      }
    }
    let mut start_t : Array[Int]? = None
    let mut end_t : Array[Int]? = None
    if intermediate {
      let st : Array[Int] = Array::make(axis_count, 0)
      let et : Array[Int] = Array::make(axis_count, 0)
      let need = tuple_coords_off + axis_count * 4
      if need < tuple_coords_off || need > end {
        return (0, 0)
      }
      for ax in 0..<axis_count {
        st.set(
          ax,
          metrics_read_i16_be(gvar, tuple_coords_off + ax * 2).unwrap_or(0),
        )
        et.set(
          ax,
          metrics_read_i16_be(gvar, tuple_coords_off + axis_count * 2 + ax * 2).unwrap_or(
            0,
          ),
        )
      }
      tuple_coords_off = tuple_coords_off + axis_count * 4
      start_t = Some(st)
      end_t = Some(et)
    }
    let scalar = metrics_gvar_tuple_scalar(self.coords, peak, start_t, end_t)
    scalars.push(scalar)
  }
  let data_off = start + data_rel
  if data_off < start || data_off > end {
    return (0, 0)
  }
  let phantom0 = total_points - 4
  let phantom1 = total_points - 3
  let mut cursor = data_off
  let mut shared_points_list : Array[Int]? = None
  if shared_points {
    let (pts, off2) = match metrics_gvar_points(gvar, cursor, total_points) {
      None => return (0, 0)
      Some(v) => v
    }
    shared_points_list = pts
    cursor = off2
  }
  let mut accum0 = 0.0
  let mut accum1 = 0.0
  for i in 0..<tuple_count {
    let size = sizes.at(i)
    let ti = tuple_indexes.at(i)
    let tuple_end = cursor + size
    if size < 0 || tuple_end < cursor || tuple_end > end {
      return (0, 0)
    }
    let scalar = scalars.at(i)
    // tupleIndex flag: PRIVATE_POINT_NUMBERS = 0x2000.
    let private_points = (ti & 0x2000) != 0
    let mut points : Array[Int]? = None
    let mut after_points = cursor
    if private_points || !shared_points {
      let (pts, off2) = match metrics_gvar_points(gvar, cursor, total_points) {
        None => return (0, 0)
        Some(v) => v
      }
      points = pts
      after_points = off2
    } else {
      points = shared_points_list
      after_points = cursor
    }
    let count = match points {
      None => total_points
      Some(arr) => arr.length()
    }
    if count <= 0 {
      cursor = tuple_end
      continue
    }
    let mut pos0 = -1
    let mut pos1 = -1
    match points {
      None => {
        pos0 = phantom0
        pos1 = phantom1
      }
      Some(arr) =>
        for j in 0..<arr.length() {
          let p = arr.at(j)
          if p == phantom0 {
            pos0 = j
          } else if p == phantom1 {
            pos1 = j
          }
        }
    }
    let (dx0, dx1, after_x) = match
      metrics_gvar_deltas_capture(gvar, after_points, count, pos0, pos1) {
      None => return (0, 0)
      Some(v) => v
    }
    let (_, _, after_y) = match
      metrics_gvar_deltas_capture(gvar, after_x, count, -1, -1) {
      None => return (0, 0)
      Some(v) => v
    }
    if after_y > tuple_end {
      return (0, 0)
    }
    if scalar != 0.0 {
      accum0 = accum0 + dx0.to_double() * scalar
      accum1 = accum1 + dx1.to_double() * scalar
    }
    cursor = tuple_end
  }
  (accum0.round().to_int(), accum1.round().to_int())
}

///|
pub fn GlyphMetrics::advance_width(
  self : GlyphMetrics,
  gid : GlyphId,
) -> Double? {
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= self.glyph_count {
    return None
  }
  let mut aw = match self.base {
    None => 0
    Some(base) => base.advance_width(gid).unwrap_or(0).to_uint64().to_int()
  }
  if !self.coords.is_empty() {
    if self.hvar is Some(hvar) && self.hvar_aw_map_off is Some(_) {
      aw = aw +
        metrics_hvar_delta(
          hvar,
          self.hvar_store_off,
          self.hvar_aw_map_off,
          gid,
          self.coords,
        )
    } else {
      let (dx0, dx1) = self.gvar_phantom_deltas(gid)
      aw = aw + (dx1 - dx0)
    }
  }
  Some(aw.to_double() * self.scale)
}

///|
pub fn GlyphMetrics::left_side_bearing(
  self : GlyphMetrics,
  gid : GlyphId,
) -> Double? {
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= self.glyph_count {
    return None
  }
  let mut lsb = match self.base {
    None => 0
    Some(base) => base.lsb(gid).unwrap_or(0)
  }
  if !self.coords.is_empty() {
    if self.hvar is Some(hvar) && self.hvar_lsb_map_off is Some(_) {
      lsb = lsb +
        metrics_hvar_delta(
          hvar,
          self.hvar_store_off,
          self.hvar_lsb_map_off,
          gid,
          self.coords,
        )
    } else {
      let (dx0, _) = self.gvar_phantom_deltas(gid)
      lsb = lsb + dx0
    }
  }
  Some(lsb.to_double() * self.scale)
}

///|
pub fn FontRef::glyph_metrics(
  self : FontRef,
  size : Size,
  location : LocationRef,
) -> GlyphMetrics {
  GlyphMetrics::new(self, size, location)
}
