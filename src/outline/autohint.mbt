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
/// Runtime autohinting support.
///
/// Upstream `fontations/skrifa` includes a runtime autohinter used when a font
/// does not provide embedded instructions. In this port, `GlyphStyles` is the
/// (font-invariant) precomputed style map that can be reused across hinting
/// instances.

///|
pub struct GlyphStyles {
  priv map : GlyphStyleMap
}

///|
priv struct GlyphStyleMap {
  styles : Array[GlyphStyle]
  metrics_map : Array[Byte]
  mut metrics_count : Int
}

///|
priv struct GlyphStyle {
  bits : Int
}

///|
const AUTOHINT_STYLE_INDEX_MASK : Int = 0xFF

///|
const AUTOHINT_STYLE_INDEX_KEEP_MASK : Int = -1 - AUTOHINT_STYLE_INDEX_MASK

///|
const AUTOHINT_STYLE_UNASSIGNED : Int = AUTOHINT_STYLE_INDEX_MASK

///|
const AUTOHINT_STYLE_NON_BASE : Int = 0x100

///|
const AUTOHINT_STYLE_DIGIT : Int = 0x200

///|
const AUTOHINT_STYLE_LATN : Int = 60

///|
const AUTOHINT_STYLE_HANI : Int = 89

///|
const AUTOHINT_MAX_STYLES : Int = 90

///|
fn GlyphStyle::default() -> GlyphStyle {
  GlyphStyle::{ bits: AUTOHINT_STYLE_UNASSIGNED }
}

///|
fn GlyphStyle::is_unassigned(self : GlyphStyle) -> Bool {
  (self.bits & AUTOHINT_STYLE_INDEX_MASK) == AUTOHINT_STYLE_UNASSIGNED
}

///|
fn GlyphStyle::is_digit(self : GlyphStyle) -> Bool {
  (self.bits & AUTOHINT_STYLE_DIGIT) != 0
}

///|
fn GlyphStyle::is_non_base(self : GlyphStyle) -> Bool {
  (self.bits & AUTOHINT_STYLE_NON_BASE) != 0
}

///|
fn GlyphStyle::style_index(self : GlyphStyle) -> Int? {
  let ix = self.bits & AUTOHINT_STYLE_INDEX_MASK
  if ix == AUTOHINT_STYLE_UNASSIGNED {
    None
  } else {
    Some(ix)
  }
}

///|
fn GlyphStyle::with_style_index(style_index : Int) -> GlyphStyle {
  GlyphStyle::{ bits: style_index & AUTOHINT_STYLE_INDEX_MASK }
}

///|
fn GlyphStyle::with_style_index_non_base(style_index : Int) -> GlyphStyle {
  GlyphStyle::{
    bits: (style_index & AUTOHINT_STYLE_INDEX_MASK) | AUTOHINT_STYLE_NON_BASE,
  }
}

///|
fn GlyphStyle::maybe_assign(
  self : GlyphStyle,
  other : GlyphStyle,
) -> GlyphStyle {
  let other_ix = other.bits & AUTOHINT_STYLE_INDEX_MASK
  let self_ix = self.bits & AUTOHINT_STYLE_INDEX_MASK
  if other_ix <= self_ix {
    GlyphStyle::{
      bits: (self.bits & AUTOHINT_STYLE_INDEX_KEEP_MASK) |
      other_ix |
      (other.bits & AUTOHINT_STYLE_INDEX_KEEP_MASK),
    }
  } else {
    self
  }
}

///|
fn GlyphStyle::set_digit(self : GlyphStyle) -> GlyphStyle {
  GlyphStyle::{ bits: self.bits | AUTOHINT_STYLE_DIGIT }
}

///|
fn GlyphStyleMap::default() -> GlyphStyleMap {
  let styles : Array[GlyphStyle] = Array::new()
  let metrics_map : Array[Byte] = Array::new()
  for _ in 0..<AUTOHINT_MAX_STYLES {
    metrics_map.push((0xFF).to_byte())
  }
  GlyphStyleMap::{ styles, metrics_map, metrics_count: 0 }
}

///|
fn GlyphStyleMap::use_style(self : GlyphStyleMap, style_ix : Int) -> Unit {
  if style_ix < 0 || style_ix >= self.metrics_map.length() {
    return
  }
  if self.metrics_map.at(style_ix).to_int() != 0xFF {
    return
  }
  self.metrics_map.set(style_ix, self.metrics_count.to_byte())
  self.metrics_count = self.metrics_count + 1
}

///|
fn autohint_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
const AUTOHINT_TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
fn autohint_num_glyphs(font : @moon_skrifa.FontRef) -> Int {
  match font.table(AUTOHINT_TAG_MAXP) {
    None => 0
    Some(maxp) => autohint_read_u16_be(maxp, 4).unwrap_or(0)
  }
}

