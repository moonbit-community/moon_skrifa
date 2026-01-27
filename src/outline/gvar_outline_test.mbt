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
/// gvar outline tests using synthetic SFNT bytes.
fn gvar_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn gvar_test_push_i16_be(out : Array[Byte], v : Int) -> Unit {
  gvar_test_push_u16_be(out, v)
}

///|
fn gvar_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn gvar_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn gvar_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  gvar_test_push_u32_be(out, gvar_test_u32(0x00010000))
  gvar_test_push_u16_be(out, num_tables)
  gvar_test_push_u16_be(out, 0)
  gvar_test_push_u16_be(out, 0)
  gvar_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    gvar_test_push_u32_be(out, tag)
    gvar_test_push_u32_be(out, gvar_test_u32(0))
    gvar_test_push_u32_be(out, gvar_test_u32(offset))
    gvar_test_push_u32_be(out, gvar_test_u32(data.length()))
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
fn gvar_test_make_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  gvar_test_push_u32_be(out, gvar_test_u32(0x00010000))
  gvar_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn gvar_test_make_head(upem : Int) -> Bytes {
  let out : Array[Byte] = Array::make(54, 0 |> Int::to_byte)
  // head.unitsPerEm at offset 18.
  out.set(18, ((upem >> 8) & 0xFF).to_byte())
  out.set(19, (upem & 0xFF).to_byte())
  // head.indexToLocFormat at offset 50: 1 => long offsets.
  out.set(50, 0 |> Int::to_byte)
  out.set(51, 1 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn gvar_test_make_loca_long(offsets : Array[Int]) -> Bytes {
  let out : Array[Byte] = Array::new()
  for off in offsets {
    gvar_test_push_u32_be(out, gvar_test_u32(off))
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn gvar_test_glyph_simple_quad() -> Bytes {
  // One contour with 3 points:
  // (0,0) on, (50,100) off, (100,0) on.
  let out : Array[Byte] = Array::new()
  gvar_test_push_i16_be(out, 1)
  gvar_test_push_i16_be(out, 0)
  gvar_test_push_i16_be(out, 0)
  gvar_test_push_i16_be(out, 100)
  gvar_test_push_i16_be(out, 100)
  gvar_test_push_u16_be(out, 2) // endPts[0]
  gvar_test_push_u16_be(out, 0) // instructionLength
  out.push(0x31 |> Int::to_byte)
  out.push(0x36 |> Int::to_byte)
  out.push(0x17 |> Int::to_byte)
  // x bytes: 50, 50
  out.push(50 |> Int::to_byte)
  out.push(50 |> Int::to_byte)
  // y bytes: 100, 100 (second is negative)
  out.push(100 |> Int::to_byte)
  out.push(100 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn gvar_test_make_gvar_one_tuple_sparse_point() -> Bytes {
  // gvar header (20 bytes):
  // axisCount=1, sharedTupleCount=0, glyphCount=2, flags=0 (short offsets),
  // dataArrayOffset=26 (20 + 3*2 offsets).
  let out : Array[Byte] = Array::new()
  gvar_test_push_u16_be(out, 1) // majorVersion
  gvar_test_push_u16_be(out, 0) // minorVersion
  gvar_test_push_u16_be(out, 1) // axisCount
  gvar_test_push_u16_be(out, 0) // sharedTupleCount
  gvar_test_push_u32_be(out, gvar_test_u32(0)) // sharedTuplesOffset (unused)
  gvar_test_push_u16_be(out, 2) // glyphCount
  gvar_test_push_u16_be(out, 0) // flags (short offsets)
  gvar_test_push_u32_be(out, gvar_test_u32(26)) // glyphVariationDataArrayOffset
  // offsets array (glyphCount+1 = 3) as u16 words:
  gvar_test_push_u16_be(out, 0) // glyph0 start
  gvar_test_push_u16_be(out, 0) // glyph1 start
  gvar_test_push_u16_be(out, 8) // glyph2 end => 16 bytes data
  // glyph1 variation data (16 bytes):
  gvar_test_push_u16_be(out, 1) // tupleCount (no shared points)
  gvar_test_push_u16_be(out, 10) // dataOffset from start
  gvar_test_push_u16_be(out, 6) // tupleSize
  gvar_test_push_u16_be(out, 0x8000) // tupleIndex: embedded peak
  gvar_test_push_i16_be(out, 0x4000) // peak = 1.0 (F2Dot14)
  // tuple data (6 bytes): points=[1], dx=[10], dy=[0]
  out.push(1 |> Int::to_byte) // point count
  out.push(0 |> Int::to_byte) // run ctrl (1 byte)
  out.push(1 |> Int::to_byte) // delta to point 1
  out.push(0 |> Int::to_byte) // x deltas ctrl (1 byte, i8)
  out.push(10 |> Int::to_byte) // dx=10
  out.push(0x80 |> Int::to_byte) // y deltas ctrl: zeros run_len=1
  Bytes::from_array(out.op_as_view())
}

///|
test "gvar applies sparse tuple + IUP shift for single delta point" {
  let glyph0 = Bytes::from_array(Array::new().op_as_view())
  let glyph1 = gvar_test_glyph_simple_quad()
  let glyf_out : Array[Byte] = Array::new()
  for b in glyph0.iter() {
    glyf_out.push(b)
  }
  let off0 = 0
  let off1 = off0 + glyph0.length()
  for b in glyph1.iter() {
    glyf_out.push(b)
  }
  let off2 = off1 + glyph1.length()
  let loca = gvar_test_make_loca_long(
    Array::from_fixed_array([off0, off1, off2]),
  )
  let sfnt = gvar_test_build_sfnt(
    Array::from_fixed_array([
      (0x6D617870, gvar_test_make_maxp(2)), // "maxp"
      (0x68656164, gvar_test_make_head(1000)), // "head"
      (0x6C6F6361, loca), // "loca"
      (0x676C7966, Bytes::from_array(glyf_out.op_as_view())), // "glyf"
      (0x67766172, gvar_test_make_gvar_one_tuple_sparse_point()), // "gvar"
    ]),
  )
  let font = @moon_skrifa.FontRef::new(sfnt).unwrap()
  let c = OutlineGlyphCollection::from_font(font)

  // Default coords => base outline.
  let base = c
    .path(@moon_skrifa.GlyphId::new((1).to_uint16()), DrawSettings::default())
    .unwrap()
  let expected_base = Array::from_fixed_array([
    PathElement::MoveTo(0.0, 0.0),
    PathElement::QuadTo(50.0, 100.0, 100.0, 0.0),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(base, expected_base), content="true")

  // coords[0] = 0.5 => scalar=0.5, dx=10 => shift=5 applied to entire contour.
  let coords : Array[@moon_skrifa.NormalizedCoord] = Array::from_fixed_array([
    8192,
  ])
  let settings = DrawSettings::unhinted(
    @moon_skrifa.Size::unscaled(),
    @moon_skrifa.LocationRef::new(coords.op_as_view()),
  )
  let varied = c
    .path(@moon_skrifa.GlyphId::new((1).to_uint16()), settings)
    .unwrap()
  let expected_varied = Array::from_fixed_array([
    PathElement::MoveTo(5.0, 0.0),
    PathElement::QuadTo(55.0, 100.0, 105.0, 0.0),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(varied, expected_varied), content="true")
}
