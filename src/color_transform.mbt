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
/// Affine transformation matrix used for COLRv1 drawing.
///
/// Ported from `fontations/skrifa/src/color/transform.rs` (Apache-2.0 OR MIT).
pub(all) struct Transform {
  xx : Double
  yx : Double
  xy : Double
  yy : Double
  dx : Double
  dy : Double
}

///|
pub fn Transform::default() -> Transform {
  Transform::{ xx: 1.0, yx: 0.0, xy: 0.0, yy: 1.0, dx: 0.0, dy: 0.0 }
}

///|
pub fn Transform::mul(self : Transform, rhs : Transform) -> Transform {
  fn muladdmul(a : Double, b : Double, c : Double, d : Double) -> Double {
    a * b + c * d
  }

  Transform::{
    xx: muladdmul(self.xx, rhs.xx, self.xy, rhs.yx),
    xy: muladdmul(self.xx, rhs.xy, self.xy, rhs.yy),
    dx: muladdmul(self.xx, rhs.dx, self.xy, rhs.dy) + self.dx,
    yx: muladdmul(self.yx, rhs.xx, self.yy, rhs.yx),
    yy: muladdmul(self.yx, rhs.xy, self.yy, rhs.yy),
    dy: muladdmul(self.yx, rhs.dx, self.yy, rhs.dy) + self.dy,
  }
}

///|
pub fn Transform::apply(
  self : Transform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  (self.xx * x + self.xy * y + self.dx, self.yx * x + self.yy * y + self.dy)
}
