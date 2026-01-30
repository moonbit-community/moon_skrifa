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
/// CFF/CFF2 font matrix helpers.
///
/// Ported from `fontations/skrifa/src/outline/cff/mod.rs` and
/// `fontations/read-fonts/src/tables/postscript/dict.rs`.

///|
priv struct CffMatrix {
  xx : CffFixed
  yx : CffFixed
  xy : CffFixed
  yy : CffFixed
  dx : CffFixed
  dy : CffFixed
}

///|
fn CffMatrix::is_identity(self : CffMatrix) -> Bool {
  self.xx.bits == CffFixed::one().bits &&
  self.yx.bits == CffFixed::zero().bits &&
  self.xy.bits == CffFixed::zero().bits &&
  self.yy.bits == CffFixed::one().bits &&
  self.dx.bits == CffFixed::zero().bits &&
  self.dy.bits == CffFixed::zero().bits
}

///|
fn CffMatrix::transform(
  self : CffMatrix,
  x : CffFixed,
  y : CffFixed,
) -> (CffFixed, CffFixed) {
  (
    self.xx.mul(x).add(self.xy.mul(y)).add(self.dx),
    self.yx.mul(x).add(self.yy.mul(y)).add(self.dy),
  )
}

///|
fn cff_matrix_mul_scaled(
  a : CffMatrix,
  b : CffMatrix,
  scaling : Int,
) -> CffMatrix {
  // Ported from `matrix_mul_scaled` in fontations.
  let val = CffFixed::from_i32(scaling)
  let xx = a.xx.mul_div(b.xx, val).add(a.xy.mul_div(b.yx, val))
  let yx = a.yx.mul_div(b.xx, val).add(a.yy.mul_div(b.yx, val))
  let xy = a.xx.mul_div(b.xy, val).add(a.xy.mul_div(b.yy, val))
  let yy = a.yx.mul_div(b.xy, val).add(a.yy.mul_div(b.yy, val))
  // Note: this transforms the translation component of `b` by the upper 2x2 of
  // `a` (matches FreeType concatenation semantics).
  let dx = b.dx.mul_div(a.xx, val).add(b.dy.mul_div(a.xy, val))
  let dy = b.dx.mul_div(a.yx, val).add(b.dy.mul_div(a.yy, val))
  CffMatrix::{ xx, yx, xy, yy, dx, dy }
}

///|
fn cff_normalize_font_matrix(
  matrix0 : CffMatrix,
  scaled_upem0 : Int,
) -> (CffMatrix, Int) {
  // Ported from `normalize_font_matrix` in read-fonts.
  let factor = if matrix0.yy.bits != CffFixed::zero().bits {
    matrix0.yy.abs()
  } else {
    // Use yx if yy is zero.
    matrix0.yx.abs()
  }
  let (m1, scaled_upem) = if factor.bits != CffFixed::one().bits {
    let scaled_upem = CffFixed::from_bits(scaled_upem0).div(factor).bits
    (
      CffMatrix::{
        xx: matrix0.xx.div(factor),
        yx: matrix0.yx.div(factor),
        xy: matrix0.xy.div(factor),
        yy: matrix0.yy.div(factor),
        dx: matrix0.dx.div(factor),
        dy: matrix0.dy.div(factor),
      },
      scaled_upem,
    )
  } else {
    (matrix0, scaled_upem0)
  }
  // FreeType shifts off the fractional parts of the translation.
  let m2 = CffMatrix::{
    xx: m1.xx,
    yx: m1.yx,
    xy: m1.xy,
    yy: m1.yy,
    dx: CffFixed::from_bits(m1.dx.bits >> 16),
    dy: CffFixed::from_bits(m1.dy.bits >> 16),
  }
  (m2, scaled_upem)
}

///|
fn cff_matrix_transform_hinted(
  matrix : CffMatrix,
  x : CffFixed,
  y : CffFixed,
) -> (CffFixed, CffFixed) {
  // Ported from `HintedTransformingSink`: apply the transform to 26.6 values,
  // but our hinted coordinates are 16.16.
  let x_26_6 = CffFixed::from_bits(x.bits >> 10)
  let y_26_6 = CffFixed::from_bits(y.bits >> 10)
  let (tx, ty) = CffMatrix::transform(matrix, x_26_6, y_26_6)
  (CffFixed::from_bits(tx.bits << 10), CffFixed::from_bits(ty.bits << 10))
}
