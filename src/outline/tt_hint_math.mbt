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
/// Fixed point math helpers for the TrueType interpreter.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/math.rs` (Apache-2.0 OR MIT).

///|
fn tt_hint_floor_26(x : Int) -> Int {
  x & -64
}

///|
fn tt_hint_round_26(x : Int) -> Int {
  tt_hint_floor_26(x + 32)
}

///|
fn tt_hint_ceil_26(x : Int) -> Int {
  tt_hint_floor_26(x + 63)
}

///|
fn tt_hint_floor_pad(x : Int, n : Int) -> Int {
  // `n` is always a power of two in our uses (matches fontations).
  x & -n
}

///|
fn tt_hint_round_pad(x : Int, n : Int) -> Int {
  tt_hint_floor_pad(x + n / 2, n)
}

///|
/// 16.16 fixed multiply with FreeType-style rounding.
fn tt_hint_mul_16_16(a : Int, b : Int) -> Int {
  let ab = a.to_int64() * b.to_int64()
  let adj = 0x8000 - (if ab < 0 { 1 } else { 0 })
  ((ab + adj.to_int64()) >> 16).to_int()
}

///|
/// 16.16 fixed division with FreeType-style rounding.
fn tt_hint_div_16_16(a0 : Int, b0 : Int) -> Int {
  let mut sign = 1
  let mut a = a0
  let mut b = b0
  if a < 0 {
    a = -a
    sign = -sign
  }
  if b < 0 {
    b = -b
    sign = -sign
  }
  let q : Int = if b == 0 {
    0x7FFFFFFF
  } else {
    let num = (a.to_int64() << 16) + (b.to_int64() >> 1)
    (num / b.to_int64()).to_int()
  }
  if sign < 0 {
    -q
  } else {
    q
  }
}

///|
/// 16.16 fixed multiply and divide: a * b / c.
fn tt_hint_mul_div_16_16(a : Int, b : Int, c : Int) -> Int {
  // Matches font-types Fixed::mul_div() behavior.
  let mut sign = 1
  let mut au : UInt = a.reinterpret_as_uint()
  let mut bu : UInt = b.reinterpret_as_uint()
  let mut cu : UInt = c.reinterpret_as_uint()
  if a < 0 {
    au = (0 : UInt) - au
    sign = -sign
  }
  if b < 0 {
    bu = (0 : UInt) - bu
    sign = -sign
  }
  if c < 0 {
    cu = (0 : UInt) - cu
    sign = -sign
  }
  let res_u : UInt64 = if cu.to_uint64() > 0 {
    (au.to_uint64() * bu.to_uint64() + (cu.to_uint64() >> 1)) / cu.to_uint64()
  } else {
    0x7FFFFFFF
  }
  let res_i : Int = res_u.to_int()
  if sign < 0 {
    -res_i
  } else {
    res_i
  }
}

///|
/// Fixed point multiply and divide without rounding: a * b / c.
///
/// Port of `FT_MulDiv_NoRound`.
fn tt_hint_mul_div_no_round(a0 : Int, b0 : Int, c0 : Int) -> Int {
  let mut a = a0
  let mut b = b0
  let mut c = c0
  let mut s = 1
  if a < 0 {
    a = -a
    s = -s
  }
  if b < 0 {
    b = -b
    s = -s
  }
  if c < 0 {
    c = -c
    s = -s
  }
  let d : Int64 = if c > 0 {
    a.to_int64() * b.to_int64() / c.to_int64()
  } else {
    0x7FFFFFFF
  }
  let out = d.to_int()
  if s < 0 {
    -out
  } else {
    out
  }
}

///|
/// Multiplication for 2.14 fixed point.
fn tt_hint_mul14(a : Int, b : Int) -> Int {
  let mut v = a.to_int64() * b.to_int64()
  v = v + 0x2000 + (v >> 63)
  (v >> 14).to_int()
}

///|
fn tt_hint_u32_leading_zeros(x0 : UInt) -> Int {
  let x = x0
  if x == 0 {
    return 32
  }
  let mut n = 0
  let mut bit : UInt = 0x80000000
  while bit != 0 && (x & bit) == 0 {
    n = n + 1
    bit = bit >> 1
  }
  n
}

///|
/// Normalize a vector in 2.14 fixed point.
///
/// Ported from FreeType's fixed point normalize routine (via fontations).
fn tt_hint_normalize14(x0 : Int, y0 : Int) -> (Int, Int) {
  // Port of fontations `math::normalize14` (FreeType fixed-point implementation).
  // Returns a normalized vector in 2.14 fixed point.
  let mut sx = 1
  let mut sy = 1
  let mut ux : UInt = x0.reinterpret_as_uint()
  let mut uy : UInt = y0.reinterpret_as_uint()
  if x0 < 0 {
    ux = (0 : UInt) - ux
    sx = -sx
  }
  if y0 < 0 {
    uy = (0 : UInt) - uy
    sy = -sy
  }
  if ux == 0 {
    return (0, if uy > 0 { sy * 0x10000 / 4 } else { 0 })
  }
  if uy == 0 {
    return (if ux > 0 { sx * 0x10000 / 4 } else { 0 }, 0)
  }
  let mut len : UInt = if ux > uy { ux + (uy >> 1) } else { uy + (ux >> 1) }
  let mut shift = tt_hint_u32_leading_zeros(len)
  // len is non-zero here, so shift is in 0..31.
  let extra = if len >= (0xAAAAAAAA : UInt) >> shift { 1 } else { 0 }
  shift = shift - 15 - extra
  if shift > 0 {
    ux = ux << shift
    uy = uy << shift
    len = if ux > uy { ux + (uy >> 1) } else { uy + (ux >> 1) }
  } else {
    let s = -shift
    ux = ux >> s
    uy = uy >> s
    len = len >> s
  }
  let x = ux.reinterpret_as_int()
  let y = uy.reinterpret_as_int()
  let mut b : Int = 0x10000 - len.reinterpret_as_int()
  let mut out_x = 0
  let mut out_y = 0
  while true {
    let u : UInt = (x + ((x * b) >> 16)).reinterpret_as_uint()
    let v : UInt = (y + ((y * b) >> 16)).reinterpret_as_uint()
    let sum : UInt = u * u + v * v
    let mut z : Int = -sum.reinterpret_as_int() / 0x200
    z = z * ((0x10000 + b) >> 8) / 0x10000
    b = b + z
    if z <= 0 {
      out_x = u.reinterpret_as_int() * sx / 4
      out_y = v.reinterpret_as_int() * sy / 4
      break
    }
  }
  (out_x, out_y)
}
