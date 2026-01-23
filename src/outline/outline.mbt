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
/// For now this module only exposes a minimal "outline format detection" API,
/// based on table presence (glyf/CFF/CFF2).
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
/// Draws the outline of a glyph and returns a flat list of path elements.
///
/// Currently only supports TrueType outlines (`glyf`).
pub fn OutlineGlyphCollection::path(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
) -> Array[PathElement]? {
  if self.font is Some(font) {
    if font.table(TAG_GLYF) is Some(_) {
      glyf_outline_path(font, gid)
    } else if font.table(TAG_CFF) is Some(_) {
      cff_outline_path(font, gid)
    } else if font.table(TAG_CFF2) is Some(_) {
      cff2_outline_path(font, gid)
    } else {
      None
    }
  } else {
    None
  }
}

///|
/// Draws the outline of a glyph into a pen.
pub fn[P : OutlinePen] OutlineGlyphCollection::draw(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
  pen : P,
) -> Bool {
  match self.path(gid) {
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
/// Draws the outline of a glyph into an SVG path string.
pub fn OutlineGlyphCollection::svg_path(
  self : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
) -> String? {
  let pen = SvgPen::new()
  if self.draw(gid, pen) {
    Some(pen.to_string())
  } else {
    None
  }
}

///|
pub struct HintingInstance {
  dummy : Int
}

///|
pub fn HintingInstance::new() -> HintingInstance {
  HintingInstance::{ dummy: 0 }
}