///|
fn autohint_style_for_codepoint(
  ranges : ArrayView[AutoHintStyleRange],
  cp : UInt,
) -> (Int, Int, GlyphStyle)? {
  let ch = cp.to_uint64().to_int()
  match autohint_style_range_for_codepoint(ch, ranges) {
    None => None
    Some((start, end, bits)) => {
      let style_ix = bits & AUTOHINT_STYLE_INDEX_MASK
      let style = if (bits & AUTOHINT_STYLE_NON_BASE) != 0 {
        GlyphStyle::with_style_index_non_base(style_ix)
      } else {
        GlyphStyle::with_style_index(style_ix)
      }
      Some((start, end, style))
    }
  }
}

///|
fn GlyphStyleMap::new(
  glyph_count : Int,
  font : @moon_skrifa.FontRef,
) -> GlyphStyleMap {
  let map = GlyphStyleMap::default()
  let ranges = autohint_style_ranges()
  for _ in 0..<glyph_count {
    map.styles.push(GlyphStyle::default())
  }
  let mut last_range : (Int, Int, GlyphStyle)? = None
  // Step 2: compute styles for glyphs contained in the cmap.
  for pair in font.charmap().mappings().iter() {
    let (cp, gid) = pair
    let gi = gid.to_uint64().to_int()
    if gi < 0 || gi >= map.styles.length() {
      continue
    }
    let mut style = map.styles.at(gi)
    match last_range {
      Some((start, end, s)) =>
        if cp.to_uint64().to_int() >= start && cp.to_uint64().to_int() <= end {
          style = style.maybe_assign(s)
          map.styles.set(gi, style)
          continue
        }
      None => ()
    }
    match autohint_style_for_codepoint(ranges, cp) {
      None => ()
      Some((start, end, s)) => {
        style = style.maybe_assign(s)
        map.styles.set(gi, style)
        // Keep track of the style range we just used for cheap locality.
        last_range = Some((start, end, s))
        match s.style_index() {
          None => ()
          Some(ix) => map.use_style(ix)
        }
      }
    }
  }
  // Step 4: assign a default to all remaining glyphs (Hani, matches upstream).
  let mut need_hani = false
  for i in 0..<map.styles.length() {
    let s = map.styles.at(i)
    if s.is_unassigned() {
      map.styles.set(i, GlyphStyle::with_style_index(AUTOHINT_STYLE_HANI))
      need_hani = true
    }
  }
  if need_hani {
    map.use_style(AUTOHINT_STYLE_HANI)
  }
  // Step 5: mark ASCII digits.
  for digit in 0x30..<0x3A {
    match font.charmap().map(digit |> Int::reinterpret_as_uint) {
      None => ()
      Some(gid) => {
        let gi = gid.to_uint64().to_int()
        if gi >= 0 && gi < map.styles.length() {
          map.styles.set(gi, map.styles.at(gi).set_digit())
        }
      }
    }
  }
  map
}

///|
/// Precomputes the glyph style map for a font.
///
/// This is invariant per font and can be reused when creating multiple
/// `HintingInstance`s with `Engine::Auto(...)`.
pub fn GlyphStyles::new(outlines : OutlineGlyphCollection) -> GlyphStyles {
  let font = outlines.font
  let glyph_count = autohint_num_glyphs(font)
  let map = if glyph_count <= 0 {
    GlyphStyleMap::default()
  } else {
    GlyphStyleMap::new(glyph_count, font)
  }
  GlyphStyles::{ map, }
}

///|
pub fn GlyphStyles::style_index(
  self : GlyphStyles,
  gid : @moon_skrifa.GlyphId,
) -> Int? {
  let gi = gid.to_uint64().to_int()
  if gi < 0 || gi >= self.map.styles.length() {
    None
  } else {
    self.map.styles.at(gi).style_index()
  }
}

///|
pub fn GlyphStyles::is_digit(
  self : GlyphStyles,
  gid : @moon_skrifa.GlyphId,
) -> Bool {
  let gi = gid.to_uint64().to_int()
  if gi < 0 || gi >= self.map.styles.length() {
    false
  } else {
    self.map.styles.at(gi).is_digit()
  }
}

///|
fn GlyphStyles::_is_non_base(
  self : GlyphStyles,
  gid : @moon_skrifa.GlyphId,
) -> Bool {
  let gi = gid.to_uint64().to_int()
  if gi < 0 || gi >= self.map.styles.length() {
    false
  } else {
    self.map.styles.at(gi).is_non_base()
  }
}
