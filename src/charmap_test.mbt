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
/// Minimal charmap tests (format 4 / 12), using synthetic SFNT bytes.
fn cmap_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn cmap_test_push_i16_be(out : Array[Byte], v : Int) -> Unit {
  let u = (v & 0xFFFF).reinterpret_as_uint()
  cmap_test_push_u16_be(out, u.to_uint64().to_int())
}

///|
fn cmap_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn cmap_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn make_sfnt_with_table(tag : UInt, table : Bytes) -> Bytes {
  let out : Array[Byte] = Array::new()
  // sfnt version
  cmap_test_push_u32_be(out, cmap_test_u32(0x00010000))
  // numTables=1, searchRange/entrySelector/rangeShift=0
  cmap_test_push_u16_be(out, 1)
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 0)
  // table record
  cmap_test_push_u32_be(out, tag)
  cmap_test_push_u32_be(out, cmap_test_u32(0))
  cmap_test_push_u32_be(out, cmap_test_u32(28))
  cmap_test_push_u32_be(out, cmap_test_u32(table.length()))
  for b in table.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn make_cmap_format4_single() -> Bytes {
  // Map U+0041 -> GID 5 (via idDelta), include required 0xFFFF sentinel segment.
  let seg_count = 2
  let fmt4_len = 32
  let out : Array[Byte] = Array::new()
  // cmap header: version=0, numTables=1
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 1)
  // encoding record: platform=3, encoding=1, offset=12
  cmap_test_push_u16_be(out, 3)
  cmap_test_push_u16_be(out, 1)
  cmap_test_push_u32_be(out, cmap_test_u32(12))

  // format 4 subtable (at offset 12)
  cmap_test_push_u16_be(out, 4)
  cmap_test_push_u16_be(out, fmt4_len)
  cmap_test_push_u16_be(out, 0) // language
  cmap_test_push_u16_be(out, seg_count * 2) // segCountX2
  cmap_test_push_u16_be(out, 0) // searchRange
  cmap_test_push_u16_be(out, 0) // entrySelector
  cmap_test_push_u16_be(out, 0) // rangeShift

  // endCode[2] = [0x0041, 0xFFFF]
  cmap_test_push_u16_be(out, 0x0041)
  cmap_test_push_u16_be(out, 0xFFFF)
  cmap_test_push_u16_be(out, 0) // reservedPad

  // startCode[2] = [0x0041, 0xFFFF]
  cmap_test_push_u16_be(out, 0x0041)
  cmap_test_push_u16_be(out, 0xFFFF)

  // idDelta[2] = [5 - 0x41, 1]
  cmap_test_push_i16_be(out, 5 - 0x0041)
  cmap_test_push_i16_be(out, 1)

  // idRangeOffset[2] = [0, 0]
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 0)
  Bytes::from_array(out.op_as_view())
}

///|
fn make_cmap_format12_single() -> Bytes {
  let fmt12_len = 28
  let out : Array[Byte] = Array::new()
  // cmap header: version=0, numTables=1
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 1)
  // encoding record: platform=3, encoding=10, offset=12
  cmap_test_push_u16_be(out, 3)
  cmap_test_push_u16_be(out, 10)
  cmap_test_push_u32_be(out, cmap_test_u32(12))

  // format 12 subtable
  cmap_test_push_u16_be(out, 12)
  cmap_test_push_u16_be(out, 0) // reserved
  cmap_test_push_u32_be(out, cmap_test_u32(fmt12_len))
  cmap_test_push_u32_be(out, cmap_test_u32(0)) // language
  cmap_test_push_u32_be(out, cmap_test_u32(1)) // nGroups
  // group: U+1F600..U+1F600 -> GID 100
  cmap_test_push_u32_be(out, cmap_test_u32(0x1F600))
  cmap_test_push_u32_be(out, cmap_test_u32(0x1F600))
  cmap_test_push_u32_be(out, cmap_test_u32(100))
  Bytes::from_array(out.op_as_view())
}

///|
const TAG_CMAP : UInt = 0x636D6170 // "cmap"

///|
test "Charmap format4 maps BMP codepoint" {
  let font = FontRef::new(
    make_sfnt_with_table(TAG_CMAP, make_cmap_format4_single()),
  ).unwrap()
  let cmap = Charmap::new(font).unwrap()
  inspect(cmap.glyph_id(0x41), content="Some(5)")
  inspect(cmap.glyph_id(0x42), content="None")
}

///|
test "Charmap format12 maps UCS-4 codepoint" {
  let font = FontRef::new(
    make_sfnt_with_table(TAG_CMAP, make_cmap_format12_single()),
  ).unwrap()
  let cmap = Charmap::new(font).unwrap()
  inspect(cmap.glyph_id(0x1F600), content="Some(100)")
  inspect(cmap.glyph_id(0x1F601), content="None")
}
