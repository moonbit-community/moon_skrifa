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
/// Minimal CFF/CFF2 DICT parsing helpers (only operators needed for outlines).

///|
priv struct CffDictInfo {
  mut charstrings_offset : Int?
  mut var_store_offset : Int?
  mut private_size : Int?
  mut private_offset : Int?
  mut subrs_offset : Int?
}

///|
fn cff_dict_read_i32_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    let b2 = view.at(offset + 2).to_int()
    let b3 = view.at(offset + 3).to_int()
    let u = (b0.reinterpret_as_uint() << 24) |
      (b1.reinterpret_as_uint() << 16) |
      (b2.reinterpret_as_uint() << 8) |
      b3.reinterpret_as_uint()
    Some(u.reinterpret_as_int())
  }
}

///|
fn cff_dict_parse_int(data : BytesView, pos : Int, b0 : Int) -> (Int, Int)? {
  match b0 {
    28 =>
      match type2_read_i16_be(data, pos) {
        None => None
        Some(v) => Some((v, pos + 2))
      }
    29 =>
      match cff_dict_read_i32_be(data, pos) {
        None => None
        Some(v) => Some((v, pos + 4))
      }
    32..=246 => Some((b0 - 139, pos))
    247..=250 =>
      if pos >= data.length() {
        None
      } else {
        let b1 = data.at(pos).to_int()
        Some(((b0 - 247) * 256 + b1 + 108, pos + 1))
      }
    251..=254 =>
      if pos >= data.length() {
        None
      } else {
        let b1 = data.at(pos).to_int()
        Some((-(b0 - 251) * 256 - b1 - 108, pos + 1))
      }
    // Real numbers (BCD) are not needed for our offsets; skip parsing.
    30 => None
    _ => None
  }
}

///|
fn cff_dict_parse(data : BytesView) -> CffDictInfo {
  let info = CffDictInfo::{
    charstrings_offset: None,
    var_store_offset: None,
    private_size: None,
    private_offset: None,
    subrs_offset: None,
  }
  let stack : Array[Int] = Array::new()
  let mut pos = 0
  while pos < data.length() {
    let b0 = data.at(pos).to_int()
    pos = pos + 1
    if b0 == 28 || b0 == 29 || b0 == 30 || (b0 >= 32 && b0 <= 254) {
      match cff_dict_parse_int(data, pos, b0) {
        None => break
        Some((v, p)) => {
          stack.push(v)
          pos = p
        }
      }
      continue
    }
    let op = if b0 == 12 {
      if pos >= data.length() {
        break
      }
      let b1 = data.at(pos).to_int()
      pos = pos + 1
      1200 + b1
    } else {
      b0
    }
    match op {
      // CharStrings offset
      17 =>
        if stack.length() >= 1 {
          info.charstrings_offset = Some(stack.at(stack.length() - 1))
        }
      // CFF2 VarStore offset (ItemVariationStore)
      24 =>
        if stack.length() >= 1 {
          info.var_store_offset = Some(stack.at(stack.length() - 1))
        }
      // Private DICT range: size, offset
      18 =>
        if stack.length() >= 2 {
          info.private_size = Some(stack.at(0))
          info.private_offset = Some(stack.at(1))
        }
      // Subrs offset (within Private DICT)
      19 =>
        if stack.length() >= 1 {
          info.subrs_offset = Some(stack.at(stack.length() - 1))
        }
      _ => ()
    }
    stack.clear()
  }
  info
}
