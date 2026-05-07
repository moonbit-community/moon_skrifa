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
fn colr_test_build_colr_v1_empty() -> Bytes {
  let out : Array[Byte] = Array::new()
  // header:
  // version=1, numBaseGlyphRecords=0
  colr_test_push_u16_be(out, 1)
  colr_test_push_u16_be(out, 0)
  // baseGlyphRecordsOffset=0, layerRecordsOffset=0, numLayerRecords=0
  colr_test_push_u32_be(out, colr_test_u32(0))
  colr_test_push_u32_be(out, colr_test_u32(0))
  colr_test_push_u16_be(out, 0)
  // v1 extra offsets: all NULL
  colr_test_push_u32_be(out, colr_test_u32(0)) // baseGlyphListOffset
  colr_test_push_u32_be(out, colr_test_u32(0)) // layerListOffset
  colr_test_push_u32_be(out, colr_test_u32(0)) // clipListOffset
  colr_test_push_u32_be(out, colr_test_u32(0)) // varIndexMapOffset
  colr_test_push_u32_be(out, colr_test_u32(0)) // itemVariationStoreOffset
  Bytes::from_array(out.op_as_view())
}

///|
fn colr_test_build_colr_v1_with_base_glyph(gid : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  // header:
  // version=1, no v0 records
  colr_test_push_u16_be(out, 1)
  colr_test_push_u16_be(out, 0)
  colr_test_push_u32_be(out, colr_test_u32(0))
  colr_test_push_u32_be(out, colr_test_u32(0))
  colr_test_push_u16_be(out, 0)
  // v1 baseGlyphList offset = 34
  colr_test_push_u32_be(out, colr_test_u32(34))
  // layerList/clipList/varIndexMap/itemVariationStore = NULL
  colr_test_push_u32_be(out, colr_test_u32(0))
  colr_test_push_u32_be(out, colr_test_u32(0))
  colr_test_push_u32_be(out, colr_test_u32(0))
  colr_test_push_u32_be(out, colr_test_u32(0))
  // BaseGlyphList:
  // numBaseGlyphPaintRecords=1
  colr_test_push_u32_be(out, colr_test_u32(1))
  // record: gid, paintOffset=10 (from baseGlyphList start)
  colr_test_push_u16_be(out, gid)
  colr_test_push_u32_be(out, colr_test_u32(10))
  // PaintSolid (format 2): paletteIndex=3, alpha=1.0
  out.push(2 |> Int::to_byte)
  colr_test_push_u16_be(out, 3)
  colr_test_push_u16_be(out, 0x4000)
  Bytes::from_array(out.op_as_view())
}

///|
struct ColrTestPainter {
  fills : Array[(Int, Int)]
}

///|
impl ColorPainter for ColrTestPainter with push_transform(_p, _t) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with pop_transform(_p) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with push_clip_glyph(_p, _gid) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with push_clip_box(_p, _bb) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with pop_clip(_p) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with fill(_p, _brush) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with fill_glyph(p, gid, _t, brush) {
  if brush is Brush::Solid(palette_index, _) {
    p.fills.push((gid.to_u16().to_int(), palette_index))
  }
}

///|
impl ColorPainter for ColrTestPainter with paint_cached_color_glyph(_p, _gid) {
  Ok(PaintCachedColorGlyph::Unimplemented)
}

///|
impl ColorPainter for ColrTestPainter with push_layer(_p, _mode) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with pop_layer(_p) {
  ()
}

///|
impl ColorPainter for ColrTestPainter with pop_layer_with_mode(_p, _mode) {
  ()
}

///|
test "COLR v0 layers basic" {
  let colr = colr_test_build_colr()
  let sfnt = colr_test_build_sfnt(Array::from_fixed_array([(TAG_COLR, colr)]))
  let font = FontRef::from_bytes(sfnt).unwrap()
  let cg = font.color_glyphs()
  let layers = cg.layers(GlyphId::GlyphId((5).to_uint16())).unwrap()
  inspect(layers.length(), content="2")
  inspect(layers.at(0).glyph_id().to_string(), content="10")
  inspect(layers.at(0).palette_index(), content="1")
  inspect(layers.at(1).glyph_id().to_string(), content="11")
  inspect(layers.at(1).palette_index(), content="2")
}

///|
test "COLR v1: header detection" {
  let colr = colr_test_build_colr_v1_empty()
  let sfnt = colr_test_build_sfnt(Array::from_fixed_array([(TAG_COLR, colr)]))
  let font = FontRef::from_bytes(sfnt).unwrap()
  let cg = font.color_glyphs()
  inspect(cg.version(), content="1")
  inspect(cg.has_colr_v1(), content="true")
  inspect(cg.layers(GlyphId::GlyphId((5).to_uint16())) is None, content="true")
}

///|
test "COLR get_with_format/get APIs" {
  let colr = colr_test_build_colr()
  let sfnt = colr_test_build_sfnt(Array::from_fixed_array([(TAG_COLR, colr)]))
  let font = FontRef::from_bytes(sfnt).unwrap()
  let collection = font.color_glyphs()
  let glyph = collection
    .get_with_format(
      GlyphId::GlyphId((5).to_uint16()),
      ColorGlyphFormat::ColrV0,
    )
    .unwrap()
  inspect(glyph.format() is ColorGlyphFormat::ColrV0, content="true")
  inspect(glyph.layers().unwrap().length(), content="2")
  let painter = ColrTestPainter::{ fills: Array::new() }
  match glyph.paint(LocationRef::default(), painter) {
    Err(_) => inspect("err", content="ok")
    Ok(_) => {
      inspect(painter.fills.length(), content="2")
      let (gid0, palette0) = painter.fills.at(0)
      inspect(gid0, content="10")
      inspect(palette0, content="1")
      let (gid1, palette1) = painter.fills.at(1)
      inspect(gid1, content="11")
      inspect(palette1, content="2")
    }
  }
}

///|
test "COLR v1 get_with_format/get APIs" {
  let colr = colr_test_build_colr_v1_with_base_glyph(8)
  let sfnt = colr_test_build_sfnt(Array::from_fixed_array([(TAG_COLR, colr)]))
  let font = FontRef::from_bytes(sfnt).unwrap()
  let collection = font.color_glyphs()
  let gid = GlyphId::GlyphId((8).to_uint16())
  let glyph = collection.get_with_format(gid, ColorGlyphFormat::ColrV1).unwrap()
  inspect(glyph.format() is ColorGlyphFormat::ColrV1, content="true")
  inspect(
    collection.get(gid).unwrap().format() is ColorGlyphFormat::ColrV1,
    content="true",
  )
  inspect(
    collection.get_with_format(
      GlyphId::GlyphId((9).to_uint16()),
      ColorGlyphFormat::ColrV1,
    )
    is None,
    content="true",
  )
}
