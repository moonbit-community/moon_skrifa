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
fn bitmap_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn bitmap_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn bitmap_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn bitmap_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  bitmap_test_push_u32_be(out, bitmap_test_u32(0x00010000))
  bitmap_test_push_u16_be(out, num_tables)
  bitmap_test_push_u16_be(out, 0)
  bitmap_test_push_u16_be(out, 0)
  bitmap_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    bitmap_test_push_u32_be(out, tag)
    bitmap_test_push_u32_be(out, bitmap_test_u32(0))
    bitmap_test_push_u32_be(out, bitmap_test_u32(offset))
    bitmap_test_push_u32_be(out, bitmap_test_u32(data.length()))
    offset = offset + data.length()
  }
  for t in tables {
    let (_, data) = t
    for b in data.iter() {
      out.push(b)
    }
  }
  Bytes::from_array(out.op_as_view())
}

///|
const TAG_SBIX : UInt = 0x73626978 // "sbix"

///|
const TAG_CBLC : UInt = 0x43424C43 // "CBLC"

///|
const TAG_CBDT : UInt = 0x43424454 // "CBDT"

///|
const TAG_EBLC : UInt = 0x45424C43 // "EBLC"

///|
const TAG_EBDT : UInt = 0x45424454 // "EBDT"

///|
fn bitmap_test_build_sbix(ppem : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  bitmap_test_push_u16_be(out, 1) // version
  bitmap_test_push_u16_be(out, 0) // flags
  bitmap_test_push_u32_be(out, bitmap_test_u32(1)) // numStrikes
  bitmap_test_push_u32_be(out, bitmap_test_u32(12)) // strikeOffsets[0]
  bitmap_test_push_u16_be(out, ppem) // strike.ppem
  bitmap_test_push_u16_be(out, 72) // strike.resolution
  Bytes::from_array(out.op_as_view())
}

///|
fn bitmap_test_build_loc(ppem_x : Int, ppem_y : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  bitmap_test_push_u16_be(out, 3) // major
  bitmap_test_push_u16_be(out, 0) // minor
  bitmap_test_push_u32_be(out, bitmap_test_u32(1)) // numSizes
  // BitmapSizeTable (48 bytes), ppemX/Y at offsets 44/45.
  for _ in 0..<44 {
    out.push(0 |> Int::to_byte)
  }
  out.push(ppem_x |> Int::to_byte)
  out.push(ppem_y |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
test "bitmap strikes sbix" {
  let sbix = bitmap_test_build_sbix(16)
  let sfnt = bitmap_test_build_sfnt(Array::from_fixed_array([(TAG_SBIX, sbix)]))
  let font = FontRef::new(sfnt).unwrap()
  let strikes = font.bitmap_strikes()
  inspect(strikes.len(), content="1")
  let strike = strikes.get(0).unwrap()
  inspect(strike.ppem_y(), content="16")
  let ok = if strikes.format() is Some(BitmapFormat::Sbix) {
    true
  } else {
    false
  }
  inspect(ok, content="true")
}

///|
test "bitmap strikes cblc/cbdt" {
  let cblc = bitmap_test_build_loc(10, 12)
  let cbdt = Bytes::from_array(Array::new().op_as_view())
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([(TAG_CBLC, cblc), (TAG_CBDT, cbdt)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let strikes = font.bitmap_strikes()
  let ok = if strikes.format() is Some(BitmapFormat::Cbdt) {
    true
  } else {
    false
  }
  inspect(ok, content="true")
  inspect(strikes.get(0).unwrap().ppem_x(), content="10")
  inspect(strikes.get(0).unwrap().ppem_y(), content="12")
}

///|
test "bitmap strikes eblc/ebdt" {
  let eblc = bitmap_test_build_loc(11, 13)
  let ebdt = Bytes::from_array(Array::new().op_as_view())
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([(TAG_EBLC, eblc), (TAG_EBDT, ebdt)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let strikes = font.bitmap_strikes()
  let ok = if strikes.format() is Some(BitmapFormat::Ebdt) {
    true
  } else {
    false
  }
  inspect(ok, content="true")
  inspect(strikes.get(0).unwrap().ppem_x(), content="11")
  inspect(strikes.get(0).unwrap().ppem_y(), content="13")
}
