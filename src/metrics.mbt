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
fn metrics_read_i32_be(view : BytesView, offset : Int) -> Int? {
  match metrics_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.reinterpret_as_int())
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
