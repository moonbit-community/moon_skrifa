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
fn colr_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn colr_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn colr_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn colr_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  colr_test_push_u32_be(out, colr_test_u32(0x00010000))
  colr_test_push_u16_be(out, num_tables)
  colr_test_push_u16_be(out, 0)
  colr_test_push_u16_be(out, 0)
  colr_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    colr_test_push_u32_be(out, tag)
    colr_test_push_u32_be(out, colr_test_u32(0))
    colr_test_push_u32_be(out, colr_test_u32(offset))
    colr_test_push_u32_be(out, colr_test_u32(data.length()))
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
const TAG_COLR : UInt = 0x434F4C52 // "COLR"

///|
fn colr_test_build_colr() -> Bytes {
  let out : Array[Byte] = Array::new()
  // header:
  // version=0, numBaseGlyphRecords=1
  colr_test_push_u16_be(out, 0)
  colr_test_push_u16_be(out, 1)
  // baseGlyphRecordsOffset=14, layerRecordsOffset=20, numLayerRecords=2
  colr_test_push_u32_be(out, colr_test_u32(14))
  colr_test_push_u32_be(out, colr_test_u32(20))
  colr_test_push_u16_be(out, 2)
  // base glyph record for gid=5: firstLayerIndex=0, numLayers=2
  colr_test_push_u16_be(out, 5)
  colr_test_push_u16_be(out, 0)
  colr_test_push_u16_be(out, 2)
  // layer records:
  // (gid=10, palette=1), (gid=11, palette=2)
  colr_test_push_u16_be(out, 10)
  colr_test_push_u16_be(out, 1)
  colr_test_push_u16_be(out, 11)
  colr_test_push_u16_be(out, 2)
  Bytes::from_array(out.op_as_view())
}

///|
test "COLR v0 layers basic" {
  let colr = colr_test_build_colr()
  let sfnt = colr_test_build_sfnt(Array::from_fixed_array([(TAG_COLR, colr)]))
  let font = FontRef::new(sfnt).unwrap()
  let cg = font.color_glyphs().unwrap()
  let layers = cg.layers(5).unwrap()
  inspect(layers.length(), content="2")
  inspect(layers.at(0).glyph_id().to_string(), content="10")
  inspect(layers.at(0).palette_index(), content="1")
  inspect(layers.at(1).glyph_id().to_string(), content="11")
  inspect(layers.at(1).palette_index(), content="2")
}
