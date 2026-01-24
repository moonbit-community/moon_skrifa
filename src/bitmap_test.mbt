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
const BITMAP_TEST_TAG_MAXP : UInt = 0x6D617870 // "maxp"

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
fn bitmap_test_build_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  // version 1.0
  bitmap_test_push_u32_be(out, bitmap_test_u32(0x00010000))
  bitmap_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn bitmap_test_build_sbix_with_glyph(
  ppem : Int,
  origin_x : Int,
  origin_y : Int,
  graphic_type : UInt,
  payload : Bytes,
) -> Bytes {
  let data_len = payload.length()
  // Header (12) + strike header (4) + offsets (8) + glyph record header (8) + payload
  let strike_off = 12
  let glyph_data_off = 12
  let glyph_end_off = glyph_data_off + 8 + data_len
  let out : Array[Byte] = Array::new()
  bitmap_test_push_u16_be(out, 1) // version
  bitmap_test_push_u16_be(out, 0) // flags
  bitmap_test_push_u32_be(out, bitmap_test_u32(1)) // numStrikes
  bitmap_test_push_u32_be(out, bitmap_test_u32(strike_off)) // strikeOffsets[0]
  // Strike
  bitmap_test_push_u16_be(out, ppem)
  bitmap_test_push_u16_be(out, 72)
  // glyphDataOffsets[numGlyphs+1] for numGlyphs=1
  bitmap_test_push_u32_be(out, bitmap_test_u32(glyph_data_off))
  bitmap_test_push_u32_be(out, bitmap_test_u32(glyph_end_off))
  // Glyph data
  bitmap_test_push_u16_be(out, origin_x & 0xFFFF)
  bitmap_test_push_u16_be(out, origin_y & 0xFFFF)
  bitmap_test_push_u32_be(out, graphic_type)
  for b in payload.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn bitmap_test_build_cblc_index1(
  ppem_x : Int,
  ppem_y : Int,
  glyph_id : Int,
  image_format : Int,
  image_data_offset : Int,
  glyph_data_len : Int,
  bit_depth : Int,
  major : Int,
) -> Bytes {
  let out : Array[Byte] = Array::new()
  // major/minor
  bitmap_test_push_u16_be(out, major)
  bitmap_test_push_u16_be(out, 0)
  // numSizes = 1
  bitmap_test_push_u32_be(out, bitmap_test_u32(1))
  // BitmapSizeTable (48 bytes)
  // indexSubTableArrayOffset = 8 + 48
  bitmap_test_push_u32_be(out, bitmap_test_u32(56))
  // indexTablesSize (unused)
  bitmap_test_push_u32_be(out, bitmap_test_u32(24))
  // numberOfIndexSubTables = 1
  bitmap_test_push_u32_be(out, bitmap_test_u32(1))
  // colorRef
  bitmap_test_push_u32_be(out, bitmap_test_u32(0))
  // hori + vert sbitLineMetrics (24 bytes)
  for _ in 0..<24 {
    out.push(0 |> Int::to_byte)
  }
  // startGlyphIndex/endGlyphIndex
  bitmap_test_push_u16_be(out, glyph_id)
  bitmap_test_push_u16_be(out, glyph_id)
  // ppemX/Y
  out.push(ppem_x |> Int::to_byte)
  out.push(ppem_y |> Int::to_byte)
  // bitDepth, flags
  out.push(bit_depth |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  // IndexSubTableArray at offset 56
  bitmap_test_push_u16_be(out, glyph_id)
  bitmap_test_push_u16_be(out, glyph_id)
  // additionalOffsetToIndexSubtable = 64
  bitmap_test_push_u32_be(out, bitmap_test_u32(64))
  // IndexSubTable1 at offset 64
  bitmap_test_push_u16_be(out, 1) // indexFormat
  bitmap_test_push_u16_be(out, image_format)
  bitmap_test_push_u32_be(out, bitmap_test_u32(image_data_offset))
  // offsets[0..1]
  bitmap_test_push_u32_be(out, bitmap_test_u32(0))
  bitmap_test_push_u32_be(out, bitmap_test_u32(glyph_data_len))
  Bytes::from_array(out.op_as_view())
}

///|
fn bitmap_test_build_cbdt_format17(
  width : Int,
  height : Int,
  bearing_x : Int,
  bearing_y : Int,
  advance : Int,
  png : Bytes,
  major : Int,
) -> Bytes {
  let out : Array[Byte] = Array::new()
  // major/minor
  bitmap_test_push_u16_be(out, major)
  bitmap_test_push_u16_be(out, 0)
  // small metrics (5 bytes)
  out.push(height |> Int::to_byte)
  out.push(width |> Int::to_byte)
  out.push(bearing_x |> Int::to_byte)
  out.push(bearing_y |> Int::to_byte)
  out.push(advance |> Int::to_byte)
  // png length + bytes
  bitmap_test_push_u32_be(out, bitmap_test_u32(png.length()))
  for b in png.iter() {
    out.push(b)
  }
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

///|
test "bitmap sbix glyph png" {
  // Minimal PNG header with IHDR width/height at bytes 16/20.
  let png_bytes = Bytes::from_array(
    Array::from_fixed_array([
      0x89 |> Int::to_byte,
      0x50 |> Int::to_byte,
      0x4E |> Int::to_byte,
      0x47 |> Int::to_byte,
      0x0D |> Int::to_byte,
      0x0A |> Int::to_byte,
      0x1A |> Int::to_byte,
      0x0A |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x0D |> Int::to_byte,
      0x49 |> Int::to_byte,
      0x48 |> Int::to_byte,
      0x44 |> Int::to_byte,
      0x52 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x02 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x03 |> Int::to_byte,
    ]).op_as_view(),
  )
  let sbix = bitmap_test_build_sbix_with_glyph(
    16, 1, 2, 0x706E6720, // "png "
     png_bytes,
  )
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([
      (BITMAP_TEST_TAG_MAXP, bitmap_test_build_maxp(1)),
      (TAG_SBIX, sbix),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let strikes = font.bitmap_strikes()
  let strike = strikes.get(0).unwrap()
  let glyph = strike.get(0).unwrap()
  let ok = if glyph.format() is BitmapImageFormat::Png { true } else { false }
  inspect(ok, content="true")
  inspect(glyph.ppem_y(), content="16")
  inspect(glyph.origin_x(), content="1")
  inspect(glyph.origin_y(), content="2")
  inspect(glyph.width(), content="Some(2)")
  inspect(glyph.height(), content="Some(3)")
  inspect(glyph.data().length(), content="24")
}

///|
test "bitmap sbix glyph jpg" {
  let jpg_bytes = Bytes::from_array(
    Array::from_fixed_array([
      0xFF |> Int::to_byte,
      0xD8 |> Int::to_byte,
      0xFF |> Int::to_byte,
      0xD9 |> Int::to_byte,
    ]).op_as_view(),
  )
  let sbix = bitmap_test_build_sbix_with_glyph(
    20, 0, 0, 0x6A706720, // "jpg "
     jpg_bytes,
  )
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([
      (BITMAP_TEST_TAG_MAXP, bitmap_test_build_maxp(1)),
      (TAG_SBIX, sbix),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let strike = font.bitmap_strikes().get(0).unwrap()
  let glyph = strike.get(0).unwrap()
  let ok = if glyph.format() is BitmapImageFormat::Jpeg { true } else { false }
  inspect(ok, content="true")
  inspect(glyph.width(), content="None")
  inspect(glyph.height(), content="None")
  inspect(glyph.data().length(), content="4")
}

///|
test "bitmap cbdt/cblc glyph png (format 17 + indexSubTable1)" {
  // Minimal PNG header (24 bytes).
  let png = Bytes::from_array(
    Array::from_fixed_array([
      0x89 |> Int::to_byte,
      0x50 |> Int::to_byte,
      0x4E |> Int::to_byte,
      0x47 |> Int::to_byte,
      0x0D |> Int::to_byte,
      0x0A |> Int::to_byte,
      0x1A |> Int::to_byte,
      0x0A |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x0D |> Int::to_byte,
      0x49 |> Int::to_byte,
      0x48 |> Int::to_byte,
      0x44 |> Int::to_byte,
      0x52 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x02 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x00 |> Int::to_byte,
      0x03 |> Int::to_byte,
    ]).op_as_view(),
  )
  let cbdt = bitmap_test_build_cbdt_format17(2, 3, 1, 2, 0, png, 3)
  // glyph record starts after CBDT header (4 bytes)
  let glyph_len = 5 + 4 + 24
  let cblc = bitmap_test_build_cblc_index1(16, 16, 0, 17, 4, glyph_len, 32, 3)
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([
      (BITMAP_TEST_TAG_MAXP, bitmap_test_build_maxp(1)),
      (TAG_CBLC, cblc),
      (TAG_CBDT, cbdt),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let strikes = font.bitmap_strikes()
  let ok = if strikes.format() is Some(BitmapFormat::Cbdt) {
    true
  } else {
    false
  }
  inspect(ok, content="true")
  let strike = strikes.get(0).unwrap()
  let glyph = strike.get(0).unwrap()
  let ok2 = if glyph.format() is BitmapImageFormat::Png { true } else { false }
  inspect(ok2, content="true")
  inspect(glyph.ppem_y(), content="16")
  inspect(glyph.origin_x(), content="1")
  inspect(glyph.origin_y(), content="2")
  inspect(glyph.width(), content="Some(2)")
  inspect(glyph.height(), content="Some(3)")
  inspect(glyph.data().length(), content="24")
}

///|
test "bitmap ebdt/eblc glyph (format 1 + indexSubTable1)" {
  // EBDT (major=2) with one glyph:
  // small metrics: height=1, width=8, bearing_x=-1, bearing_y=2, advance=0
  // data: 1 byte (byte-aligned)
  let ebdt_out : Array[Byte] = Array::new()
  bitmap_test_push_u16_be(ebdt_out, 2)
  bitmap_test_push_u16_be(ebdt_out, 0)
  ebdt_out.push(1 |> Int::to_byte)
  ebdt_out.push(8 |> Int::to_byte)
  ebdt_out.push(0xFF |> Int::to_byte) // -1
  ebdt_out.push(2 |> Int::to_byte)
  ebdt_out.push(0 |> Int::to_byte)
  ebdt_out.push(0xAA |> Int::to_byte)
  let ebdt = Bytes::from_array(ebdt_out.op_as_view())
  let glyph_len = 5 + 1
  let eblc = bitmap_test_build_cblc_index1(12, 12, 0, 1, 4, glyph_len, 1, 2)
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([
      (BITMAP_TEST_TAG_MAXP, bitmap_test_build_maxp(1)),
      (TAG_EBLC, eblc),
      (TAG_EBDT, ebdt),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let strikes = font.bitmap_strikes()
  let ok = if strikes.format() is Some(BitmapFormat::Ebdt) {
    true
  } else {
    false
  }
  inspect(ok, content="true")
  let glyph = strikes.get(0).unwrap().get(0).unwrap()
  inspect(glyph.width(), content="Some(8)")
  inspect(glyph.height(), content="Some(1)")
  inspect(glyph.origin_x(), content="-1")
  inspect(glyph.origin_y(), content="2")
  inspect(glyph.data().length(), content="1")
}
