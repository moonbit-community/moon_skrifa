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
/// COLRv1 paint graph traversal (MVP).
///
/// Ported from `fontations/skrifa/src/color/{instance,traversal}.rs` (Apache-2.0 OR MIT).
///
/// Current scope:
/// - Formats: all COLRv1 paint formats 1..=32 (including gradients, transforms and var variants)
/// - ClipList support (including ClipBox format 2 variation deltas)
const COLOR_TRAV_TAG_COLR : UInt = 0x434F4C52 // "COLR"

///|
pub(all) enum PaintError {
  ParseError
  GlyphNotFound(GlyphId)
  PaintCycleDetected
  DepthLimitExceeded
  UnsupportedPaintFormat(Int)
}

///|
pub(all) enum PaintCachedColorGlyph {
  Ok
  Unimplemented
}

///|
pub(all) enum CompositeMode {
  Clear
  Src
  Dest
  SrcOver
  DestOver
  SrcIn
  DestIn
  SrcOut
  DestOut
  SrcAtop
  DestAtop
  Xor
  Plus
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Multiply
  HslHue
  HslSaturation
  HslColor
  HslLuminosity
  Unknown
}

///|
pub(all) enum Extend {
  Pad
  Repeat
  Reflect
  Unknown
}

///|
fn extend_from_u8(raw : Int) -> Extend {
  match raw {
    0 => Pad
    1 => Repeat
    2 => Reflect
    _ => Unknown
  }
}

///|
pub fn Extend::raw(self : Extend) -> Int {
  match self {
    Pad => 0
    Repeat => 1
    Reflect => 2
    Unknown => -1
  }
}

///|
fn extend_is_pad(e : Extend) -> Bool {
  e.raw() == 0
}

///|
fn composite_mode_from_u8(raw : Int) -> CompositeMode {
  match raw {
    0 => Clear
    1 => Src
    2 => Dest
    3 => SrcOver
    4 => DestOver
    5 => SrcIn
    6 => DestIn
    7 => SrcOut
    8 => DestOut
    9 => SrcAtop
    10 => DestAtop
    11 => Xor
    12 => Plus
    13 => Screen
    14 => Overlay
    15 => Darken
    16 => Lighten
    17 => ColorDodge
    18 => ColorBurn
    19 => HardLight
    20 => SoftLight
    21 => Difference
    22 => Exclusion
    23 => Multiply
    24 => HslHue
    25 => HslSaturation
    26 => HslColor
    27 => HslLuminosity
    _ => Unknown
  }
}

///|
pub fn CompositeMode::raw(self : CompositeMode) -> Int {
  match self {
    Clear => 0
    Src => 1
    Dest => 2
    SrcOver => 3
    DestOver => 4
    SrcIn => 5
    DestIn => 6
    SrcOut => 7
    DestOut => 8
    SrcAtop => 9
    DestAtop => 10
    Xor => 11
    Plus => 12
    Screen => 13
    Overlay => 14
    Darken => 15
    Lighten => 16
    ColorDodge => 17
    ColorBurn => 18
    HardLight => 19
    SoftLight => 20
    Difference => 21
    Exclusion => 22
    Multiply => 23
    HslHue => 24
    HslSaturation => 25
    HslColor => 26
    HslLuminosity => 27
    Unknown => -1
  }
}

///|
pub(all) struct ColorStop {
  offset : Double
  palette_index : Int
  alpha : Double
}

///|
pub(all) enum Brush {
  Solid(Int, Double)
  LinearGradient((Double, Double), (Double, Double), Array[ColorStop], Extend)
  RadialGradient(
    (Double, Double),
    Double,
    (Double, Double),
    Double,
    Array[ColorStop],
    Extend
  )
  SweepGradient((Double, Double), Double, Double, Array[ColorStop], Extend)
}

///|
pub(open) trait ColorPainter {
  push_transform(Self, Transform) -> Unit
  pop_transform(Self) -> Unit
  push_clip_glyph(Self, GlyphId) -> Unit
  push_clip_box(Self, (Double, Double, Double, Double)) -> Unit
  pop_clip(Self) -> Unit
  fill(Self, Brush) -> Unit
  fill_glyph(Self, GlyphId, Transform?, Brush) -> Unit
  paint_cached_color_glyph(Self, GlyphId) -> Result[
    PaintCachedColorGlyph,
    PaintError,
  ]
  push_layer(Self, CompositeMode) -> Unit
  pop_layer(Self) -> Unit
  pop_layer_with_mode(Self, CompositeMode) -> Unit
}

///|
const COLOR_TRAV_MAX_DEPTH : Int = 64

///|
fn color_trav_read_u8(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 1 > view.length() {
    None
  } else {
    Some(view.at(offset).to_int())
  }
}

///|
fn color_trav_read_i8(view : BytesView, offset : Int) -> Int? {
  match color_trav_read_u8(view, offset) {
    None => None
    Some(u) => if u >= 0x80 { Some(u - 0x100) } else { Some(u) }
  }
}

///|
fn color_trav_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn color_trav_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match color_trav_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
fn color_trav_read_u24_be(view : BytesView, offset : Int) -> Int? {
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
fn color_trav_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn color_trav_read_u32_be_int(view : BytesView, offset : Int) -> Int? {
  match color_trav_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.to_uint64().to_int())
  }
}

///|
fn color_trav_read_fixed_16_16(view : BytesView, offset : Int) -> Double? {
  match color_trav_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.reinterpret_as_int().to_double() / 65536.0)
  }
}

///|
fn color_trav_read_f2dot14(view : BytesView, offset : Int) -> Double? {
  match color_trav_read_i16_be(view, offset) {
    None => None
    Some(v) => Some(v.to_double() / 16384.0)
  }
}

///|
const COLOR_TRAV_PI : Double = 3.141592653589793

///|
const COLOR_TRAV_NO_VARIATION_DELTAS : UInt = 0xFFFFFFFF

///|
fn color_trav_var_index_add(base : UInt, add : Int) -> UInt {
  base + add.reinterpret_as_uint()
}

///|
fn color_trav_apply_fword_delta(base : Int, delta : Double) -> Double {
  base.to_double() + delta
}

///|
fn color_trav_apply_ufword_delta(base : Int, delta : Double) -> Double {
  base.to_double() + delta
}

///|
fn color_trav_apply_fixed_delta(base : Double, delta : Double) -> Double {
  base + delta / 65536.0
}

///|
fn color_trav_apply_f2dot14_delta(base : Double, delta : Double) -> Double {
  base + delta / 16384.0
}

///|
fn color_trav_var_entry_size(entry_format : Int) -> Int {
  ((entry_format & 0x30) >> 4) + 1
}

///|
fn color_trav_var_bit_count(entry_format : Int) -> Int {
  (entry_format & 0x0F) + 1
}

