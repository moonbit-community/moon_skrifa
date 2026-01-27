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
fn glyph_metrics_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn glyph_metrics_test_push_i16_be(out : Array[Byte], v : Int) -> Unit {
  glyph_metrics_test_push_u16_be(out, v & 0xFFFF)
}

///|
fn glyph_metrics_test_push_u32_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 24) & mask).to_byte())
  out.push(((u >> 16) & mask).to_byte())
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn glyph_metrics_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  glyph_metrics_test_push_u32_be(out, 0x00010000)
  glyph_metrics_test_push_u16_be(out, num_tables)
  glyph_metrics_test_push_u16_be(out, 0)
  glyph_metrics_test_push_u16_be(out, 0)
  glyph_metrics_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    glyph_metrics_test_push_u32_be(out, tag.to_uint64().to_int())
    glyph_metrics_test_push_u32_be(out, 0)
    glyph_metrics_test_push_u32_be(out, offset)
    glyph_metrics_test_push_u32_be(out, data.length())
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
fn glyph_metrics_test_make_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  glyph_metrics_test_push_u32_be(out, 0x00010000)
  glyph_metrics_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_metrics_test_make_hhea(num_hmetrics : Int) -> Bytes {
  let out : Array[Byte] = Array::make(36, 0 |> Int::to_byte)
  out.set(34, ((num_hmetrics >> 8) & 0xFF).to_byte())
  out.set(35, (num_hmetrics & 0xFF).to_byte())
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_metrics_test_make_hmtx(advance : Int, lsb : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  glyph_metrics_test_push_u16_be(out, advance)
  glyph_metrics_test_push_i16_be(out, lsb)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_metrics_test_make_head(units_per_em : Int) -> Bytes {
  let out : Array[Byte] = Array::make(20, 0 |> Int::to_byte)
  out.set(18, ((units_per_em >> 8) & 0xFF).to_byte())
  out.set(19, (units_per_em & 0xFF).to_byte())
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_metrics_test_make_head_long_loca(units_per_em : Int) -> Bytes {
  let out : Array[Byte] = Array::make(54, 0 |> Int::to_byte)
  out.set(18, ((units_per_em >> 8) & 0xFF).to_byte())
  out.set(19, (units_per_em & 0xFF).to_byte())
  // head.indexToLocFormat at offset 50: 1 => long offsets.
  out.set(50, 0 |> Int::to_byte)
  out.set(51, 1 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_metrics_test_make_loca_long(offsets : Array[Int]) -> Bytes {
  let out : Array[Byte] = Array::new()
  for off in offsets {
    glyph_metrics_test_push_u32_be(out, off)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_metrics_test_glyf_simple_quad() -> Bytes {
  // One contour with 3 points:
  // (0,0) on, (50,100) off, (100,0) on.
  let out : Array[Byte] = Array::new()
  glyph_metrics_test_push_i16_be(out, 1)
  glyph_metrics_test_push_i16_be(out, 0)
  glyph_metrics_test_push_i16_be(out, 0)
  glyph_metrics_test_push_i16_be(out, 100)
  glyph_metrics_test_push_i16_be(out, 100)
  glyph_metrics_test_push_u16_be(out, 2) // endPts[0]
  glyph_metrics_test_push_u16_be(out, 0) // instructionLength
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
fn glyph_metrics_test_make_gvar_phantom_deltas(dx0 : Int, dx1 : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  // gvar header (axisCount=1, glyphCount=1, long offsets)
  glyph_metrics_test_push_u16_be(out, 1) // major
  glyph_metrics_test_push_u16_be(out, 0) // minor
  glyph_metrics_test_push_u16_be(out, 1) // axisCount
  glyph_metrics_test_push_u16_be(out, 0) // sharedTupleCount
  glyph_metrics_test_push_u32_be(out, 0) // sharedTuplesOffset
  glyph_metrics_test_push_u16_be(out, 1) // glyphCount
  glyph_metrics_test_push_u16_be(out, 1) // flags: long offsets
  glyph_metrics_test_push_u32_be(out, 28) // glyphVariationDataArrayOffset
  // Offsets[0..1]
  glyph_metrics_test_push_u32_be(out, 0)
  // glyph variation data length = 21
  glyph_metrics_test_push_u32_be(out, 21)

  // GlyphVariationData (21 bytes)
  glyph_metrics_test_push_u16_be(out, 1) // tupleVariationCount
  glyph_metrics_test_push_u16_be(out, 10) // offsetToData
  glyph_metrics_test_push_u16_be(out, 11) // variationDataSize
  glyph_metrics_test_push_u16_be(out, 0x8000) // tupleIndex: embedded peak tuple
  // peak tuple: 1.0 in F2Dot14
  glyph_metrics_test_push_i16_be(out, 16384)
  // Tuple data: pointCount=0 (all points)
  out.push(0 |> Int::to_byte)
  // xDeltas: 4 int16 deltas (words run)
  out.push(0x83 |> Int::to_byte)
  glyph_metrics_test_push_i16_be(out, dx0)
  glyph_metrics_test_push_i16_be(out, dx1)
  glyph_metrics_test_push_i16_be(out, 0)
  glyph_metrics_test_push_i16_be(out, 0)
  // yDeltas: 4 zeros (zero run)
  out.push(0x43 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

// Build a minimal HVAR table that adds +50 to advance width and lsb when
// coords[0] == 1.0 (16384 in F2Dot14).

///|
fn glyph_metrics_test_make_hvar() -> Bytes {
  let out : Array[Byte] = Array::new()
  // version 1.0 (MajorMinor)
  glyph_metrics_test_push_u16_be(out, 1)
  glyph_metrics_test_push_u16_be(out, 0)
  // itemVariationStoreOffset = 20
  glyph_metrics_test_push_u32_be(out, 20)
  // advanceWidthMappingOffset = 52 (after store)
  glyph_metrics_test_push_u32_be(out, 52)
  // lsbMappingOffset = 52
  glyph_metrics_test_push_u32_be(out, 52)
  // rsbMappingOffset = NULL
  glyph_metrics_test_push_u32_be(out, 0)

  // ItemVariationStore at offset 20
  // format=1
  glyph_metrics_test_push_u16_be(out, 1)
  // variationRegionListOffset = 12 (immediately after header+offsets)
  glyph_metrics_test_push_u32_be(out, 12)
  // itemVariationDataCount=1
  glyph_metrics_test_push_u16_be(out, 1)
  // itemVariationDataOffsets[0] = 22
  glyph_metrics_test_push_u32_be(out, 22)

  // VariationRegionList at offset 20 + 12 = 32
  // axisCount=1, regionCount=1
  glyph_metrics_test_push_u16_be(out, 1)
  glyph_metrics_test_push_u16_be(out, 1)
  // Region 0 axis coords: start=0, peak=1.0, end=1.0 (F2Dot14)
  glyph_metrics_test_push_i16_be(out, 0)
  glyph_metrics_test_push_i16_be(out, 16384)
  glyph_metrics_test_push_i16_be(out, 16384)

  // ItemVariationData at offset 20 + 22 = 42
  // itemCount=1, shortDeltaCount=1, regionIndexCount=1
  glyph_metrics_test_push_u16_be(out, 1)
  glyph_metrics_test_push_u16_be(out, 1)
  glyph_metrics_test_push_u16_be(out, 1)
  // regionIndexes[0] = 0
  glyph_metrics_test_push_u16_be(out, 0)
  // deltaSets[0][0] = +50
  glyph_metrics_test_push_i16_be(out, 50)

  // DeltaSetIndexMap at offset 52: format 0, entryFormat=0x17 (2 bytes, 8-bit inner), mapCount=1, entry=0
  out.push(0 |> Int::to_byte)
  out.push(0x17 |> Int::to_byte)
  glyph_metrics_test_push_u16_be(out, 1)
  glyph_metrics_test_push_u16_be(out, 0)
  Bytes::from_array(out.op_as_view())
}

///|
const GM_TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
const GM_TAG_HHEA : UInt = 0x68686561 // "hhea"

///|
const GM_TAG_HMTX : UInt = 0x686D7478 // "hmtx"

///|
const GM_TAG_HEAD : UInt = 0x68656164 // "head"

///|
const GM_TAG_HVAR : UInt = 0x48564152 // "HVAR"

///|
const GM_TAG_GLYF : UInt = 0x676C7966 // "glyf"

///|
const GM_TAG_LOCA : UInt = 0x6C6F6361 // "loca"

///|
const GM_TAG_GVAR : UInt = 0x67564152 // "gvar"

///|
test "GlyphMetrics basic + HVAR deltas" {
  let sfnt = glyph_metrics_test_build_sfnt(
    Array::from_fixed_array([
      (GM_TAG_MAXP, glyph_metrics_test_make_maxp(1)),
      (GM_TAG_HHEA, glyph_metrics_test_make_hhea(1)),
      (GM_TAG_HMTX, glyph_metrics_test_make_hmtx(500, 10)),
      (GM_TAG_HEAD, glyph_metrics_test_make_head(1000)),
      (GM_TAG_HVAR, glyph_metrics_test_make_hvar()),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let gm0 = font.glyph_metrics(Size::unscaled(), LocationRef::default())
  inspect(
    gm0
    .advance_width(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="500",
  )
  inspect(
    gm0
    .left_side_bearing(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="10",
  )
  let coords = Array::from_fixed_array([16384])
  let gm1 = font.glyph_metrics(
    Size::unscaled(),
    LocationRef::new(coords.op_as_view()),
  )
  inspect(
    gm1
    .advance_width(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="550",
  )
  inspect(
    gm1
    .left_side_bearing(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="60",
  )
}

///|
test "GlyphMetrics bounds from outline path" {
  let glyf = glyph_metrics_test_glyf_simple_quad()
  let loca = glyph_metrics_test_make_loca_long(
    Array::from_fixed_array([0, glyf.length()]),
  )
  let sfnt = glyph_metrics_test_build_sfnt(
    Array::from_fixed_array([
      (GM_TAG_MAXP, glyph_metrics_test_make_maxp(1)),
      (GM_TAG_HHEA, glyph_metrics_test_make_hhea(1)),
      (GM_TAG_HMTX, glyph_metrics_test_make_hmtx(500, 10)),
      (GM_TAG_HEAD, glyph_metrics_test_make_head_long_loca(1000)),
      (GM_TAG_LOCA, loca),
      (GM_TAG_GLYF, glyf),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let gm = font.glyph_metrics(Size::unscaled(), LocationRef::default())
  let b = gm.bounds(GlyphId::new((0).to_uint16())).unwrap()
  inspect(b.x_min().to_int().to_string(), content="0")
  inspect(b.y_min().to_int().to_string(), content="0")
  inspect(b.x_max().to_int().to_string(), content="100")
  inspect(b.y_max().to_int().to_string(), content="100")
}

///|
test "GlyphMetrics gvar phantom deltas fallback" {
  // Empty glyph (no points) but with phantom deltas from gvar.
  let loca = glyph_metrics_test_make_loca_long(Array::from_fixed_array([0, 0]))
  let gvar = glyph_metrics_test_make_gvar_phantom_deltas(10, 30)
  let sfnt = glyph_metrics_test_build_sfnt(
    Array::from_fixed_array([
      (GM_TAG_MAXP, glyph_metrics_test_make_maxp(1)),
      (GM_TAG_HHEA, glyph_metrics_test_make_hhea(1)),
      (GM_TAG_HMTX, glyph_metrics_test_make_hmtx(500, 10)),
      (GM_TAG_HEAD, glyph_metrics_test_make_head_long_loca(1000)),
      (GM_TAG_LOCA, loca),
      (GM_TAG_GLYF, Bytes::from_array(Array::new().op_as_view())),
      (GM_TAG_GVAR, gvar),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let gm0 = font.glyph_metrics(Size::unscaled(), LocationRef::default())
  inspect(
    gm0
    .advance_width(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="500",
  )
  inspect(
    gm0
    .left_side_bearing(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="10",
  )
  let coords = Array::from_fixed_array([16384])
  let gm1 = font.glyph_metrics(
    Size::unscaled(),
    LocationRef::new(coords.op_as_view()),
  )
  inspect(
    gm1
    .advance_width(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="520",
  )
  inspect(
    gm1
    .left_side_bearing(GlyphId::new((0).to_uint16()))
    .unwrap()
    .to_int()
    .to_string(),
    content="20",
  )
}
