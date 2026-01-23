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
/// Types for collecting the output when drawing a glyph outline.
///
/// Ported from `fontations/skrifa/src/outline/pen.rs` (Apache-2.0 OR MIT).

///|
/// Interface for accepting a sequence of path commands.
pub(open) trait OutlinePen {
  move_to(Self, Int, Int) -> Unit
  line_to(Self, Int, Int) -> Unit
  quad_to(Self, Int, Int, Int, Int) -> Unit
  curve_to(Self, Int, Int, Int, Int, Int, Int) -> Unit
  close(Self) -> Unit
}

///|
pub impl OutlinePen for Array[PathElement] with move_to(out, x, y) {
  out.push(PathElement::MoveTo(x, y))
}

///|
pub impl OutlinePen for Array[PathElement] with line_to(out, x, y) {
  out.push(PathElement::LineTo(x, y))
}

///|
pub impl OutlinePen for Array[PathElement] with quad_to(out, cx0, cy0, x, y) {
  out.push(PathElement::QuadTo(cx0, cy0, x, y))
}

///|
pub impl OutlinePen for Array[PathElement] with curve_to(
  out,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  out.push(PathElement::CurveTo(cx0, cy0, cx1, cy1, x, y))
}

///|
pub impl OutlinePen for Array[PathElement] with close(out) {
  out.push(PathElement::Close)
}

///|
/// Pen that generates SVG style path data.
pub struct SvgPen {
  priv mut s : String
}

///|
pub fn SvgPen::new() -> SvgPen {
  SvgPen::{ s: "" }
}

///|
pub fn SvgPen::clear(self : SvgPen) -> Unit {
  self.s = ""
}

///|
pub fn SvgPen::to_string(self : SvgPen) -> String {
  self.s
}

///|
fn SvgPen::maybe_space(self : SvgPen) -> Unit {
  if !self.s.is_empty() {
    self.s = self.s + " "
  }
}

///|
pub impl OutlinePen for SvgPen with move_to(pen, x, y) {
  pen.maybe_space()
  pen.s = pen.s + ("M" + x.to_string() + "," + y.to_string())
}

///|
pub impl OutlinePen for SvgPen with line_to(pen, x, y) {
  pen.maybe_space()
  pen.s = pen.s + ("L" + x.to_string() + "," + y.to_string())
}

///|
pub impl OutlinePen for SvgPen with quad_to(pen, cx0, cy0, x, y) {
  pen.maybe_space()
  pen.s = pen.s +
    (
      "Q" +
      cx0.to_string() +
      "," +
      cy0.to_string() +
      " " +
      x.to_string() +
      "," +
      y.to_string()
    )
}

///|
pub impl OutlinePen for SvgPen with curve_to(pen, cx0, cy0, cx1, cy1, x, y) {
  pen.maybe_space()
  pen.s = pen.s +
    (
      "C" +
      cx0.to_string() +
      "," +
      cy0.to_string() +
      " " +
      cx1.to_string() +
      "," +
      cy1.to_string() +
      " " +
      x.to_string() +
      "," +
      y.to_string()
    )
}

///|
pub impl OutlinePen for SvgPen with close(pen) {
  pen.maybe_space()
  pen.s = pen.s + "Z"
}