///|
fn color_trav_var_index_map_get(
  colr : BytesView,
  map_off : Int,
  index : UInt,
) -> (Int, Int)? {
  let format = color_trav_read_u8(colr, map_off).unwrap_or(-1)
  if format != 0 && format != 1 {
    return None
  }
  let entry_format = color_trav_read_u8(colr, map_off + 1).unwrap_or(-1)
  if entry_format < 0 {
    return None
  }
  let entry_size = color_trav_var_entry_size(entry_format)
  let bit_count = color_trav_var_bit_count(entry_format)
  if entry_size < 1 || entry_size > 4 || bit_count < 1 || bit_count > 16 {
    return None
  }
  let map_count = if format == 0 {
    color_trav_read_u16_be(colr, map_off + 2).unwrap_or(-1)
  } else {
    color_trav_read_u32_be_int(colr, map_off + 2).unwrap_or(-1)
  }
  if map_count <= 0 {
    return None
  }
  let idx = index.to_uint64().to_int()
  if idx < 0 || idx >= map_count {
    return None
  }
  let data_off = if format == 0 { map_off + 4 } else { map_off + 6 }
  let entry_off = data_off + idx * entry_size
  let entry : Int? = match entry_size {
    1 => color_trav_read_u8(colr, entry_off)
    2 => color_trav_read_u16_be(colr, entry_off)
    3 => color_trav_read_u24_be(colr, entry_off)
    _ => color_trav_read_u32_be_int(colr, entry_off)
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
fn color_trav_region_scalar(
  colr : BytesView,
  region_list_off : Int,
  region_index : Int,
  coords : ArrayView[NormalizedCoord],
) -> Double {
  let axis_count = color_trav_read_u16_be(colr, region_list_off).unwrap_or(-1)
  let region_count = color_trav_read_u16_be(colr, region_list_off + 2).unwrap_or(
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
    let start = color_trav_read_i16_be(colr, ax).unwrap_or(0).to_double() /
      16384.0
    let peak = color_trav_read_i16_be(colr, ax + 2).unwrap_or(0).to_double() /
      16384.0
    let end = color_trav_read_i16_be(colr, ax + 4).unwrap_or(0).to_double() /
      16384.0
    if peak == 0.0 {
      continue
    }
    if start > peak || peak > end || (start < 0.0 && end > 0.0) {
      continue
    }
    let coord = if i < coords.length() {
      coords.at(i).to_double() / 16384.0
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
fn color_trav_item_variation_store_delta(
  colr : BytesView,
  store_off : Int,
  outer : Int,
  inner : Int,
  coords : ArrayView[NormalizedCoord],
) -> Double {
  if coords.is_empty() {
    return 0.0
  }
  // ItemVariationStore header:
  // u16 format, u32 regionListOff, u16 dataCount, u32[dataCount] dataOffsets
  let region_list_rel = color_trav_read_u32_be_int(colr, store_off + 2).unwrap_or(
    -1,
  )
  let data_count = color_trav_read_u16_be(colr, store_off + 6).unwrap_or(-1)
  if region_list_rel <= 0 || data_count <= 0 {
    return 0.0
  }
  if outer < 0 || outer >= data_count {
    return 0.0
  }
  let offsets_off = store_off + 8
  let data_rel = color_trav_read_u32_be_int(colr, offsets_off + outer * 4).unwrap_or(
    0,
  )
  if data_rel <= 0 {
    return 0.0
  }
  let data_off = store_off + data_rel
  // ItemVariationData header:
  // u16 itemCount, u16 shortDeltaCount, u16 regionIndexCount, u16[regionIndexCount] regionIndexes, deltaSets...
  let item_count = color_trav_read_u16_be(colr, data_off).unwrap_or(-1)
  let short_count = color_trav_read_u16_be(colr, data_off + 2).unwrap_or(-1)
  let region_index_count = color_trav_read_u16_be(colr, data_off + 4).unwrap_or(
    -1,
  )
  if item_count <= 0 || region_index_count <= 0 {
    return 0.0
  }
  if inner < 0 || inner >= item_count {
    return 0.0
  }
  let region_indexes_off = data_off + 6
  let deltas_off = region_indexes_off + region_index_count * 2
  let short = if short_count < 0 { 0 } else { short_count }
  let row_size = short * 2 + (region_index_count - short)
  if row_size <= 0 {
    return 0.0
  }
  let row_off = deltas_off + inner * row_size
  let region_list_off = store_off + region_list_rel
  let mut accum = 0.0
  for i in 0..<region_index_count {
    let region_index = color_trav_read_u16_be(colr, region_indexes_off + i * 2).unwrap_or(
      -1,
    )
    let scalar = color_trav_region_scalar(
      colr, region_list_off, region_index, coords,
    )
    if scalar == 0.0 {
      continue
    }
    let delta = if i < short {
      color_trav_read_i16_be(colr, row_off + i * 2).unwrap_or(0)
    } else {
      let pos = row_off + short * 2 + (i - short)
      color_trav_read_i8(colr, pos).unwrap_or(0)
    }
    accum = accum + delta.to_double() * scalar
  }
  accum
}

///|
fn color_trav_var_delta(
  colr : BytesView,
  var_index_map_off : Int?,
  store_off : Int?,
  var_index : UInt,
  coords : ArrayView[NormalizedCoord],
) -> Double {
  if coords.is_empty() {
    return 0.0
  }
  if store_off is None {
    return 0.0
  }
  if var_index == COLOR_TRAV_NO_VARIATION_DELTAS {
    return 0.0
  }
  let (outer, inner) = match var_index_map_off {
    None => (0, (var_index & 0xFFFF).to_uint64().to_int())
    Some(map_off) =>
      match color_trav_var_index_map_get(colr, map_off, var_index) {
        None => return 0.0
        Some(v) => v
      }
  }
  color_trav_item_variation_store_delta(
    colr,
    store_off.unwrap(),
    outer,
    inner,
    coords,
  )
}

///|
fn color_trav_sort_color_stops(stops : Array[ColorStop]) -> Unit {
  // Insertion sort (color line stop counts are typically small).
  let n = stops.length()
  for i in 1..<n {
    let key = stops.at(i)
    let mut j = i - 1
    while j >= 0 && stops.at(j).offset > key.offset {
      stops.set(j + 1, stops.at(j))
      j = j - 1
    }
    stops.set(j + 1, key)
  }
}

///|
fn color_trav_stack_contains(stack : Array[Int], id : Int) -> Bool {
  for x in stack {
    if x == id {
      return true
    }
  }
  false
}

///|
fn color_trav_base_paint_offset(
  colr : BytesView,
  base_glyph_list_off : Int,
  glyph_id : GlyphId,
) -> Int? {
  let gid = glyph_id.to_uint64().to_int()
  if gid < 0 {
    return None
  }
  let num = color_trav_read_u32_be_int(colr, base_glyph_list_off).unwrap_or(-1)
  if num < 0 {
    return None
  }
  let records_off = base_glyph_list_off + 4
  let records_end = records_off + num * 6
  if records_end < records_off || records_end > colr.length() {
    return None
  }
  // Sorted by glyph id.
  let mut lo = 0
  let mut hi = num
  while lo < hi {
    let mid = (lo + hi) / 2
    let pos = records_off + mid * 6
    let mgid = color_trav_read_u16_be(colr, pos).unwrap_or(-1)
    if mgid < gid {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo < 0 || lo >= num {
    return None
  }
  let pos = records_off + lo * 6
  let found = color_trav_read_u16_be(colr, pos).unwrap_or(-1)
  if found != gid {
    return None
  }
  let off = color_trav_read_u32_be_int(colr, pos + 2).unwrap_or(-1)
  if off <= 0 {
    return None
  }
  let abs_off = base_glyph_list_off + off
  if abs_off < 0 || abs_off >= colr.length() {
    None
  } else {
    Some(abs_off)
  }
}

///|
fn color_trav_layer_paint_offset(
  colr : BytesView,
  layer_list_off : Int,
  layer_index : Int,
) -> Int? {
  let num = color_trav_read_u32_be_int(colr, layer_list_off).unwrap_or(-1)
  if num <= 0 {
    return None
  }
  if layer_index < 0 || layer_index >= num {
    return None
  }
  let offsets_off = layer_list_off + 4
  let offsets_end = offsets_off + num * 4
  if offsets_end < offsets_off || offsets_end > colr.length() {
    return None
  }
  let off = color_trav_read_u32_be_int(colr, offsets_off + layer_index * 4).unwrap_or(
    -1,
  )
  if off <= 0 {
    return None
  }
  let abs_off = layer_list_off + off
  if abs_off < 0 || abs_off >= colr.length() {
    None
  } else {
    Some(abs_off)
  }
}

///|
fn color_trav_clip_box(
  colr : BytesView,
  clip_list_off : Int,
  glyph_id : GlyphId,
  coords : ArrayView[NormalizedCoord],
  var_index_map_off : Int?,
  var_store_off : Int?,
) -> (Double, Double, Double, Double)? {
  let gid = glyph_id.to_uint64().to_int()
  if gid < 0 {
    return None
  }
  let format = color_trav_read_u8(colr, clip_list_off).unwrap_or(-1)
  if format != 1 {
    return None
  }
  let num = color_trav_read_u32_be_int(colr, clip_list_off + 1).unwrap_or(-1)
  if num <= 0 {
    return None
  }
  let clips_off = clip_list_off + 5
  let clips_end = clips_off + num * 7
  if clips_end < clips_off || clips_end > colr.length() {
    return None
  }
  // Clips are sorted by startGlyphID; find last start <= gid.
  let mut lo = 0
  let mut hi = num
  while lo < hi {
    let mid = (lo + hi) / 2
    let pos = clips_off + mid * 7
    let start_gid = color_trav_read_u16_be(colr, pos).unwrap_or(-1)
    if start_gid <= gid {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let idx = lo - 1
  if idx < 0 || idx >= num {
    return None
  }
  let pos = clips_off + idx * 7
  let start_gid = color_trav_read_u16_be(colr, pos).unwrap_or(-1)
  let end_gid = color_trav_read_u16_be(colr, pos + 2).unwrap_or(-1)
  if start_gid < 0 || end_gid < start_gid || gid > end_gid {
    return None
  }
  let clip_box_rel = color_trav_read_u24_be(colr, pos + 4).unwrap_or(-1)
  if clip_box_rel <= 0 {
    return None
  }
  let clip_box_off = clip_list_off + clip_box_rel
  let cformat = color_trav_read_u8(colr, clip_box_off).unwrap_or(-1)
  if cformat != 1 && cformat != 2 {
    return None
  }
  let x_min0 = color_trav_read_i16_be(colr, clip_box_off + 1).unwrap_or(0)
  let y_min0 = color_trav_read_i16_be(colr, clip_box_off + 3).unwrap_or(0)
  let x_max0 = color_trav_read_i16_be(colr, clip_box_off + 5).unwrap_or(0)
  let y_max0 = color_trav_read_i16_be(colr, clip_box_off + 7).unwrap_or(0)
  if cformat == 1 {
    Some(
      (
        x_min0.to_double(),
        y_min0.to_double(),
        x_max0.to_double(),
        y_max0.to_double(),
      ),
    )
  } else {
    let var_base_u = color_trav_read_u32_be(colr, clip_box_off + 9).unwrap_or(
      COLOR_TRAV_NO_VARIATION_DELTAS,
    )
    let dx_min = color_trav_var_delta(
      colr, var_index_map_off, var_store_off, var_base_u, coords,
    )
    let dy_min = color_trav_var_delta(
      colr,
      var_index_map_off,
      var_store_off,
      color_trav_var_index_add(var_base_u, 1),
      coords,
    )
    let dx_max = color_trav_var_delta(
      colr,
      var_index_map_off,
      var_store_off,
      color_trav_var_index_add(var_base_u, 2),
      coords,
    )
    let dy_max = color_trav_var_delta(
      colr,
      var_index_map_off,
      var_store_off,
      color_trav_var_index_add(var_base_u, 3),
      coords,
    )
    Some(
      (
        color_trav_apply_fword_delta(x_min0, dx_min),
        color_trav_apply_fword_delta(y_min0, dy_min),
        color_trav_apply_fword_delta(x_max0, dx_max),
        color_trav_apply_fword_delta(y_max0, dy_max),
      ),
    )
  }
}

///|
fn color_trav_read_color_line(
  colr : BytesView,
  color_line_off : Int,
  is_var : Bool,
  coords : ArrayView[NormalizedCoord],
  var_index_map_off : Int?,
  var_store_off : Int?,
) -> (Extend, Array[ColorStop])? {
  let extend_raw = color_trav_read_u8(colr, color_line_off).unwrap_or(-1)
  if extend_raw < 0 {
    return None
  }
  let extend = extend_from_u8(extend_raw)
  let num = color_trav_read_u16_be(colr, color_line_off + 1).unwrap_or(-1)
  if num < 0 {
    return None
  }
  let rec_len = if is_var { 10 } else { 6 }
  let stops_off = color_line_off + 3
  let end = stops_off + num * rec_len
  if end < stops_off || end > colr.length() {
    return None
  }
  let out : Array[ColorStop] = Array::new(capacity=num)
  for i in 0..<num {
    let p = stops_off + i * rec_len
    let stop_offset0 = color_trav_read_f2dot14(colr, p).unwrap_or(0.0)
    let pi = color_trav_read_u16_be(colr, p + 2).unwrap_or(-1)
    let alpha0 = color_trav_read_f2dot14(colr, p + 4).unwrap_or(1.0)
    if pi < 0 {
      continue
    }
    if is_var {
      let var_base_u = color_trav_read_u32_be(colr, p + 6).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      let d0 = color_trav_var_delta(
        colr, var_index_map_off, var_store_off, var_base_u, coords,
      )
      let d1 = color_trav_var_delta(
        colr,
        var_index_map_off,
        var_store_off,
        color_trav_var_index_add(var_base_u, 1),
        coords,
      )
      out.push(ColorStop::{
        offset: color_trav_apply_f2dot14_delta(stop_offset0, d0),
        palette_index: pi,
        alpha: color_trav_apply_f2dot14_delta(alpha0, d1),
      })
    } else {
      out.push(ColorStop::{
        offset: stop_offset0,
        palette_index: pi,
        alpha: alpha0,
      })
    }
  }
  color_trav_sort_color_stops(out)
  Some((extend, out))
}

///|
fn color_trav_point_add(
  a : (Double, Double),
  b : (Double, Double),
) -> (Double, Double) {
  let (ax, ay) = a
  let (bx, by) = b
  (ax + bx, ay + by)
}

///|
fn color_trav_point_sub(
  a : (Double, Double),
  b : (Double, Double),
) -> (Double, Double) {
  let (ax, ay) = a
  let (bx, by) = b
  (ax - bx, ay - by)
}

///|
fn color_trav_point_mul(a : (Double, Double), k : Double) -> (Double, Double) {
  let (ax, ay) = a
  (ax * k, ay * k)
}

///|
fn color_trav_point_dot(a : (Double, Double), b : (Double, Double)) -> Double {
  let (ax, ay) = a
  let (bx, by) = b
  ax * bx + ay * by
}

///|
fn color_trav_point_cross(a : (Double, Double), b : (Double, Double)) -> Double {
  let (ax, ay) = a
  let (bx, by) = b
  ax * by - ay * bx
}

///|
fn color_trav_point_project(
  vector : (Double, Double),
  onto : (Double, Double),
) -> (Double, Double) {
  let denom = color_trav_point_dot(onto, onto)
  if denom == 0.0 {
    (0.0, 0.0)
  } else {
    let k = color_trav_point_dot(vector, onto) / denom
    color_trav_point_mul(onto, k)
  }
}

///|
fn color_trav_rescale_stops(
  stops : Array[ColorStop],
  start_offset : Double,
  scale_factor : Double,
) -> Unit {
  for i in 0..<stops.length() {
    let s0 = stops.at(i)
    stops.set(i, ColorStop::{
      offset: (s0.offset - start_offset) * scale_factor,
      palette_index: s0.palette_index,
      alpha: s0.alpha,
    })
  }
}

///|
fn color_trav_make_linear_brush(
  p0_in : (Double, Double),
  p1_in : (Double, Double),
  p2_in : (Double, Double),
  stops : Array[ColorStop],
  extend : Extend,
) -> Brush? {
  if stops.is_empty() {
    return None
  }
  let (p0x, p0y) = p0_in
  let (p1x, p1y) = p1_in
  let (p2x, p2y) = p2_in
  if (p1x == p0x && p1y == p0y) || (p2x == p0x && p2y == p0y) {
    let s = stops.at(0)
    return Some(Solid(s.palette_index, s.alpha))
  }
  let p0 = p0_in
  let p1 = p1_in
  let p2 = p2_in
  let v01 = color_trav_point_sub(p1, p0)
  let v02 = color_trav_point_sub(p2, p0)
  if color_trav_point_cross(v01, v02) == 0.0 {
    let s = stops.at(0)
    return Some(Solid(s.palette_index, s.alpha))
  }
  let (v02x, v02y) = v02
  let perp = (v02y, -v02x)
  let mut p3 = color_trav_point_add(p0, color_trav_point_project(v01, perp))
  color_trav_sort_color_stops(stops)
  let first = stops.at(0)
  let mut last = stops.at(stops.length() - 1)
  let mut range = last.offset - first.offset
  if range == 0.0 && !extend_is_pad(extend) {
    return None
  }
  if range == 0.0 && extend_is_pad(extend) {
    stops.push(ColorStop::{
      offset: last.offset + 1.0,
      palette_index: last.palette_index,
      alpha: last.alpha,
    })
    range = 1.0
    last = stops.at(stops.length() - 1)
  }
  let start_offset = first.offset
  let end_offset = last.offset
  if range != 1.0 || start_offset != 0.0 {
    let axis = color_trav_point_sub(p3, p0)
    let p0_off = color_trav_point_mul(axis, start_offset)
    let p3_off = color_trav_point_mul(axis, end_offset)
    p3 = color_trav_point_add(p0, p3_off)
    let p0n = color_trav_point_add(p0, p0_off)
    let scale = 1.0 / range
    color_trav_rescale_stops(stops, start_offset, scale)
    Some(LinearGradient(p0n, p3, stops, extend))
  } else {
    Some(LinearGradient(p0, p3, stops, extend))
  }
}

///|
fn color_trav_make_radial_brush(
  c0_in : (Double, Double),
  r0_in : Double,
  c1_in : (Double, Double),
  r1_in : Double,
  stops : Array[ColorStop],
  extend : Extend,
) -> Brush? {
  if stops.is_empty() {
    return None
  }
  color_trav_sort_color_stops(stops)
  let first = stops.at(0)
  let last = stops.at(stops.length() - 1)
  let mut range = last.offset - first.offset
  if range == 0.0 && !extend_is_pad(extend) {
    return None
  }
  if range == 0.0 && extend_is_pad(extend) {
    stops.push(ColorStop::{
      offset: last.offset + 1.0,
      palette_index: last.palette_index,
      alpha: last.alpha,
    })
    range = 1.0
  }
  let start_offset = first.offset
  let end_offset = if stops.length() > 1 {
    stops.at(stops.length() - 1).offset
  } else {
    first.offset
  }
  let mut c0 = c0_in
  let mut c1 = c1_in
  let mut r0 = r0_in
  let mut r1 = r1_in
  if range != 1.0 || start_offset != 0.0 {
    let v = color_trav_point_sub(c1, c0)
    let rd = r1 - r0
    let c0_off = color_trav_point_mul(v, start_offset)
    let c1_off = color_trav_point_mul(v, end_offset)
    c1 = color_trav_point_add(c0, c1_off)
    c0 = color_trav_point_add(c0, c0_off)
    r1 = r0 + rd * end_offset
    r0 = r0 + rd * start_offset
    color_trav_rescale_stops(stops, start_offset, 1.0 / range)
  }
  if range == 1.0 && start_offset == 0.0 {
    // No normalization needed.
  } else if range != 0.0 {
    // Already normalized above.
  }
  Some(RadialGradient(c0, r0, c1, r1, stops, extend))
}

///|
fn color_trav_make_sweep_brush(
  c0 : (Double, Double),
  start_angle : Double,
  end_angle : Double,
  stops : Array[ColorStop],
  extend : Extend,
) -> Brush? {
  if stops.is_empty() {
    return None
  }
  let mut start_deg = start_angle * 180.0 + 180.0
  let mut end_deg = end_angle * 180.0 + 180.0
  let sector = end_deg - start_deg
  color_trav_sort_color_stops(stops)
  let first = stops.at(0)
  let last = stops.at(stops.length() - 1)
  let mut range = last.offset - first.offset
  if range == 0.0 && !extend_is_pad(extend) {
    return None
  }
  if range == 0.0 && extend_is_pad(extend) {
    stops.push(ColorStop::{
      offset: last.offset + 1.0,
      palette_index: last.palette_index,
      alpha: last.alpha,
    })
    range = 1.0
  }
  let start_off = first.offset
  let end_off = stops.at(stops.length() - 1).offset
  // Scale angles based on original stop offsets.
  let start_angle_scaled = start_deg + sector * start_off
  let end_angle_scaled = start_deg + sector * end_off
  // Normalize stops.
  color_trav_rescale_stops(stops, start_off, 1.0 / range)
  start_deg = start_angle_scaled
  end_deg = end_angle_scaled
  // Convert CCW to clockwise degrees.
  start_deg = 360.0 - start_deg
  end_deg = 360.0 - end_deg
  if start_deg >= end_deg {
    let tmp = start_deg
    start_deg = end_deg
    end_deg = tmp
    // Reverse stops and mirror offsets.
    let n = stops.length()
    for i in 0..<(n / 2) {
      let a = stops.at(i)
      let b = stops.at(n - 1 - i)
      stops.set(i, b)
      stops.set(n - 1 - i, a)
    }
    for i in 0..<n {
      let s0 = stops.at(i)
      stops.set(i, ColorStop::{
        offset: 1.0 - s0.offset,
        palette_index: s0.palette_index,
        alpha: s0.alpha,
      })
    }
  }
  if start_deg == end_deg && !extend_is_pad(extend) {
    return None
  }
  Some(SweepGradient(c0, start_deg, end_deg, stops, extend))
}

///|
fn color_trav_transform_translate(dx : Double, dy : Double) -> Transform {
  let base = Transform::default()
  Transform::{ xx: base.xx, yx: base.yx, xy: base.xy, yy: base.yy, dx, dy }
}

///|
fn color_trav_transform_scale(sx : Double, sy : Double) -> Transform {
  Transform::{ xx: sx, yx: 0.0, xy: 0.0, yy: sy, dx: 0.0, dy: 0.0 }
}

///|
fn color_trav_transform_rotate(angle : Double) -> Transform {
  // Angle is encoded as "180° per 1.0 of value", in CCW direction.
  let theta = angle * COLOR_TRAV_PI
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  Transform::{ xx: c, yx: s, xy: -s, yy: c, dx: 0.0, dy: 0.0 }
}

///|
fn color_trav_transform_skew(x_angle : Double, y_angle : Double) -> Transform {
  let tx = @math.tan(x_angle * COLOR_TRAV_PI)
  let ty = @math.tan(y_angle * COLOR_TRAV_PI)
  Transform::{ xx: 1.0, yx: ty, xy: tx, yy: 1.0, dx: 0.0, dy: 0.0 }
}

///|
fn color_trav_transform_around_center(
  center : (Double, Double),
  inner : Transform,
) -> Transform {
  let (cx, cy) = center
  let t0 = color_trav_transform_translate(cx, cy)
  let t1 = color_trav_transform_translate(-cx, -cy)
  t0.mul(inner).mul(t1)
}

///|
priv struct ColorTravCtx {
  colr : BytesView
  base_glyph_list_off : Int
  layer_list_off : Int
  clip_list_off : Int?
  var_index_map_off : Int?
  var_store_off : Int?
  coords : ArrayView[NormalizedCoord]
}

///|
fn[P : ColorPainter] color_trav_traverse_paint(
  ctx : ColorTravCtx,
  paint_off : Int,
  stack : Array[Int],
  depth : Int,
  painter : P,
) -> Result[Unit, PaintError] {
  if depth >= COLOR_TRAV_MAX_DEPTH {
    return Err(DepthLimitExceeded)
  }
  if paint_off < 0 || paint_off >= ctx.colr.length() {
    return Err(ParseError)
  }
  if color_trav_stack_contains(stack, paint_off) {
    return Err(PaintCycleDetected)
  }
  stack.push(paint_off)
  let format = color_trav_read_u8(ctx.colr, paint_off).unwrap_or(-1)
  let result = match format {
    // PaintColrLayers
    1 => {
      let num_layers = color_trav_read_u8(ctx.colr, paint_off + 1).unwrap_or(-1)
      let first_layer = color_trav_read_u32_be_int(ctx.colr, paint_off + 2).unwrap_or(
        -1,
      )
      if num_layers < 0 || first_layer < 0 {
        Err(ParseError)
      } else {
        for i in 0..<num_layers {
          let layer_ix = first_layer + i
          match
            color_trav_layer_paint_offset(
              ctx.colr,
              ctx.layer_list_off,
              layer_ix,
            ) {
            None => return Err(ParseError)
            Some(layer_paint_off) =>
              match
                color_trav_traverse_paint(
                  ctx,
                  layer_paint_off,
                  stack,
                  depth + 1,
                  painter,
                ) {
                Err(e) => return Err(e)
                Ok(_) => ()
              }
          }
        }
        Ok(())
      }
    }
    // PaintSolid
    2 => {
      let palette_index = color_trav_read_u16_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let alpha = color_trav_read_f2dot14(ctx.colr, paint_off + 3).unwrap_or(
        1.0,
      )
      if palette_index < 0 {
        Err(ParseError)
      } else {
        ColorPainter::fill(painter, Solid(palette_index, alpha))
        Ok(())
      }
    }
    // PaintVarSolid
    3 => {
      let palette_index = color_trav_read_u16_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let alpha0 = color_trav_read_f2dot14(ctx.colr, paint_off + 3).unwrap_or(
        1.0,
      )
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 5).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if palette_index < 0 {
        Err(ParseError)
      } else {
        let d0 = color_trav_var_delta(
          ctx.colr,
          ctx.var_index_map_off,
          ctx.var_store_off,
          var_base,
          ctx.coords,
        )
        let alpha = color_trav_apply_f2dot14_delta(alpha0, d0)
        ColorPainter::fill(painter, Solid(palette_index, alpha))
        Ok(())
      }
    }
    // PaintLinearGradient
    4 => {
      let cl_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(-1)
      if cl_off <= 0 {
        Err(ParseError)
      } else {
        let x0 = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
        let y0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
        let x1 = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
        let y1 = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
        let x2 = color_trav_read_i16_be(ctx.colr, paint_off + 12).unwrap_or(0)
        let y2 = color_trav_read_i16_be(ctx.colr, paint_off + 14).unwrap_or(0)
        let abs_cl = paint_off + cl_off
        match
          color_trav_read_color_line(
            ctx.colr,
            abs_cl,
            false,
            ctx.coords,
            ctx.var_index_map_off,
            ctx.var_store_off,
          ) {
          None => Err(ParseError)
          Some((extend, stops0)) =>
            match
              color_trav_make_linear_brush(
                (x0.to_double(), y0.to_double()),
                (x1.to_double(), y1.to_double()),
                (x2.to_double(), y2.to_double()),
                stops0,
                extend,
              ) {
              None => Ok(())
              Some(brush) => {
                ColorPainter::fill(painter, brush)
                Ok(())
              }
            }
        }
      }
    }
    // PaintVarLinearGradient
    5 => {
      let cl_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(-1)
      if cl_off <= 0 {
        Err(ParseError)
      } else {
        let x0_0 = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
        let y0_0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
        let x1_0 = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
        let y1_0 = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
        let x2_0 = color_trav_read_i16_be(ctx.colr, paint_off + 12).unwrap_or(0)
        let y2_0 = color_trav_read_i16_be(ctx.colr, paint_off + 14).unwrap_or(0)
        let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 16).unwrap_or(
          COLOR_TRAV_NO_VARIATION_DELTAS,
        )
        let x0 = color_trav_apply_fword_delta(
          x0_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let y0 = color_trav_apply_fword_delta(
          y0_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let x1 = color_trav_apply_fword_delta(
          x1_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let y1 = color_trav_apply_fword_delta(
          y1_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 3),
            ctx.coords,
          ),
        )
        let x2 = color_trav_apply_fword_delta(
          x2_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 4),
            ctx.coords,
          ),
        )
        let y2 = color_trav_apply_fword_delta(
          y2_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 5),
            ctx.coords,
          ),
        )
        let abs_cl = paint_off + cl_off
        match
          color_trav_read_color_line(
            ctx.colr,
            abs_cl,
            true,
            ctx.coords,
            ctx.var_index_map_off,
            ctx.var_store_off,
          ) {
          None => Err(ParseError)
          Some((extend, stops0)) =>
            match
              color_trav_make_linear_brush(
                (x0, y0),
                (x1, y1),
                (x2, y2),
                stops0,
                extend,
              ) {
              None => Ok(())
              Some(brush) => {
                ColorPainter::fill(painter, brush)
                Ok(())
              }
            }
        }
      }
    }
    // PaintRadialGradient
    6 => {
      let cl_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(-1)
      if cl_off <= 0 {
        Err(ParseError)
      } else {
        let x0 = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
        let y0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
        let r0 = color_trav_read_u16_be(ctx.colr, paint_off + 8).unwrap_or(0)
        let x1 = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
        let y1 = color_trav_read_i16_be(ctx.colr, paint_off + 12).unwrap_or(0)
        let r1 = color_trav_read_u16_be(ctx.colr, paint_off + 14).unwrap_or(0)
        let abs_cl = paint_off + cl_off
        match
          color_trav_read_color_line(
            ctx.colr,
            abs_cl,
            false,
            ctx.coords,
            ctx.var_index_map_off,
            ctx.var_store_off,
          ) {
          None => Err(ParseError)
          Some((extend, stops0)) =>
            match
              color_trav_make_radial_brush(
                (x0.to_double(), y0.to_double()),
                r0.to_double(),
                (x1.to_double(), y1.to_double()),
                r1.to_double(),
                stops0,
                extend,
              ) {
              None => Ok(())
              Some(brush) => {
                ColorPainter::fill(painter, brush)
                Ok(())
              }
            }
        }
      }
    }
    // PaintVarRadialGradient
    7 => {
      let cl_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(-1)
      if cl_off <= 0 {
        Err(ParseError)
      } else {
        let x0_0 = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
        let y0_0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
        let r0_0 = color_trav_read_u16_be(ctx.colr, paint_off + 8).unwrap_or(0)
        let x1_0 = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
        let y1_0 = color_trav_read_i16_be(ctx.colr, paint_off + 12).unwrap_or(0)
        let r1_0 = color_trav_read_u16_be(ctx.colr, paint_off + 14).unwrap_or(0)
        let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 16).unwrap_or(
          COLOR_TRAV_NO_VARIATION_DELTAS,
        )
        let x0 = color_trav_apply_fword_delta(
          x0_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let y0 = color_trav_apply_fword_delta(
          y0_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let r0 = color_trav_apply_ufword_delta(
          r0_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let x1 = color_trav_apply_fword_delta(
          x1_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 3),
            ctx.coords,
          ),
        )
        let y1 = color_trav_apply_fword_delta(
          y1_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 4),
            ctx.coords,
          ),
        )
        let r1 = color_trav_apply_ufword_delta(
          r1_0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 5),
            ctx.coords,
          ),
        )
        let abs_cl = paint_off + cl_off
        match
          color_trav_read_color_line(
            ctx.colr,
            abs_cl,
            true,
            ctx.coords,
            ctx.var_index_map_off,
            ctx.var_store_off,
          ) {
          None => Err(ParseError)
          Some((extend, stops0)) =>
            match
              color_trav_make_radial_brush(
                (x0, y0),
                r0,
                (x1, y1),
                r1,
                stops0,
                extend,
              ) {
              None => Ok(())
              Some(brush) => {
                ColorPainter::fill(painter, brush)
                Ok(())
              }
            }
        }
      }
    }
    // PaintSweepGradient
    8 => {
      let cl_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(-1)
      if cl_off <= 0 {
        Err(ParseError)
      } else {
        let cx = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
        let cy = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
        let start_angle = color_trav_read_f2dot14(ctx.colr, paint_off + 8).unwrap_or(
          0.0,
        )
        let end_angle = color_trav_read_f2dot14(ctx.colr, paint_off + 10).unwrap_or(
          0.0,
        )
        let abs_cl = paint_off + cl_off
        match
          color_trav_read_color_line(
            ctx.colr,
            abs_cl,
            false,
            ctx.coords,
            ctx.var_index_map_off,
            ctx.var_store_off,
          ) {
          None => Err(ParseError)
          Some((extend, stops0)) =>
            match
              color_trav_make_sweep_brush(
                (cx.to_double(), cy.to_double()),
                start_angle,
                end_angle,
                stops0,
                extend,
              ) {
              None => Ok(())
              Some(brush) => {
                ColorPainter::fill(painter, brush)
                Ok(())
              }
            }
        }
      }
    }
    // PaintVarSweepGradient
    9 => {
      let cl_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(-1)
      if cl_off <= 0 {
        Err(ParseError)
      } else {
        let cx0 = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
        let cy0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
        let start0 = color_trav_read_f2dot14(ctx.colr, paint_off + 8).unwrap_or(
          0.0,
        )
        let end0 = color_trav_read_f2dot14(ctx.colr, paint_off + 10).unwrap_or(
          0.0,
        )
        let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 12).unwrap_or(
          COLOR_TRAV_NO_VARIATION_DELTAS,
        )
        let cx = color_trav_apply_fword_delta(
          cx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let cy = color_trav_apply_fword_delta(
          cy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let start_angle = color_trav_apply_f2dot14_delta(
          start0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let end_angle = color_trav_apply_f2dot14_delta(
          end0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 3),
            ctx.coords,
          ),
        )
        let abs_cl = paint_off + cl_off
        match
          color_trav_read_color_line(
            ctx.colr,
            abs_cl,
            true,
            ctx.coords,
            ctx.var_index_map_off,
            ctx.var_store_off,
          ) {
          None => Err(ParseError)
          Some((extend, stops0)) =>
            match
              color_trav_make_sweep_brush(
                (cx, cy),
                start_angle,
                end_angle,
                stops0,
                extend,
              ) {
              None => Ok(())
              Some(brush) => {
                ColorPainter::fill(painter, brush)
                Ok(())
              }
            }
        }
      }
    }
    // PaintGlyph
    10 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let gid_i = color_trav_read_u16_be(ctx.colr, paint_off + 4).unwrap_or(-1)
      if sub_off <= 0 || gid_i < 0 {
        Err(ParseError)
      } else {
        let gid = GlyphId::new(gid_i.to_uint16())
        ColorPainter::push_clip_glyph(painter, gid)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_clip(painter)
        r
      }
    }
    // PaintColrGlyph
    11 => {
      let gid_i = color_trav_read_u16_be(ctx.colr, paint_off + 1).unwrap_or(-1)
      if gid_i < 0 {
        Err(ParseError)
      } else {
        let target = GlyphId::new(gid_i.to_uint16())
        match ColorPainter::paint_cached_color_glyph(painter, target) {
          Err(e) => Err(e)
          Ok(PaintCachedColorGlyph::Ok) => Ok(())
          Ok(PaintCachedColorGlyph::Unimplemented) =>
            match
              color_trav_base_paint_offset(
                ctx.colr,
                ctx.base_glyph_list_off,
                target,
              ) {
              None => Err(GlyphNotFound(target))
              Some(target_off) => {
                let mut pushed = false
                match ctx.clip_list_off {
                  None => ()
                  Some(clip_off) =>
                    match
                      color_trav_clip_box(
                        ctx.colr,
                        clip_off,
                        target,
                        ctx.coords,
                        ctx.var_index_map_off,
                        ctx.var_store_off,
                      ) {
                      None => ()
                      Some(bb) => {
                        ColorPainter::push_clip_box(painter, bb)
                        pushed = true
                      }
                    }
                }
                let r = color_trav_traverse_paint(
                  ctx,
                  target_off,
                  stack,
                  depth + 1,
                  painter,
                )
                if pushed {
                  ColorPainter::pop_clip(painter)
                }
                r
              }
            }
        }
      }
    }
    // PaintTransform
    12 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let t_off = color_trav_read_u24_be(ctx.colr, paint_off + 4).unwrap_or(-1)
      if sub_off <= 0 || t_off <= 0 {
        Err(ParseError)
      } else {
        let abs_t = paint_off + t_off
        let xx = color_trav_read_fixed_16_16(ctx.colr, abs_t).unwrap_or(1.0)
        let yx = color_trav_read_fixed_16_16(ctx.colr, abs_t + 4).unwrap_or(0.0)
        let xy = color_trav_read_fixed_16_16(ctx.colr, abs_t + 8).unwrap_or(0.0)
        let yy = color_trav_read_fixed_16_16(ctx.colr, abs_t + 12).unwrap_or(
          1.0,
        )
        let dx = color_trav_read_fixed_16_16(ctx.colr, abs_t + 16).unwrap_or(
          0.0,
        )
        let dy = color_trav_read_fixed_16_16(ctx.colr, abs_t + 20).unwrap_or(
          0.0,
        )
        let t = Transform::{ xx, yx, xy, yy, dx, dy }
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarTransform
    13 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let t_off = color_trav_read_u24_be(ctx.colr, paint_off + 4).unwrap_or(-1)
      if sub_off <= 0 || t_off <= 0 {
        Err(ParseError)
      } else {
        let abs_t = paint_off + t_off
        let xx0 = color_trav_read_fixed_16_16(ctx.colr, abs_t).unwrap_or(1.0)
        let yx0 = color_trav_read_fixed_16_16(ctx.colr, abs_t + 4).unwrap_or(
          0.0,
        )
        let xy0 = color_trav_read_fixed_16_16(ctx.colr, abs_t + 8).unwrap_or(
          0.0,
        )
        let yy0 = color_trav_read_fixed_16_16(ctx.colr, abs_t + 12).unwrap_or(
          1.0,
        )
        let dx0 = color_trav_read_fixed_16_16(ctx.colr, abs_t + 16).unwrap_or(
          0.0,
        )
        let dy0 = color_trav_read_fixed_16_16(ctx.colr, abs_t + 20).unwrap_or(
          0.0,
        )
        let var_base = color_trav_read_u32_be(ctx.colr, abs_t + 24).unwrap_or(
          COLOR_TRAV_NO_VARIATION_DELTAS,
        )
        let xx = color_trav_apply_fixed_delta(
          xx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let yx = color_trav_apply_fixed_delta(
          yx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let xy = color_trav_apply_fixed_delta(
          xy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let yy = color_trav_apply_fixed_delta(
          yy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 3),
            ctx.coords,
          ),
        )
        let dx = color_trav_apply_fixed_delta(
          dx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 4),
            ctx.coords,
          ),
        )
        let dy = color_trav_apply_fixed_delta(
          dy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 5),
            ctx.coords,
          ),
        )
        let t = Transform::{ xx, yx, xy, yy, dx, dy }
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintTranslate
    14 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let dx = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
      let dy = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let t = color_trav_transform_translate(dx.to_double(), dy.to_double())
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarTranslate
    15 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let dx0 = color_trav_read_i16_be(ctx.colr, paint_off + 4).unwrap_or(0)
      let dy0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 8).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let dx = color_trav_apply_fword_delta(
          dx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let dy = color_trav_apply_fword_delta(
          dy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let t = color_trav_transform_translate(dx, dy)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintScale
    16 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let sx = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      let sy = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(1.0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let t = color_trav_transform_scale(sx, sy)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarScale
    17 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let sx0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      let sy0 = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(1.0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 8).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let sx = color_trav_apply_f2dot14_delta(
          sx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let sy = color_trav_apply_f2dot14_delta(
          sy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let t = color_trav_transform_scale(sx, sy)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintScaleAroundCenter
    18 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let sx = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      let sy = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(1.0)
      let cx = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      let cy = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let inner = color_trav_transform_scale(sx, sy)
        let t = color_trav_transform_around_center(
          (cx.to_double(), cy.to_double()),
          inner,
        )
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarScaleAroundCenter
    19 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let sx0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      let sy0 = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(1.0)
      let cx0 = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      let cy0 = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 12).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let sx = color_trav_apply_f2dot14_delta(
          sx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let sy = color_trav_apply_f2dot14_delta(
          sy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let cx = color_trav_apply_fword_delta(
          cx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let cy = color_trav_apply_fword_delta(
          cy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 3),
            ctx.coords,
          ),
        )
        let inner = color_trav_transform_scale(sx, sy)
        let t = color_trav_transform_around_center((cx, cy), inner)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintScaleUniform
    20 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let s = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let t = color_trav_transform_scale(s, s)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarScaleUniform
    21 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let s0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 6).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let s = color_trav_apply_f2dot14_delta(
          s0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            var_base,
            ctx.coords,
          ),
        )
        let t = color_trav_transform_scale(s, s)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintScaleUniformAroundCenter
    22 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let s = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      let cx = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
      let cy = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let inner = color_trav_transform_scale(s, s)
        let t = color_trav_transform_around_center(
          (cx.to_double(), cy.to_double()),
          inner,
        )
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarScaleUniformAroundCenter
    23 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let s0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(1.0)
      let cx0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
      let cy0 = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 10).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let s = color_trav_apply_f2dot14_delta(
          s0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let cx = color_trav_apply_fword_delta(
          cx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let cy = color_trav_apply_fword_delta(
          cy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let inner = color_trav_transform_scale(s, s)
        let t = color_trav_transform_around_center((cx, cy), inner)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintRotate
    24 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let angle = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(
        0.0,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let t = color_trav_transform_rotate(angle)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarRotate
    25 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let angle0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(
        0.0,
      )
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 6).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let angle = color_trav_apply_f2dot14_delta(
          angle0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            var_base,
            ctx.coords,
          ),
        )
        let t = color_trav_transform_rotate(angle)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintRotateAroundCenter
    26 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let angle = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(
        0.0,
      )
      let cx = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
      let cy = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let inner = color_trav_transform_rotate(angle)
        let t = color_trav_transform_around_center(
          (cx.to_double(), cy.to_double()),
          inner,
        )
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarRotateAroundCenter
    27 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let angle0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(
        0.0,
      )
      let cx0 = color_trav_read_i16_be(ctx.colr, paint_off + 6).unwrap_or(0)
      let cy0 = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 10).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let angle = color_trav_apply_f2dot14_delta(
          angle0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let cx = color_trav_apply_fword_delta(
          cx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let cy = color_trav_apply_fword_delta(
          cy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let inner = color_trav_transform_rotate(angle)
        let t = color_trav_transform_around_center((cx, cy), inner)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintSkew
    28 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let ax = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(0.0)
      let ay = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(0.0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let t = color_trav_transform_skew(ax, ay)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarSkew
    29 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let ax0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(0.0)
      let ay0 = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(0.0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 8).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let ax = color_trav_apply_f2dot14_delta(
          ax0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let ay = color_trav_apply_f2dot14_delta(
          ay0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let t = color_trav_transform_skew(ax, ay)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintSkewAroundCenter
    30 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let ax = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(0.0)
      let ay = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(0.0)
      let cx = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      let cy = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let inner = color_trav_transform_skew(ax, ay)
        let t = color_trav_transform_around_center(
          (cx.to_double(), cy.to_double()),
          inner,
        )
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintVarSkewAroundCenter
    31 => {
      let sub_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let ax0 = color_trav_read_f2dot14(ctx.colr, paint_off + 4).unwrap_or(0.0)
      let ay0 = color_trav_read_f2dot14(ctx.colr, paint_off + 6).unwrap_or(0.0)
      let cx0 = color_trav_read_i16_be(ctx.colr, paint_off + 8).unwrap_or(0)
      let cy0 = color_trav_read_i16_be(ctx.colr, paint_off + 10).unwrap_or(0)
      let var_base = color_trav_read_u32_be(ctx.colr, paint_off + 12).unwrap_or(
        COLOR_TRAV_NO_VARIATION_DELTAS,
      )
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let ax = color_trav_apply_f2dot14_delta(
          ax0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 0),
            ctx.coords,
          ),
        )
        let ay = color_trav_apply_f2dot14_delta(
          ay0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 1),
            ctx.coords,
          ),
        )
        let cx = color_trav_apply_fword_delta(
          cx0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 2),
            ctx.coords,
          ),
        )
        let cy = color_trav_apply_fword_delta(
          cy0,
          color_trav_var_delta(
            ctx.colr,
            ctx.var_index_map_off,
            ctx.var_store_off,
            color_trav_var_index_add(var_base, 3),
            ctx.coords,
          ),
        )
        let inner = color_trav_transform_skew(ax, ay)
        let t = color_trav_transform_around_center((cx, cy), inner)
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          ctx,
          abs_sub,
          stack,
          depth + 1,
          painter,
        )
        ColorPainter::pop_transform(painter)
        r
      }
    }
    // PaintComposite
    32 => {
      let source_off = color_trav_read_u24_be(ctx.colr, paint_off + 1).unwrap_or(
        -1,
      )
      let mode_raw = color_trav_read_u8(ctx.colr, paint_off + 4).unwrap_or(-1)
      let backdrop_off = color_trav_read_u24_be(ctx.colr, paint_off + 5).unwrap_or(
        -1,
      )
      if source_off <= 0 || backdrop_off <= 0 || mode_raw < 0 {
        Err(ParseError)
      } else {
        let src_over = composite_mode_from_u8(3)
        let mode = composite_mode_from_u8(mode_raw)
        ColorPainter::push_layer(painter, src_over)
        let abs_backdrop = paint_off + backdrop_off
        match
          color_trav_traverse_paint(
            ctx,
            abs_backdrop,
            stack,
            depth + 1,
            painter,
          ) {
          Err(e) => {
            ColorPainter::pop_layer_with_mode(painter, src_over)
            Err(e)
          }
          Ok(_) => {
            ColorPainter::push_layer(painter, mode)
            let abs_source = paint_off + source_off
            let r = color_trav_traverse_paint(
              ctx,
              abs_source,
              stack,
              depth + 1,
              painter,
            )
            ColorPainter::pop_layer_with_mode(painter, mode)
            ColorPainter::pop_layer_with_mode(painter, src_over)
            r
          }
        }
      }
    }
    _ => Err(UnsupportedPaintFormat(format))
  }
  stack.pop() |> ignore
  result
}

