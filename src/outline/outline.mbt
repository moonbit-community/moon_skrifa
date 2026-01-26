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
/// Outline module (skeleton).
///
/// Ported from `fontations/skrifa/src/outline/*` (Apache-2.0 OR MIT).
///
/// This package is being incrementally refactored toward API/behavior parity
/// with upstream `skrifa::outline`.
const TAG_GLYF : UInt = 0x676C7966 // "glyf"

///|
const TAG_CFF : UInt = 0x43464620 // "CFF "

///|
const TAG_CFF2 : UInt = 0x43464632 // "CFF2"

///|
const TAG_FPGM : UInt = 0x6670676D // "fpgm"

///|
const TAG_PREP : UInt = 0x70726570 // "prep"

///|
/// Source format for an outline glyph.
pub(all) enum OutlineGlyphFormat {
  Glyf
  Cff
  Cff2
}

///|
/// Specifies the hinting strategy for memory size calculations.
pub(all) enum Hinting {
  None_
  Embedded
}

///|
pub fn Hinting::default() -> Hinting {
  Hinting::None_
}

///|
pub fn Hinting::none() -> Hinting {
  Hinting::None_
}

///|
/// Information and adjusted metrics generated while drawing an outline glyph.
pub struct AdjustedMetrics {
  has_overlaps : Bool
  lsb : Double?
  advance_width : Double?
}

///|
pub fn AdjustedMetrics::default() -> AdjustedMetrics {
  AdjustedMetrics::{ has_overlaps: false, lsb: None, advance_width: None }
}

///|
pub struct OutlineGlyphCollection {
  font : @moon_skrifa.FontRef
  priv kind : OutlineGlyphFormat?
}

///|
pub fn OutlineGlyphCollection::new(
  font : @moon_skrifa.FontRef,
) -> OutlineGlyphCollection {
  // Upstream selection order: glyf first, then CFF2, then CFF.
  let kind = if font.table(TAG_GLYF) is Some(_) {
    Some(OutlineGlyphFormat::Glyf)
  } else if font.table(TAG_CFF2) is Some(_) {
    Some(OutlineGlyphFormat::Cff2)
  } else if font.table(TAG_CFF) is Some(_) {
    Some(OutlineGlyphFormat::Cff)
  } else {
    None
  }
  OutlineGlyphCollection::{ font, kind }
}

///|
pub fn OutlineGlyphCollection::from_font(
  font : @moon_skrifa.FontRef,
) -> OutlineGlyphCollection {
  OutlineGlyphCollection::new(font)
}

///|
/// Creates a new outline collection for the given font and outline format.
///
/// Returns `None` if the font does not contain outlines in the requested
/// format.
pub fn OutlineGlyphCollection::with_format(
  font : @moon_skrifa.FontRef,
  format : OutlineGlyphFormat,
) -> OutlineGlyphCollection? {
  match format {
    OutlineGlyphFormat::Glyf =>
      if font.table(TAG_GLYF) is Some(_) {
        Some(OutlineGlyphCollection::{ font, kind: Some(format) })
      } else {
        None
      }
    OutlineGlyphFormat::Cff =>
      if font.table(TAG_CFF) is Some(_) {
        Some(OutlineGlyphCollection::{ font, kind: Some(format) })
      } else {
        None
      }
    OutlineGlyphFormat::Cff2 =>
      if font.table(TAG_CFF2) is Some(_) {
        Some(OutlineGlyphCollection::{ font, kind: Some(format) })
      } else {
        None
      }
  }
}

///|
priv enum DrawInstance {
  Unhinted(@moon_skrifa.Size, @moon_skrifa.LocationRef)
  Hinted(HintingInstance, Bool)
}

///|
/// Options that define how a glyph outline is drawn to a pen.
pub struct DrawSettings {
  priv instance : DrawInstance
  priv memory : Array[Byte]?
  priv path_style : PathStyle
}

///|
pub fn DrawSettings::default() -> DrawSettings {
  DrawSettings::unhinted(
    @moon_skrifa.Size::unscaled(),
    @moon_skrifa.LocationRef::default(),
  )
}

///|
pub fn DrawSettings::unhinted(
  size : @moon_skrifa.Size,
  location : @moon_skrifa.LocationRef,
) -> DrawSettings {
  DrawSettings::{
    instance: DrawInstance::Unhinted(size, location),
    memory: None,
    path_style: PathStyle::default(),
  }
}

///|
pub fn DrawSettings::hinted(
  instance : HintingInstance,
  is_pedantic : Bool,
) -> DrawSettings {
  DrawSettings::{
    instance: DrawInstance::Hinted(instance, is_pedantic),
    memory: None,
    path_style: PathStyle::default(),
  }
}

