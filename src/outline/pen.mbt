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
/// Style for converting glyf point streams to path commands.
///
/// Some glyph point streams are ambiguous when the first point is off-curve;
/// major implementations differ. This lets callers choose which behavior to
/// match.
pub(all) enum PathStyle {
  FreeType
  HarfBuzz
}

///|
pub fn PathStyle::default() -> PathStyle {
  PathStyle::FreeType
}

///|
/// Interface for accepting a sequence of path commands.
pub(open) trait OutlinePen {
  move_to(Self, Double, Double) -> Unit
  line_to(Self, Double, Double) -> Unit
  quad_to(Self, Double, Double, Double, Double) -> Unit
  curve_to(Self, Double, Double, Double, Double, Double, Double) -> Unit
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
  priv precision : Int?
}

///|
pub fn SvgPen::new() -> SvgPen {
  SvgPen::{ s: "", precision: None }
}

///|
/// Creates a new SVG pen that formats floating point values with the given
/// precision (the number of digits printed after the decimal point).
pub fn SvgPen::with_precision(precision : Int) -> SvgPen {
  SvgPen::{ s: "", precision: Some(precision) }
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
fn svg_pen_pow10_int(p : Int) -> Int {
  let mut v = 1
  for _ in 0..<p {
    v = v * 10
  }
  v
}

///|
/// Round-to-nearest with ties-to-even (banker's rounding) for non-negative
/// values. This matches Rust's float formatting behavior used by upstream
/// SvgPen when a precision is specified.
fn svg_pen_round_ties_even_pos(x : Double) -> Int {
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
/// Formats a floating point value with a fixed number of digits after the
/// decimal point, rounding to nearest.
fn svg_pen_format_fixed(x : Double, precision : Int) -> String {
  let sign = if x < 0.0 { "-" } else { "" }
  if precision <= 0 {
    return sign + svg_pen_round_ties_even_pos(x.abs()).to_string()
  }
  let pow10 = svg_pen_pow10_int(precision)
  let scaled = svg_pen_round_ties_even_pos(x.abs() * pow10.to_double())
  let int_part = scaled / pow10
  let frac_part = scaled % pow10
  let mut frac = frac_part.to_string()
  // Pad leading zeros.
  while frac.length() < precision {
    frac = "0" + frac
  }
  sign + int_part.to_string() + "." + frac
}

///|
fn SvgPen::fmt_num(self : SvgPen, x : Double) -> String {
  match self.precision {
    None => x.to_string()
    Some(p) => svg_pen_format_fixed(x, p)
  }
}

///|
pub impl OutlinePen for SvgPen with move_to(pen, x, y) {
  pen.maybe_space()
  pen.s = pen.s + ("M" + pen.fmt_num(x) + "," + pen.fmt_num(y))
}

///|
pub impl OutlinePen for SvgPen with line_to(pen, x, y) {
  pen.maybe_space()
  pen.s = pen.s + ("L" + pen.fmt_num(x) + "," + pen.fmt_num(y))
}

///|
pub impl OutlinePen for SvgPen with quad_to(pen, cx0, cy0, x, y) {
  pen.maybe_space()
  pen.s = pen.s +
    (
      "Q" +
      pen.fmt_num(cx0) +
      "," +
      pen.fmt_num(cy0) +
      " " +
      pen.fmt_num(x) +
      "," +
      pen.fmt_num(y)
    )
}

///|
pub impl OutlinePen for SvgPen with curve_to(pen, cx0, cy0, cx1, cy1, x, y) {
  pen.maybe_space()
  pen.s = pen.s +
    (
      "C" +
      pen.fmt_num(cx0) +
      "," +
      pen.fmt_num(cy0) +
      " " +
      pen.fmt_num(cx1) +
      "," +
      pen.fmt_num(cy1) +
      " " +
      pen.fmt_num(x) +
      "," +
      pen.fmt_num(y)
    )
}

///|
pub impl OutlinePen for SvgPen with close(pen) {
  pen.maybe_space()
  pen.s = pen.s + "Z"
}

///|
/// Pen that drops all drawing output.
pub struct NullPen {}

///|
pub fn NullPen::new() -> NullPen {
  NullPen::{  }
}

///|
pub impl OutlinePen for NullPen with move_to(_, _, _) {

}

///|
pub impl OutlinePen for NullPen with line_to(_, _, _) {

}

///|
pub impl OutlinePen for NullPen with quad_to(_, _, _, _, _) {

}

///|
pub impl OutlinePen for NullPen with curve_to(_, _, _, _, _, _, _) {

}

///|
pub impl OutlinePen for NullPen with close(_) {

}
