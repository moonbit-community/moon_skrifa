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
/// OpenType tag (four ASCII bytes).
///
/// Ported from `read-fonts::types::Tag` usage in `fontations/skrifa`.
pub struct Tag {
  priv value : UInt
}

///|
pub fn Tag::from_uint(value : UInt) -> Tag {
  Tag::{ value, }
}

///|
pub fn Tag::default() -> Tag {
  Tag::from_uint(0)
}

///|
pub fn Tag::to_uint(self : Tag) -> UInt {
  self.value
}

///|
pub fn Tag::new(b0 : Int, b1 : Int, b2 : Int, b3 : Int) -> Tag? {
  if b0 < 0 ||
    b0 > 255 ||
    b1 < 0 ||
    b1 > 255 ||
    b2 < 0 ||
    b2 > 255 ||
    b3 < 0 ||
    b3 > 255 {
    None
  } else {
    let u0 = b0.reinterpret_as_uint()
    let u1 = b1.reinterpret_as_uint()
    let u2 = b2.reinterpret_as_uint()
    let u3 = b3.reinterpret_as_uint()
    Some(Tag::{ value: (u0 << 24) | (u1 << 16) | (u2 << 8) | u3 })
  }
}

///|
pub fn Tag::from_str(s : String) -> Tag? {
  if s.length() != 4 {
    return None
  }
  let c0 = s.code_unit_at(0).to_int()
  let c1 = s.code_unit_at(1).to_int()
  let c2 = s.code_unit_at(2).to_int()
  let c3 = s.code_unit_at(3).to_int()
  Tag::new(c0, c1, c2, c3)
}

///|
pub fn Tag::from_str_or_default(s : String) -> Tag {
  match Tag::from_str(s) {
    Some(tag) => tag
    None => Tag::from_uint(0)
  }
}

///|
pub fn Tag::to_string(self : Tag) -> String {
  let u = self.value
  let mask = 255 |> Int::reinterpret_as_uint
  let b0 = ((u >> 24) & mask).reinterpret_as_int()
  let b1 = ((u >> 16) & mask).reinterpret_as_int()
  let b2 = ((u >> 8) & mask).reinterpret_as_int()
  let b3 = (u & mask).reinterpret_as_int()
  let chars = Array::from_fixed_array([
    b0.unsafe_to_char(),
    b1.unsafe_to_char(),
    b2.unsafe_to_char(),
    b3.unsafe_to_char(),
  ])
  String::from_array(chars.op_as_view())
}