///|
pub fn DrawSettings::with_memory(
  self : DrawSettings,
  memory : Array[Byte]?,
) -> DrawSettings {
  DrawSettings::{ instance: self.instance, memory, path_style: self.path_style }
}

///|
pub fn DrawSettings::with_path_style(
  self : DrawSettings,
  path_style : PathStyle,
) -> DrawSettings {
  DrawSettings::{ instance: self.instance, memory: self.memory, path_style }
}

///|
pub fn DrawSettings::path_style(self : DrawSettings) -> PathStyle {
  self.path_style
}

///|
pub fn DrawSettings::size(self : DrawSettings) -> @moon_skrifa.Size {
  match self.instance {
    DrawInstance::Unhinted(size, _) => size
    DrawInstance::Hinted(h, _) => h.size()
  }
}

///|
pub fn DrawSettings::location(self : DrawSettings) -> @moon_skrifa.LocationRef {
  match self.instance {
    DrawInstance::Unhinted(_, loc) => loc
    DrawInstance::Hinted(h, _) => h.location()
  }
}

///|
pub fn DrawSettings::hinting_instance(self : DrawSettings) -> HintingInstance? {
  match self.instance {
    DrawInstance::Hinted(h, _) => Some(h)
    _ => None
  }
}

///|
pub fn DrawSettings::is_pedantic(self : DrawSettings) -> Bool {
  match self.instance {
    DrawInstance::Hinted(_, p) => p
    _ => false
  }
}

///|
/// A scalable glyph outline.
///
/// This can be sourced from the `glyf`, `CFF` or `CFF2` tables.
pub struct OutlineGlyph {
  priv font : @moon_skrifa.FontRef
  priv glyph_id : @moon_skrifa.GlyphId
  priv kind : OutlineGlyphFormat
}

///|
pub fn OutlineGlyph::format(self : OutlineGlyph) -> OutlineGlyphFormat {
  self.kind
}

///|
pub fn OutlineGlyph::glyph_id(self : OutlineGlyph) -> @moon_skrifa.GlyphId {
  self.glyph_id
}

///|
/// Returns a value indicating if the outline may contain overlapping contours
/// or components.
///
/// For CFF outlines, returns `None` since this information is unavailable.
pub fn OutlineGlyph::has_overlaps(self : OutlineGlyph) -> Bool? {
  match self.kind {
    OutlineGlyphFormat::Glyf =>
      Some(glyf_has_overlaps(self.font, self.glyph_id).unwrap_or(false))
    _ => None
  }
}

///|
/// Returns a value indicating whether the outline has hinting instructions.
///
/// For CFF outlines, returns `None` since this is unknown prior to loading the
/// outline.
pub fn OutlineGlyph::has_hinting(self : OutlineGlyph) -> Bool? {
  match self.kind {
    OutlineGlyphFormat::Glyf =>
      Some(glyf_has_hinting(self.font, self.glyph_id).unwrap_or(false))
    _ => None
  }
}

///|
/// Returns the size (in bytes) of the temporary memory required to draw this
/// outline.
///
/// This port currently returns 0 until the full glyf scaler/hinter is
/// implemented.
pub fn OutlineGlyph::draw_memory_size(
  self : OutlineGlyph,
  _hinting : Hinting,
) -> Int {
  self |> ignore
  0
}

