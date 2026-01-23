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
