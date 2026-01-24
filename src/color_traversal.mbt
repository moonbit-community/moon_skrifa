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
/// - Formats: PaintColrLayers(1), PaintSolid(2), PaintGlyph(10), PaintColrGlyph(11),
///   PaintTransform(12), PaintTranslate(14), PaintComposite(32)
/// - No gradients, no variable paints, no clip boxes
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
fn[P : ColorPainter] color_trav_traverse_paint(
  font : FontRef,
  colr : BytesView,
  base_glyph_list_off : Int,
  layer_list_off : Int,
  paint_off : Int,
  stack : Array[Int],
  depth : Int,
  painter : P,
) -> Result[Unit, PaintError] {
  if depth >= COLOR_TRAV_MAX_DEPTH {
    return Err(DepthLimitExceeded)
  }
  if paint_off < 0 || paint_off >= colr.length() {
    return Err(ParseError)
  }
  if color_trav_stack_contains(stack, paint_off) {
    return Err(PaintCycleDetected)
  }
  stack.push(paint_off)
  let format = color_trav_read_u8(colr, paint_off).unwrap_or(-1)
  let result = match format {
    // PaintColrLayers
    1 => {
      let num_layers = color_trav_read_u8(colr, paint_off + 1).unwrap_or(-1)
      let first_layer = color_trav_read_u32_be_int(colr, paint_off + 2).unwrap_or(
        -1,
      )
      if num_layers < 0 || first_layer < 0 {
        Err(ParseError)
      } else {
        for i in 0..<num_layers {
          let layer_ix = first_layer + i
          match color_trav_layer_paint_offset(colr, layer_list_off, layer_ix) {
            None => return Err(ParseError)
            Some(layer_paint_off) =>
              match
                color_trav_traverse_paint(
                  font,
                  colr,
                  base_glyph_list_off,
                  layer_list_off,
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
      let palette_index = color_trav_read_u16_be(colr, paint_off + 1).unwrap_or(
        -1,
      )
      let alpha = color_trav_read_f2dot14(colr, paint_off + 3).unwrap_or(1.0)
      if palette_index < 0 {
        Err(ParseError)
      } else {
        ColorPainter::fill(painter, Solid(palette_index, alpha))
        Ok(())
      }
    }
    // PaintGlyph
    10 => {
      let sub_off = color_trav_read_u24_be(colr, paint_off + 1).unwrap_or(-1)
      let gid = color_trav_read_u16_be(colr, paint_off + 4).unwrap_or(-1)
      if sub_off <= 0 || gid < 0 {
        Err(ParseError)
      } else {
        ColorPainter::push_clip_glyph(painter, gid.reinterpret_as_uint())
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          font,
          colr,
          base_glyph_list_off,
          layer_list_off,
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
      let gid = color_trav_read_u16_be(colr, paint_off + 1).unwrap_or(-1)
      if gid < 0 {
        Err(ParseError)
      } else {
        let target = gid.reinterpret_as_uint()
        match ColorPainter::paint_cached_color_glyph(painter, target) {
          Err(e) => Err(e)
          Ok(PaintCachedColorGlyph::Ok) => Ok(())
          Ok(PaintCachedColorGlyph::Unimplemented) =>
            match
              color_trav_base_paint_offset(colr, base_glyph_list_off, target) {
              None => Err(GlyphNotFound(target))
              Some(target_off) =>
                color_trav_traverse_paint(
                  font,
                  colr,
                  base_glyph_list_off,
                  layer_list_off,
                  target_off,
                  stack,
                  depth + 1,
                  painter,
                )
            }
        }
      }
    }
    // PaintTransform
    12 => {
      let sub_off = color_trav_read_u24_be(colr, paint_off + 1).unwrap_or(-1)
      let t_off = color_trav_read_u24_be(colr, paint_off + 4).unwrap_or(-1)
      if sub_off <= 0 || t_off <= 0 {
        Err(ParseError)
      } else {
        let abs_t = paint_off + t_off
        let xx = color_trav_read_fixed_16_16(colr, abs_t).unwrap_or(1.0)
        let yx = color_trav_read_fixed_16_16(colr, abs_t + 4).unwrap_or(0.0)
        let xy = color_trav_read_fixed_16_16(colr, abs_t + 8).unwrap_or(0.0)
        let yy = color_trav_read_fixed_16_16(colr, abs_t + 12).unwrap_or(1.0)
        let dx = color_trav_read_fixed_16_16(colr, abs_t + 16).unwrap_or(0.0)
        let dy = color_trav_read_fixed_16_16(colr, abs_t + 20).unwrap_or(0.0)
        let t = Transform::{ xx, yx, xy, yy, dx, dy }
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          font,
          colr,
          base_glyph_list_off,
          layer_list_off,
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
      let sub_off = color_trav_read_u24_be(colr, paint_off + 1).unwrap_or(-1)
      let dx = color_trav_read_i16_be(colr, paint_off + 4).unwrap_or(0)
      let dy = color_trav_read_i16_be(colr, paint_off + 6).unwrap_or(0)
      if sub_off <= 0 {
        Err(ParseError)
      } else {
        let base = Transform::default()
        let t = Transform::{
          xx: base.xx,
          yx: base.yx,
          xy: base.xy,
          yy: base.yy,
          dx: dx.to_double(),
          dy: dy.to_double(),
        }
        ColorPainter::push_transform(painter, t)
        let abs_sub = paint_off + sub_off
        let r = color_trav_traverse_paint(
          font,
          colr,
          base_glyph_list_off,
          layer_list_off,
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
      let source_off = color_trav_read_u24_be(colr, paint_off + 1).unwrap_or(-1)
      let mode_raw = color_trav_read_u8(colr, paint_off + 4).unwrap_or(-1)
      let backdrop_off = color_trav_read_u24_be(colr, paint_off + 5).unwrap_or(
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
            font,
            colr,
            base_glyph_list_off,
            layer_list_off,
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
              font,
              colr,
              base_glyph_list_off,
              layer_list_off,
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
  let colr = match self.table(COLOR_TRAV_TAG_COLR) {
    None => return Err(GlyphNotFound(glyph_id))
    Some(v) => v
  }
  let version = color_trav_read_u16_be(colr, 0).unwrap_or(-1)
  if version != 1 {
    return Err(ParseError)
  }
  if colr.length() < 34 {
    return Err(ParseError)
  }
  let base_glyph_list_off = color_trav_read_u32_be_int(colr, 14).unwrap_or(-1)
  let layer_list_off = color_trav_read_u32_be_int(colr, 18).unwrap_or(-1)
  if base_glyph_list_off <= 0 || layer_list_off <= 0 {
    return Err(ParseError)
  }
  let base_off = base_glyph_list_off
  let layer_off = layer_list_off
  match color_trav_base_paint_offset(colr, base_off, glyph_id) {
    None => Err(GlyphNotFound(glyph_id))
    Some(root_paint_off) => {
      let stack : Array[Int] = Array::new()
      color_trav_traverse_paint(
        self, colr, base_off, layer_off, root_paint_off, stack, 0, painter,
      )
    }
  }
}