///|
/// Draws the outline glyph with the given settings and emits the resulting
/// path commands to the specified pen.
pub fn[P : OutlinePen] OutlineGlyph::draw(
  self : OutlineGlyph,
  settings : DrawSettings,
  pen : P,
) -> Result[AdjustedMetrics, DrawError] {
  if settings.hinting_instance() is Some(_) &&
    settings.path_style() is PathStyle::HarfBuzz {
    return Err(DrawError::HarfBuzzHintingUnsupported)
  }
  if self.kind is OutlineGlyphFormat::Glyf &&
    settings.path_style() is PathStyle::FreeType &&
    settings.hinting_instance() is Some(h) &&
    h.is_enabled() {
    let (metrics, path) = match
      h.hinted_glyf_path(self, settings.is_pedantic()) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    for e in path.iter() {
      match e {
        PathElement::MoveTo(x, y) => OutlinePen::move_to(pen, x, y)
        PathElement::LineTo(x, y) => OutlinePen::line_to(pen, x, y)
        PathElement::QuadTo(cx0, cy0, x, y) =>
          OutlinePen::quad_to(pen, cx0, cy0, x, y)
        PathElement::CurveTo(cx0, cy0, cx1, cy1, x, y) =>
          OutlinePen::curve_to(pen, cx0, cy0, cx1, cy1, x, y)
        PathElement::Close => OutlinePen::close(pen)
      }
    }
    return Ok(metrics)
  }
  let metrics0 = match self.kind {
    OutlineGlyphFormat::Glyf => {
      let has_overlaps = self.has_overlaps().unwrap_or(false)
      let (lsb0, advance_width0) = match
        @moon_skrifa.FontRef::glyph_metrics(
          self.font,
          settings.size(),
          settings.location(),
        ) {
        None => (None, None)
        Some(gm) =>
          (gm.left_side_bearing(self.glyph_id), gm.advance_width(self.glyph_id))
      }
      let (lsb, advance_width) = if settings.path_style() is PathStyle::FreeType {
        (
          match lsb0 {
            None => None
            Some(v) => Some(outline_quantize_freetype(v))
          },
          match advance_width0 {
            None => None
            Some(v) => Some(outline_quantize_freetype(v))
          },
        )
      } else {
        (lsb0, advance_width0)
      }
      AdjustedMetrics::{ has_overlaps, lsb, advance_width }
    }
    _ => AdjustedMetrics::default()
  }
  // Match upstream behavior: when drawing via a (possibly disabled) hinting
  // instance, advance width is rounded to the nearest pixel even if we fall
  // back to the unhinted path.
  let metrics = if settings.hinting_instance() is Some(h) &&
    settings.path_style() is PathStyle::FreeType &&
    !h.is_enabled() {
    AdjustedMetrics::{
      has_overlaps: metrics0.has_overlaps,
      lsb: metrics0.lsb,
      advance_width: match metrics0.advance_width {
        None => None
        Some(v) => Some(v.round())
      },
    }
  } else {
    metrics0
  }
  let path = match self.path(settings) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  for e in path.iter() {
    match e {
      PathElement::MoveTo(x, y) => OutlinePen::move_to(pen, x, y)
      PathElement::LineTo(x, y) => OutlinePen::line_to(pen, x, y)
      PathElement::QuadTo(cx0, cy0, x, y) =>
        OutlinePen::quad_to(pen, cx0, cy0, x, y)
      PathElement::CurveTo(cx0, cy0, cx1, cy1, x, y) =>
        OutlinePen::curve_to(pen, cx0, cy0, cx1, cy1, x, y)
      PathElement::Close => OutlinePen::close(pen)
    }
  }
  Ok(metrics)
}

///|
/// Draws the outline glyph and returns a flat list of path elements.
pub fn OutlineGlyph::path(
  self : OutlineGlyph,
  settings : DrawSettings,
) -> Result[Array[PathElement], DrawError] {
  if settings.hinting_instance() is Some(_) &&
    settings.path_style() is PathStyle::HarfBuzz {
    return Err(DrawError::HarfBuzzHintingUnsupported)
  }
  if self.kind is OutlineGlyphFormat::Glyf &&
    settings.path_style() is PathStyle::FreeType &&
    settings.hinting_instance() is Some(h) &&
    h.is_enabled() {
    let (_, path) = match h.hinted_glyf_path(self, settings.is_pedantic()) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    Ok(path)
  } else {
    let upem = outline_units_per_em(self.font)
    let scale = settings.size().linear_scale(upem)
    let path_style = settings.path_style()
    let coords = settings.location().effective_coords()
    match self.kind {
      OutlineGlyphFormat::Glyf =>
        match
          glyf_outline_path(
            self.font,
            self.glyph_id,
            coords,
            path_style,
            settings.size(),
          ) {
          None => Err(DrawError::GlyphNotFound(self.glyph_id))
          Some(p) => Ok(p)
        }
      OutlineGlyphFormat::Cff =>
        match cff_outline_path(self.font, self.glyph_id) {
          None => Err(DrawError::GlyphNotFound(self.glyph_id))
          // Upstream uses fixed-point rounding when scaling PostScript outlines.
          Some(p) =>
            Ok(outline_scale_path(p, scale, OutlineScaleMode::FreeType))
        }
      OutlineGlyphFormat::Cff2 =>
        match cff2_outline_path(self.font, self.glyph_id, coords) {
          None => Err(DrawError::GlyphNotFound(self.glyph_id))
          Some(p) =>
            Ok(outline_scale_path(p, scale, OutlineScaleMode::FreeType))
        }
    }
  }
}

///|
pub fn OutlineGlyphCollection::format(
  self : OutlineGlyphCollection,
) -> OutlineGlyphFormat? {
  self.kind
}

