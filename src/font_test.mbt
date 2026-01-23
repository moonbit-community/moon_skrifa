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
/// Minimal FontRef tests (SFNT/TTC + table lookup).
fn push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
const TAG_TTCF : UInt = 0x74746366 // "ttcf"

///|
const TAG_TEST : UInt = 0x74657374 // "test"

///|
fn u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn make_min_sfnt() -> Bytes {
  let out = Array::new()
  // sfnt version: 0x00010000
  push_u32_be(out, u32(0x00010000))
  // numTables=1, searchRange/entrySelector/rangeShift=0
  push_u16_be(out, 1)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  // table record (16 bytes)
  push_u32_be(out, TAG_TEST)
  push_u32_be(out, u32(0)) // checksum (unused)
  push_u32_be(out, u32(28)) // offset (from sfnt start)
  push_u32_be(out, u32(4)) // length
  // table bytes: "abcd"
  out.push(0x61 |> Int::to_byte)
  out.push(0x62 |> Int::to_byte)
  out.push(0x63 |> Int::to_byte)
  out.push(0x64 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn make_min_ttc() -> Bytes {
  let out = Array::new()
  push_u32_be(out, TAG_TTCF)
  push_u32_be(out, u32(0x00010000)) // version
  push_u32_be(out, u32(1)) // numFonts
  push_u32_be(out, u32(16)) // offset[0] (immediately after offsets array)
  let sfnt = make_min_sfnt()
  for b in sfnt.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
test "FontRef::new sfnt + table()" {
  let data = make_min_sfnt()
  let font = FontRef::new(data).unwrap()
  inspect(font.index(), content="0")
  let t = font.table(TAG_TEST).unwrap()
  inspect(t.to_bytes(), content="b\"abcd\"")
}

///|
test "FontRef::new ttc + table()" {
  let data = make_min_ttc()
  let font = FontRef::new(data).unwrap()
  inspect(font.index(), content="0")
  let t = font.table(TAG_TEST).unwrap()
  inspect(t.to_bytes(), content="b\"abcd\"")
}

///|
test "FontRef::from_index bounds" {
  let data = make_min_ttc()
  let ok = match FontRef::from_index(data, 1) {
    None => true
    Some(_) => false
  }
  inspect(ok, content="true")
}
