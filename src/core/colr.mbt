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
/// Color glyph layers (OpenType `COLR` v0) MVP.
///
/// Ported from `fontations/skrifa/src/color/*` (Apache-2.0 OR MIT).
const COLR_TAG_COLR : UInt = 0x434F4C52 // "COLR"

///|
fn colr_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn colr_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn colr_read_u32_be_int(view : BytesView, offset : Int) -> Int? {
  match colr_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.to_uint64().to_int())
  }
}

///|
pub struct ColorLayer {
  glyph_id : GlyphId
  palette_index : Int
}

///|
pub fn ColorLayer::glyph_id(self : ColorLayer) -> GlyphId {
  self.glyph_id
}

///|
pub fn ColorLayer::palette_index(self : ColorLayer) -> Int {
  self.palette_index
}

///|
pub(all) enum ColorGlyphFormat {
  ColrV0
  ColrV1
}

///|
pub struct ColorGlyph {
  priv collection : ColorGlyphCollection
  priv glyph_id : GlyphId
  priv format : ColorGlyphFormat
}

///|
pub fn ColorGlyph::format(self : ColorGlyph) -> ColorGlyphFormat {
  self.format
}

///|
pub fn ColorGlyph::layers(self : ColorGlyph) -> Array[ColorLayer]? {
  match self.format {
    ColrV0 => self.collection.layers(self.glyph_id)
    ColrV1 => None
  }
}

///|
pub fn[P : ColorPainter] ColorGlyph::paint(
  self : ColorGlyph,
  location : LocationRef,
  painter : P,
) -> Result[Unit, PaintError] {
  match self.format {
    ColrV1 =>
      match self.collection.font {
        Some(font) => font.paint_colr_v1_at(self.glyph_id, location, painter)
        None => Err(ParseError)
      }
    ColrV0 =>
      match self.collection.layers(self.glyph_id) {
        None => Err(GlyphNotFound(self.glyph_id))
        Some(layers) => {
          for layer in layers {
            painter.fill_glyph(
              layer.glyph_id(),
              None,
              Solid(layer.palette_index(), 1.0),
            )
          }
          Ok(())
        }
      }
  }
}

///|
pub struct ColorGlyphCollection {
  priv font : FontRef?
  priv colr : BytesView?
  priv version : Int
  priv base_off : Int
  priv layer_off : Int
  priv num_base : Int
  priv num_layers : Int
  priv _v1_base_glyph_list_off : Int?
  priv _v1_layer_list_off : Int?
  priv _v1_clip_list_off : Int?
  priv _v1_var_index_map_off : Int?
  priv _v1_item_variation_store_off : Int?
}

///|
pub fn ColorGlyphCollection::ColorGlyphCollection(
  font : FontRef,
) -> ColorGlyphCollection {
  let colr = match font.table(COLR_TAG_COLR) {
    None => return ColorGlyphCollection::empty(Some(font))
    Some(v) => v
  }
  if colr.length() < 14 {
    return ColorGlyphCollection::empty(Some(font))
  }
  let version = colr_read_u16_be(colr, 0).unwrap_or(-1)
  if version != 0 && version != 1 {
    return ColorGlyphCollection::empty(Some(font))
  }
  if version == 1 && colr.length() < 34 {
    return ColorGlyphCollection::empty(Some(font))
  }
  let num_base = colr_read_u16_be(colr, 2).unwrap_or(-1)
  let base_off = colr_read_u32_be_int(colr, 4).unwrap_or(-1)
  let layer_off = colr_read_u32_be_int(colr, 8).unwrap_or(-1)
  let num_layers = colr_read_u16_be(colr, 12).unwrap_or(-1)
  if num_base < 0 || base_off < 0 || layer_off < 0 || num_layers < 0 {
    return ColorGlyphCollection::empty(Some(font))
  }
  let base_end = base_off + num_base * 6
  let layers_end = layer_off + num_layers * 4
  if base_end < base_off || base_end > colr.length() {
    return ColorGlyphCollection::empty(Some(font))
  }
  if layers_end < layer_off || layers_end > colr.length() {
    return ColorGlyphCollection::empty(Some(font))
  }
  let mut _v1_base_glyph_list_off : Int? = None
  let mut _v1_layer_list_off : Int? = None
  let mut _v1_clip_list_off : Int? = None
  let mut _v1_var_index_map_off : Int? = None
  let mut _v1_item_variation_store_off : Int? = None
  if version == 1 {
    let bg = colr_read_u32_be_int(colr, 14).unwrap_or(-1)
    let ll = colr_read_u32_be_int(colr, 18).unwrap_or(-1)
    let cl = colr_read_u32_be_int(colr, 22).unwrap_or(-1)
    let vim = colr_read_u32_be_int(colr, 26).unwrap_or(-1)
    let ivs = colr_read_u32_be_int(colr, 30).unwrap_or(-1)
    // In COLR, Offset32 uses 0 as "NULL".
    if bg > 0 && bg < colr.length() {
      _v1_base_glyph_list_off = Some(bg)
    }
    if ll > 0 && ll < colr.length() {
      _v1_layer_list_off = Some(ll)
    }
    if cl > 0 && cl < colr.length() {
      _v1_clip_list_off = Some(cl)
    }
    if vim > 0 && vim < colr.length() {
      _v1_var_index_map_off = Some(vim)
    }
    if ivs > 0 && ivs < colr.length() {
      _v1_item_variation_store_off = Some(ivs)
    }
  }
  {
    font: Some(font),
    colr: Some(colr),
    version,
    base_off,
    layer_off,
    num_base,
    num_layers,
    _v1_base_glyph_list_off,
    _v1_layer_list_off,
    _v1_clip_list_off,
    _v1_var_index_map_off,
    _v1_item_variation_store_off,
  }
}