///|
/// Returns the outline for the given glyph identifier.
pub fn OutlineGlyphCollection::get(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
) -> OutlineGlyph? {
  match self.kind {
    None => None
    Some(kind) => {
      let idx = gid.to_uint64().to_int()
      let n = self.glyph_count()
      if idx < 0 || idx >= n {
        None
      } else {
        Some(OutlineGlyph::{ font: self.font, glyph_id: gid, kind })
      }
    }
  }
}

///|
/// Returns an iterator-like list of all outline glyphs in the collection.
pub fn OutlineGlyphCollection::iter(
  self : OutlineGlyphCollection,
) -> Array[(@moon_skrifa.GlyphId, OutlineGlyph)] {
  let out : Array[(@moon_skrifa.GlyphId, OutlineGlyph)] = Array::new()
  let n = self.glyph_count()
  for i in 0..<n {
    let gid : @moon_skrifa.GlyphId = i.to_uint16()
    match self.get(gid) {
      None => ()
      Some(g) => out.push((gid, g))
    }
  }
  out
}

///|
/// Returns the number of glyphs addressable by this outline source.
pub fn OutlineGlyphCollection::glyph_count(
  self : OutlineGlyphCollection,
) -> Int {
  match self.kind {
    None => 0
    Some(OutlineGlyphFormat::Glyf) => glyf_glyph_count(self.font).unwrap_or(0)
    Some(OutlineGlyphFormat::Cff) => cff_glyph_count(self.font).unwrap_or(0)
    Some(OutlineGlyphFormat::Cff2) => cff2_glyph_count(self.font).unwrap_or(0)
  }
}

///|
/// Returns true when the interpreter engine must be used for hinting this set
/// of outlines to produce correct results.
pub fn OutlineGlyphCollection::require_interpreter(
  self : OutlineGlyphCollection,
) -> Bool {
  match self.kind {
    None => false
    _ => require_interpreter(self.font)
  }
}

///|
/// Returns true when the font supports hinting at fractional sizes.
pub fn OutlineGlyphCollection::fractional_size_hinting(
  self : OutlineGlyphCollection,
) -> Bool {
  match self.kind {
    Some(OutlineGlyphFormat::Glyf) =>
      // head.flags bit 3 (0x0008) == FORCE_INTEGER_PPEM
      match self.font.table(TAG_HEAD) {
        None => true
        Some(head) =>
          if outline_read_u16_be(head, 16) is Some(flags) {
            (flags & 0x0008) == 0
          } else {
            true
          }
      }
    _ => true
  }
}

///|
fn table_is_non_empty(font : @moon_skrifa.FontRef, tag : UInt) -> Bool {
  match font.table(tag) {
    None => false
    Some(view) => view.length() > 0
  }
}

///|
/// Returns `true` if the embedded instruction interpreter is preferred.
///
/// This matches the high-level selection logic used by upstream:
/// - CFF/CFF2 prefers the (PostScript) interpreter
/// - glyf prefers the TrueType interpreter when fpgm/prep are non-empty, or
///   for a small set of "tricky" fonts (stubbed by name/ID in this port)
pub fn OutlineGlyphCollection::prefer_interpreter(
  self : OutlineGlyphCollection,
) -> Bool {
  match self.format() {
    Some(OutlineGlyphFormat::Cff) => true
    Some(OutlineGlyphFormat::Cff2) => true
    Some(OutlineGlyphFormat::Glyf) =>
      require_interpreter(self.font) ||
      table_is_non_empty(self.font, TAG_FPGM) ||
      table_is_non_empty(self.font, TAG_PREP)
    _ => false
  }
}

///|
/// Single path command emitted when drawing a glyph outline.
///
/// Coordinate units are raw font units (design units).
pub(all) enum PathElement {
  MoveTo(Double, Double)
  LineTo(Double, Double)
  QuadTo(Double, Double, Double, Double)
  CurveTo(Double, Double, Double, Double, Double, Double)
  Close
}

///|
/// Reads a big-endian u16 from a BytesView.
fn outline_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn outline_units_per_em(font : @moon_skrifa.FontRef) -> UInt16 {
  let mut upem : UInt16 = 0
  match font.table(TAG_HEAD) {
    None => ()
    Some(head) => {
      let v = outline_read_u16_be(head, 18).unwrap_or(0)
      upem = v.to_uint16()
    }
  }
  upem
}

///|

///|
fn outline_round_ties_even_pos(x : Double) -> Int {
  let i = x.to_int()
  let frac = x - i.to_double()
  let diff = frac - 0.5
  if diff.abs() <= 0.000000000001 {
    if i % 2 == 0 {
      i
    } else {
      i + 1
    }
  } else if frac < 0.5 {
    i
  } else {
    i + 1
  }
}