///|
pub fn[P : ColorPainter] FontRef::paint_colr_v1(
  self : FontRef,
  glyph_id : GlyphId,
  painter : P,
) -> Result[Unit, PaintError] {
  let loc = LocationRef::default()
  self.paint_colr_v1_at(glyph_id, loc, painter)
}

///|
pub fn[P : ColorPainter] FontRef::paint_colr_v1_at(
  self : FontRef,
  glyph_id : GlyphId,
  location : LocationRef,
  painter : P,
) -> Result[Unit, PaintError] {
  let colr = match self.table(COLOR_TRAV_TAG_COLR) {
    None => return Err(GlyphNotFound(glyph_id))
    Some(v) => v
  }
  let version = color_trav_read_u16_be(colr, 0).unwrap_or(-1)
  if version != 1 || colr.length() < 34 {
    return Err(ParseError)
  }
  let base_glyph_list_off = color_trav_read_u32_be_int(colr, 14).unwrap_or(-1)
  let layer_list_off = color_trav_read_u32_be_int(colr, 18).unwrap_or(-1)
  let clip_list_off0 = color_trav_read_u32_be_int(colr, 22).unwrap_or(0)
  let var_index_map_off0 = color_trav_read_u32_be_int(colr, 26).unwrap_or(0)
  let var_store_off0 = color_trav_read_u32_be_int(colr, 30).unwrap_or(0)
  if base_glyph_list_off <= 0 || layer_list_off <= 0 {
    return Err(ParseError)
  }
  let clip_list_off = if clip_list_off0 > 0 && clip_list_off0 < colr.length() {
    Some(clip_list_off0)
  } else {
    None
  }
  let var_index_map_off = if var_index_map_off0 > 0 &&
    var_index_map_off0 < colr.length() {
    Some(var_index_map_off0)
  } else {
    None
  }
  let var_store_off = if var_store_off0 > 0 && var_store_off0 < colr.length() {
    Some(var_store_off0)
  } else {
    None
  }
  let coords = location.effective_coords()
  let ctx = ColorTravCtx::{
    colr,
    base_glyph_list_off,
    layer_list_off,
    clip_list_off,
    var_index_map_off,
    var_store_off,
    coords,
  }
  match color_trav_base_paint_offset(colr, base_glyph_list_off, glyph_id) {
    None => Err(GlyphNotFound(glyph_id))
    Some(root_paint_off) => {
      let mut pushed = false
      match clip_list_off {
        None => ()
        Some(clip_off) =>
          match
            color_trav_clip_box(
              colr, clip_off, glyph_id, coords, var_index_map_off, var_store_off,
            ) {
            None => ()
            Some(bb) => {
              ColorPainter::push_clip_box(painter, bb)
              pushed = true
            }
          }
      }
      let stack : Array[Int] = Array::new()
      let r = color_trav_traverse_paint(ctx, root_paint_off, stack, 0, painter)
      if pushed {
        ColorPainter::pop_clip(painter)
      }
      r
    }
  }
}
