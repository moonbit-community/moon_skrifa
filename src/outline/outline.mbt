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
pub struct OutlineGlyphCollection {
  font : @moon_skrifa.FontRef?
}

///|
pub fn OutlineGlyphCollection::new() -> OutlineGlyphCollection {
  OutlineGlyphCollection::{ font: None }
}

///|
pub fn OutlineGlyphCollection::from_font(
  font : @moon_skrifa.FontRef,
) -> OutlineGlyphCollection {
  OutlineGlyphCollection::{ font: Some(font) }
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
pub fn OutlineGlyphCollection::format(self : OutlineGlyphCollection) -> UInt? {
  if self.font is Some(font) {
    if font.table(TAG_GLYF) is Some(_) {
      Some(TAG_GLYF)
    } else if font.table(TAG_CFF) is Some(_) {
      Some(TAG_CFF)
    } else if font.table(TAG_CFF2) is Some(_) {
      Some(TAG_CFF2)
    } else {
      None
    }
  } else {
    None
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
  if self.font is Some(font) {
    match self.format() {
      Some(TAG_CFF) => true
      Some(TAG_CFF2) => true
      Some(TAG_GLYF) =>
        require_interpreter(font) ||
        table_is_non_empty(font, TAG_FPGM) ||
        table_is_non_empty(font, TAG_PREP)
      _ => false
    }
  } else {
    false
  }
}

///|
/// Single path command emitted when drawing a glyph outline.
///
/// Coordinate units are raw font units (design units).
pub(all) enum PathElement {
  MoveTo(Int, Int)
  LineTo(Int, Int)
  QuadTo(Int, Int, Int, Int)
  CurveTo(Int, Int, Int, Int, Int, Int)
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
fn outline_scale_int(v : Int, scale : Double) -> Int {
  (v.to_double() * scale).round().to_int()
}

///|
fn outline_scale_path(
  path : Array[PathElement],
  scale : Double,
) -> Array[PathElement] {
  if scale == 1.0 {
    return path
  }
  let out : Array[PathElement] = Array::new()
  for e in path.iter() {
    match e {
      PathElement::MoveTo(x, y) =>
        out.push(
          PathElement::MoveTo(
            outline_scale_int(x, scale),
            outline_scale_int(y, scale),
          ),
        )
      PathElement::LineTo(x, y) =>
        out.push(
          PathElement::LineTo(
            outline_scale_int(x, scale),
            outline_scale_int(y, scale),
          ),
        )
      PathElement::QuadTo(cx0, cy0, x, y) =>
        out.push(
          PathElement::QuadTo(
            outline_scale_int(cx0, scale),
            outline_scale_int(cy0, scale),
            outline_scale_int(x, scale),
            outline_scale_int(y, scale),
          ),
        )
      PathElement::CurveTo(cx0, cy0, cx1, cy1, x, y) =>
        out.push(
          PathElement::CurveTo(
            outline_scale_int(cx0, scale),
            outline_scale_int(cy0, scale),
            outline_scale_int(cx1, scale),
            outline_scale_int(cy1, scale),
            outline_scale_int(x, scale),
            outline_scale_int(y, scale),
          ),
        )
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
  if self.font is Some(font) {
    let upem = outline_units_per_em(font)
    let scale = settings.size().linear_scale(upem)
    let path_style = settings.path_style()
    let _coords = settings.location().effective_coords()
    let raw = if font.table(TAG_GLYF) is Some(_) {
      glyf_outline_path(font, gid, path_style)
    } else if font.table(TAG_CFF) is Some(_) {
      cff_outline_path(font, gid)
    } else if font.table(TAG_CFF2) is Some(_) {
      cff2_outline_path(font, gid)
    } else {
      None
    }
    match raw {
      None => None
      Some(p) => Some(outline_scale_path(p, scale))
    }
  } else {
    None
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
  match self.path(gid, settings) {
    None => false
    Some(path) => {
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
      true
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