///|
fn outline_quantize_freetype(v : Double) -> Double {
  let sign = if v < 0.0 { -1.0 } else { 1.0 }
  let scaled = v.abs() * 64.0
  sign * outline_round_ties_even_pos(scaled).to_double() / 64.0
}

///|
priv enum OutlineScaleMode {
  Float
  FreeType
  HarfBuzz
}

///|
fn outline_scale_path(
  path : Array[PathElement],
  scale : Double,
  mode : OutlineScaleMode,
) -> Array[PathElement] {
  if mode is OutlineScaleMode::Float && scale == 1.0 {
    return path
  }
  if mode is OutlineScaleMode::FreeType && scale == 1.0 {
    return path
  }
  let scale = match mode {
    OutlineScaleMode::HarfBuzz => scale * 65536.0
    _ => scale
  }
  let out : Array[PathElement] = Array::new()
  for e in path.iter() {
    match e {
      PathElement::MoveTo(x, y) =>
        if mode is OutlineScaleMode::FreeType {
          out.push(
            PathElement::MoveTo(
              outline_quantize_freetype(x * scale),
              outline_quantize_freetype(y * scale),
            ),
          )
        } else {
          out.push(PathElement::MoveTo(x * scale, y * scale))
        }
      PathElement::LineTo(x, y) =>
        if mode is OutlineScaleMode::FreeType {
          out.push(
            PathElement::LineTo(
              outline_quantize_freetype(x * scale),
              outline_quantize_freetype(y * scale),
            ),
          )
        } else {
          out.push(PathElement::LineTo(x * scale, y * scale))
        }
      PathElement::QuadTo(cx0, cy0, x, y) =>
        if mode is OutlineScaleMode::FreeType {
          out.push(
            PathElement::QuadTo(
              outline_quantize_freetype(cx0 * scale),
              outline_quantize_freetype(cy0 * scale),
              outline_quantize_freetype(x * scale),
              outline_quantize_freetype(y * scale),
            ),
          )
        } else {
          out.push(
            PathElement::QuadTo(cx0 * scale, cy0 * scale, x * scale, y * scale),
          )
        }
      PathElement::CurveTo(cx0, cy0, cx1, cy1, x, y) =>
        if mode is OutlineScaleMode::FreeType {
          out.push(
            PathElement::CurveTo(
              outline_quantize_freetype(cx0 * scale),
              outline_quantize_freetype(cy0 * scale),
              outline_quantize_freetype(cx1 * scale),
              outline_quantize_freetype(cy1 * scale),
              outline_quantize_freetype(x * scale),
              outline_quantize_freetype(y * scale),
            ),
          )
        } else {
          out.push(
            PathElement::CurveTo(
              cx0 * scale,
              cy0 * scale,
              cx1 * scale,
              cy1 * scale,
              x * scale,
              y * scale,
            ),
          )
        }
      PathElement::Close => out.push(PathElement::Close)
    }
  }
  out
}

///|
/// Draws the outline of a glyph and returns a flat list of path elements.
pub fn OutlineGlyphCollection::path(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
  settings : DrawSettings,
) -> Array[PathElement]? {
  match self.get(gid) {
    None => None
    Some(g) =>
      match g.path(settings) {
        Err(_) => None
        Ok(p) => Some(p)
      }
  }
}

///|
/// Convenience wrapper for the previous unscaled API.
pub fn OutlineGlyphCollection::path_unscaled(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
) -> Array[PathElement]? {
  self.path(gid, DrawSettings::default())
}

///|
/// Draws the outline of a glyph into a pen.
pub fn[P : OutlinePen] OutlineGlyphCollection::draw(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
  settings : DrawSettings,
  pen : P,
) -> Bool {
  match self.get(gid) {
    None => false
    Some(g) =>
      match g.draw(settings, pen) {
        Err(_) => false
        Ok(_) => true
      }
  }
}

///|
/// Convenience wrapper for the previous unscaled API.
pub fn[P : OutlinePen] OutlineGlyphCollection::draw_unscaled(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
  pen : P,
) -> Bool {
  self.draw(gid, DrawSettings::default(), pen)
}

///|
/// Draws the outline of a glyph into an SVG path string.
pub fn OutlineGlyphCollection::svg_path(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
  settings : DrawSettings,
) -> String? {
  let pen = SvgPen::new()
  if self.draw(gid, settings, pen) {
    Some(pen.to_string())
  } else {
    None
  }
}

///|
pub fn OutlineGlyphCollection::svg_path_unscaled(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
) -> String? {
  self.svg_path(gid, DrawSettings::default())
}
