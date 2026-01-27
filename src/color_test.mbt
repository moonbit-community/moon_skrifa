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
fn color_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn color_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn color_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn color_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  color_test_push_u32_be(out, color_test_u32(0x00010000))
  color_test_push_u16_be(out, num_tables)
  color_test_push_u16_be(out, 0)
  color_test_push_u16_be(out, 0)
  color_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    color_test_push_u32_be(out, tag)
    color_test_push_u32_be(out, color_test_u32(0))
    color_test_push_u32_be(out, color_test_u32(offset))
    color_test_push_u32_be(out, color_test_u32(data.length()))
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
const TAG_CPAL : UInt = 0x4350414C // "CPAL"

///|
fn color_test_build_cpal() -> Bytes {
  let out : Array[Byte] = Array::new()
  // version 0
  color_test_push_u16_be(out, 0)
  // numPaletteEntries=2
  color_test_push_u16_be(out, 2)
  // numPalettes=1
  color_test_push_u16_be(out, 1)
  // numColorRecords=2
  color_test_push_u16_be(out, 2)
  // offsetFirstColorRecord = 12 + 2*numPalettes = 14
  color_test_push_u32_be(out, color_test_u32(14))
  // colorRecordIndices[0] = 0
  color_test_push_u16_be(out, 0)
  // ColorRecord[0] = red (BGRA)
  out.push(0 |> Int::to_byte) // B
  out.push(0 |> Int::to_byte) // G
  out.push(255 |> Int::to_byte) // R
  out.push(255 |> Int::to_byte) // A
  // ColorRecord[1] = green
  out.push(0 |> Int::to_byte)
  out.push(255 |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  out.push(255 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
test "CPAL palettes basic" {
  let cpal = color_test_build_cpal()
  let sfnt = color_test_build_sfnt(Array::from_fixed_array([(TAG_CPAL, cpal)]))
  let font = FontRef::new(sfnt).unwrap()
  let palettes = font.color_palettes()
  inspect(palettes.len(), content="1")
  inspect(palettes.entries_per_palette(), content="2")
  let c0 = palettes.color(0, 0).unwrap()
  inspect(c0.r().to_int(), content="255")
  inspect(c0.g().to_int(), content="0")
  inspect(c0.b().to_int(), content="0")
  let c1 = palettes.color(0, 1).unwrap()
  inspect(c1.r().to_int(), content="0")
  inspect(c1.g().to_int(), content="255")
  inspect(c1.b().to_int(), content="0")
}