///|
fn ColorGlyphCollection::empty(font : FontRef?) -> ColorGlyphCollection {
  {
    font,
    colr: None,
    version: 0,
    base_off: 0,
    layer_off: 0,
    num_base: 0,
    num_layers: 0,
    _v1_base_glyph_list_off: None,
    _v1_layer_list_off: None,
    _v1_clip_list_off: None,
    _v1_var_index_map_off: None,
    _v1_item_variation_store_off: None,
  }
}

///|
pub fn ColorGlyphCollection::version(self : ColorGlyphCollection) -> Int {
  self.version
}

///|
pub fn ColorGlyphCollection::has_colr_v1(self : ColorGlyphCollection) -> Bool {
  self.colr is Some(_) && self.version == 1
}

///|
fn ColorGlyphCollection::v1_has_glyph(
  self : ColorGlyphCollection,
  glyph_id : GlyphId,
) -> Bool {
  if self.version != 1 {
    return false
  }
  let colr = match self.colr {
    None => return false
    Some(v) => v
  }
  let base_glyph_list_off = match self._v1_base_glyph_list_off {
    None => return false
    Some(v) => v
  }
  let gid = glyph_id.to_uint64().to_int()
  if gid < 0 {
    return false
  }
  let num = colr_read_u32_be_int(colr, base_glyph_list_off).unwrap_or(-1)
  if num < 0 {
    return false
  }
  let records_off = base_glyph_list_off + 4
  let records_end = records_off + num * 6
  if records_end < records_off || records_end > colr.length() {
    return false
  }
  let mut lo = 0
  let mut hi = num
  while lo < hi {
    let mid = (lo + hi) / 2
    let pos = records_off + mid * 6
    let mgid = colr_read_u16_be(colr, pos).unwrap_or(-1)
    if mgid < gid {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo < 0 || lo >= num {
    return false
  }
  let pos = records_off + lo * 6
  let found = colr_read_u16_be(colr, pos).unwrap_or(-1)
  if found != gid {
    return false
  }
  let paint_off = colr_read_u32_be_int(colr, pos + 2).unwrap_or(-1)
  if paint_off <= 0 {
    return false
  }
  let abs_off = base_glyph_list_off + paint_off
  abs_off >= 0 && abs_off < colr.length()
}

///|
pub fn ColorGlyphCollection::get_with_format(
  self : ColorGlyphCollection,
  glyph_id : GlyphId,
  glyph_format : ColorGlyphFormat,
) -> ColorGlyph? {
  match glyph_format {
    ColrV0 =>
      if self.layers(glyph_id) is Some(_) {
        Some({ collection: self, glyph_id, format: glyph_format })
      } else {
        None
      }
    ColrV1 =>
      if self.v1_has_glyph(glyph_id) {
        Some({ collection: self, glyph_id, format: glyph_format })
      } else {
        None
      }
  }
}

///|
pub fn ColorGlyphCollection::get(
  self : ColorGlyphCollection,
  glyph_id : GlyphId,
) -> ColorGlyph? {
  match self.get_with_format(glyph_id, ColrV1) {
    None => self.get_with_format(glyph_id, ColrV0)
    Some(v) => Some(v)
  }
}

///|
pub fn ColorGlyphCollection::layers(
  self : ColorGlyphCollection,
  glyph_id : GlyphId,
) -> Array[ColorLayer]? {
  let colr = match self.colr {
    None => return None
    Some(v) => v
  }
  let gid = glyph_id.to_uint64().to_int()
  if gid < 0 {
    return None
  }
  // Base glyph records are sorted by glyphId; binary search.
  let mut lo = 0
  let mut hi = self.num_base
  while lo < hi {
    let mid = (lo + hi) / 2
    let pos = self.base_off + mid * 6
    let mgid = colr_read_u16_be(colr, pos).unwrap_or(-1)
    if mgid < gid {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo < 0 || lo >= self.num_base {
    return None
  }
  let pos = self.base_off + lo * 6
  let found = colr_read_u16_be(colr, pos).unwrap_or(-1)
  if found != gid {
    return None
  }
  let first_layer = colr_read_u16_be(colr, pos + 2).unwrap_or(-1)
  let num = colr_read_u16_be(colr, pos + 4).unwrap_or(-1)
  if first_layer < 0 || num < 0 {
    return None
  }
  if first_layer + num > self.num_layers {
    return None
  }
  let out : Array[ColorLayer] = Array::new(capacity=num)
  for i in 0..<num {
    let lpos = self.layer_off + (first_layer + i) * 4
    let layer_gid = colr_read_u16_be(colr, lpos).unwrap_or(-1)
    let palette_idx = colr_read_u16_be(colr, lpos + 2).unwrap_or(-1)
    if layer_gid < 0 || palette_idx < 0 {
      continue
    }
    out.push({
      glyph_id: GlyphId(layer_gid.to_uint16()),
      palette_index: palette_idx,
    })
  }
  Some(out)
}

///|
pub fn FontRef::color_glyphs(self : FontRef) -> ColorGlyphCollection {
  ColorGlyphCollection(self)
}
