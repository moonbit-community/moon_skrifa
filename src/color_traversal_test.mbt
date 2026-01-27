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
fn color_trav_test_push_u8(out : Array[Byte], v : Int) -> Unit {
  out.push(v.to_byte())
}

///|
fn color_trav_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn color_trav_test_push_u24_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 16) & mask).to_byte())
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn color_trav_test_push_u32_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 24) & mask).to_byte())
  out.push(((u >> 16) & mask).to_byte())
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn color_trav_test_push_i16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn color_trav_test_push_fixed_16_16(out : Array[Byte], v : Double) -> Unit {
  let scaled = (v * 65536.0).round().to_int()
  color_trav_test_push_u32_be(out, scaled)
}

///|
fn color_trav_test_push_f2dot14(out : Array[Byte], v : Double) -> Unit {
  let scaled = (v * 16384.0).round().to_int()
  color_trav_test_push_i16_be(out, scaled)
}

///|
fn color_trav_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  color_trav_test_push_u32_be(out, 0x00010000)
  color_trav_test_push_u16_be(out, num_tables)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    color_trav_test_push_u32_be(out, tag.to_uint64().to_int())
    color_trav_test_push_u32_be(out, 0)
    color_trav_test_push_u32_be(out, offset)
    color_trav_test_push_u32_be(out, data.length())
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
const COLOR_TRAV_TEST_TAG_COLR : UInt = 0x434F4C52 // "COLR"

///|
fn color_trav_test_build_colr_v1_layers() -> Bytes {
  let out : Array[Byte] = Array::new()
  // COLR header v1 (34 bytes)
  color_trav_test_push_u16_be(out, 1) // version
  color_trav_test_push_u16_be(out, 0) // numBaseGlyphRecords (v0)
  color_trav_test_push_u32_be(out, 0) // baseGlyphRecordsOffset (v0)
  color_trav_test_push_u32_be(out, 0) // layerRecordsOffset (v0)
  color_trav_test_push_u16_be(out, 0) // numLayerRecords (v0)
  // v1 offsets (filled in now)
  let base_off = 34
  // BaseGlyphList offset
  color_trav_test_push_u32_be(out, base_off)
  // LayerList offset (after BaseGlyphList)
  // BaseGlyphList: u32 count + 1 record (6 bytes) + root paint (6 bytes) = 16 bytes
  let layer_off = base_off + 16
  color_trav_test_push_u32_be(out, layer_off)
  color_trav_test_push_u32_be(out, 0) // clipListOffset
  color_trav_test_push_u32_be(out, 0) // varIndexMapOffset
  color_trav_test_push_u32_be(out, 0) // itemVariationStoreOffset

  // BaseGlyphList
  color_trav_test_push_u32_be(out, 1) // numBaseGlyphPaintRecords
  // record: gid=5, paintOffset=10 (4 + 6)
  color_trav_test_push_u16_be(out, 5)
  color_trav_test_push_u32_be(out, 10)
  // root paint: PaintColrLayers format 1, numLayers=2, firstLayerIndex=0
  color_trav_test_push_u8(out, 1)
  color_trav_test_push_u8(out, 2)
  color_trav_test_push_u32_be(out, 0)

  // LayerList
  color_trav_test_push_u32_be(out, 2) // numLayers
  // offsets: layer0 at 12, layer1 at 23
  color_trav_test_push_u32_be(out, 12)
  color_trav_test_push_u32_be(out, 23)
  // layer0 paint: PaintGlyph(gid=10) -> PaintSolid(pi=1, alpha=1.0)
  color_trav_test_push_u8(out, 10)
  color_trav_test_push_u24_be(out, 6)
  color_trav_test_push_u16_be(out, 10)
  color_trav_test_push_u8(out, 2)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_f2dot14(out, 1.0)
  // layer1 paint: PaintGlyph(gid=11) -> PaintSolid(pi=2, alpha=1.0)
  color_trav_test_push_u8(out, 10)
  color_trav_test_push_u24_be(out, 6)
  color_trav_test_push_u16_be(out, 11)
  color_trav_test_push_u8(out, 2)
  color_trav_test_push_u16_be(out, 2)
  color_trav_test_push_f2dot14(out, 1.0)
  Bytes::from_array(out.op_as_view())
}

///|
fn color_trav_test_build_colr_v1_transform() -> Bytes {
  let out : Array[Byte] = Array::new()
  // COLR header v1 (34 bytes)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u16_be(out, 0)
  let base_off = 34
  let layer_off = base_off + 4 + 6 + (7 + 5 + 24) // count + record + paint bundle
  color_trav_test_push_u32_be(out, base_off)
  color_trav_test_push_u32_be(out, layer_off)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)

  // BaseGlyphList: glyph 7 points to PaintTransform at offset 10
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u16_be(out, 7)
  color_trav_test_push_u32_be(out, 10)

  // PaintTransform (format 12)
  // paint_offset=7 (PaintSolid), transform_offset=12 (Affine2x3)
  color_trav_test_push_u8(out, 12)
  color_trav_test_push_u24_be(out, 7)
  color_trav_test_push_u24_be(out, 12)
  // PaintSolid: pi=9, alpha=1.0
  color_trav_test_push_u8(out, 2)
  color_trav_test_push_u16_be(out, 9)
  color_trav_test_push_f2dot14(out, 1.0)
  // Affine2x3: identity + dx=3, dy=5
  color_trav_test_push_fixed_16_16(out, 1.0)
  color_trav_test_push_fixed_16_16(out, 0.0)
  color_trav_test_push_fixed_16_16(out, 0.0)
  color_trav_test_push_fixed_16_16(out, 1.0)
  color_trav_test_push_fixed_16_16(out, 3.0)
  color_trav_test_push_fixed_16_16(out, 5.0)

  // LayerList: minimal valid table (numLayers=1, offset points to self but unused)
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u32_be(out, 4)
  Bytes::from_array(out.op_as_view())
}

///|
fn color_trav_test_build_colr_v1_composite() -> Bytes {
  let out : Array[Byte] = Array::new()
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u16_be(out, 0)
  let base_off = 34
  let layer_off = base_off + 4 + 6 + (8 + 5 + 5) // count + record + composite + 2 solids
  color_trav_test_push_u32_be(out, base_off)
  color_trav_test_push_u32_be(out, layer_off)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)

  // BaseGlyphList: glyph 12 -> composite paint at offset 10
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u16_be(out, 12)
  color_trav_test_push_u32_be(out, 10)

  // PaintComposite: backdrop at 8, source at 13, mode=Plus(12)
  color_trav_test_push_u8(out, 32)
  color_trav_test_push_u24_be(out, 13) // source offset
  color_trav_test_push_u8(out, 12) // composite mode
  color_trav_test_push_u24_be(out, 8) // backdrop offset
  // backdrop PaintSolid (pi=1)
  color_trav_test_push_u8(out, 2)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_f2dot14(out, 1.0)
  // source PaintSolid (pi=2)
  color_trav_test_push_u8(out, 2)
  color_trav_test_push_u16_be(out, 2)
  color_trav_test_push_f2dot14(out, 1.0)

  // LayerList: minimal valid table
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u32_be(out, 4)
  Bytes::from_array(out.op_as_view())
}

///|
fn color_trav_test_build_colr_v1_cycle() -> Bytes {
  let out : Array[Byte] = Array::new()
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u16_be(out, 0)
  let base_off = 34
  let layer_off = base_off + 4 + 6 + 3 // count + record + paintcolrglyph
  color_trav_test_push_u32_be(out, base_off)
  color_trav_test_push_u32_be(out, layer_off)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)

  // BaseGlyphList: glyph 100 -> PaintColrGlyph at offset 10
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u16_be(out, 100)
  color_trav_test_push_u32_be(out, 10)
  // PaintColrGlyph referencing itself
  color_trav_test_push_u8(out, 11)
  color_trav_test_push_u16_be(out, 100)

  // LayerList: minimal valid table
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u32_be(out, 4)
  Bytes::from_array(out.op_as_view())
}

///|
fn color_trav_test_build_colr_v1_linear_gradient_with_clip() -> Bytes {
  let out : Array[Byte] = Array::new()
  // COLR header v1 (34 bytes)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u16_be(out, 0)
  let base_off = 34
  // BaseGlyphList length: 4 + 6 + (PaintGlyph(6) + PaintLinearGradient(16) + ColorLine(15)) = 47
  let layer_off = base_off + 47
  // LayerList length: 8
  let clip_off = layer_off + 8
  color_trav_test_push_u32_be(out, base_off)
  color_trav_test_push_u32_be(out, layer_off)
  color_trav_test_push_u32_be(out, clip_off)
  color_trav_test_push_u32_be(out, 0) // varIndexMapOffset
  color_trav_test_push_u32_be(out, 0) // itemVariationStoreOffset

  // BaseGlyphList: glyph 1 -> PaintGlyph at offset 10
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u32_be(out, 10)

  // PaintGlyph (format 10): glyph 5, paintOffset=6 (gradient follows)
  color_trav_test_push_u8(out, 10)
  color_trav_test_push_u24_be(out, 6)
  color_trav_test_push_u16_be(out, 5)

  // PaintLinearGradient (format 4), ColorLine at offset 16 (after this table)
  color_trav_test_push_u8(out, 4)
  color_trav_test_push_u24_be(out, 16)
  // p0=(0,0), p1=(100,0), p2=(0,100)
  color_trav_test_push_i16_be(out, 0)
  color_trav_test_push_i16_be(out, 0)
  color_trav_test_push_i16_be(out, 100)
  color_trav_test_push_i16_be(out, 0)
  color_trav_test_push_i16_be(out, 0)
  color_trav_test_push_i16_be(out, 100)

  // ColorLine: extend=Pad(0), 2 stops
  color_trav_test_push_u8(out, 0)
  color_trav_test_push_u16_be(out, 2)
  // stop0: offset=0, pi=1, alpha=1
  color_trav_test_push_f2dot14(out, 0.0)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_f2dot14(out, 1.0)
  // stop1: offset=1, pi=2, alpha=1
  color_trav_test_push_f2dot14(out, 1.0)
  color_trav_test_push_u16_be(out, 2)
  color_trav_test_push_f2dot14(out, 1.0)

  // LayerList: minimal valid table
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u32_be(out, 4)

  // ClipList: one clip for glyph 1, ClipBoxFormat1 at offset 12
  color_trav_test_push_u8(out, 1)
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u24_be(out, 12)
  // ClipBoxFormat1: format=1, (0,0)-(50,60)
  color_trav_test_push_u8(out, 1)
  color_trav_test_push_i16_be(out, 0)
  color_trav_test_push_i16_be(out, 0)
  color_trav_test_push_i16_be(out, 50)
  color_trav_test_push_i16_be(out, 60)
  Bytes::from_array(out.op_as_view())
}

///|
fn color_trav_test_build_colr_v1_var_solid_alpha() -> Bytes {
  let out : Array[Byte] = Array::new()
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u32_be(out, 0)
  color_trav_test_push_u16_be(out, 0)
  let base_off = 34
  // BaseGlyphList length: 4 + 6 + PaintVarSolid(9) = 19
  let layer_off = base_off + 19
  // LayerList length: 8
  let vim_off = layer_off + 8
  // VarIndexMap length: 6
  let ivs_off = vim_off + 6
  color_trav_test_push_u32_be(out, base_off)
  color_trav_test_push_u32_be(out, layer_off)
  color_trav_test_push_u32_be(out, 0) // clipListOffset
  color_trav_test_push_u32_be(out, vim_off)
  color_trav_test_push_u32_be(out, ivs_off)

  // BaseGlyphList: glyph 2 -> PaintVarSolid at offset 10
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u16_be(out, 2)
  color_trav_test_push_u32_be(out, 10)

  // PaintVarSolid: paletteIndex=3, alpha=0.5, varIndexBase=0
  color_trav_test_push_u8(out, 3)
  color_trav_test_push_u16_be(out, 3)
  color_trav_test_push_f2dot14(out, 0.5)
  color_trav_test_push_u32_be(out, 0)

  // LayerList: minimal valid table
  color_trav_test_push_u32_be(out, 1)
  color_trav_test_push_u32_be(out, 4)

  // VarIndexMap (DeltaSetIndexMap): format 0, entryFormat 0x17, mapCount 1, entry 0
  color_trav_test_push_u8(out, 0)
  color_trav_test_push_u8(out, 0x17)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 0)

  // ItemVariationStore: one region, one item delta = +8192 (0.5 in F2Dot14 units)
  color_trav_test_push_u16_be(out, 1) // format
  color_trav_test_push_u32_be(out, 12) // regionListOffset
  color_trav_test_push_u16_be(out, 1) // dataCount
  color_trav_test_push_u32_be(out, 22) // dataOffsets[0]
  // VariationRegionList (at +12): axisCount=1, regionCount=1, start=0, peak=1, end=1
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_i16_be(out, 0)
  color_trav_test_push_i16_be(out, 16384)
  color_trav_test_push_i16_be(out, 16384)
  // ItemVariationData (at +22): itemCount=1, shortDeltaCount=1, regionIndexCount=1, regionIndex=0, delta=8192
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 1)
  color_trav_test_push_u16_be(out, 0)
  color_trav_test_push_i16_be(out, 8192)
  Bytes::from_array(out.op_as_view())
}

///|
priv struct ColorTravTestPainter {
  ops : Array[String]
}

///|
fn ColorTravTestPainter::new() -> ColorTravTestPainter {
  ColorTravTestPainter::{ ops: Array::new() }
}

///|
fn ColorTravTestPainter::dump(self : ColorTravTestPainter) -> String {
  self.ops.join("|")
}

///|
impl ColorPainter for ColorTravTestPainter with push_transform(p, t) {
  p.ops.push(
    "push_transform dx=" + t.dx.to_string() + " dy=" + t.dy.to_string(),
  )
}

///|
impl ColorPainter for ColorTravTestPainter with pop_transform(p) {
  p.ops.push("pop_transform")
}

///|
impl ColorPainter for ColorTravTestPainter with push_clip_glyph(p, gid) {
  p.ops.push("push_clip_glyph " + gid.to_string())
}

///|
impl ColorPainter for ColorTravTestPainter with push_clip_box(p, _bb) {
  p.ops.push("push_clip_box")
}

///|
impl ColorPainter for ColorTravTestPainter with pop_clip(p) {
  p.ops.push("pop_clip")
}

///|
impl ColorPainter for ColorTravTestPainter with fill(p, brush) {
  match brush {
    Solid(pi, alpha) =>
      p.ops.push(
        "fill_solid pi=" +
        pi.to_string() +
        " a=" +
        (alpha * 16384.0).round().to_int().to_string(),
      )
    LinearGradient(_, _, stops, extend) =>
      p.ops.push(
        "fill_linear n=" +
        stops.length().to_string() +
        " e=" +
        extend.raw().to_string(),
      )
    RadialGradient(_, _, _, _, stops, extend) =>
      p.ops.push(
        "fill_radial n=" +
        stops.length().to_string() +
        " e=" +
        extend.raw().to_string(),
      )
    SweepGradient(_, _, _, stops, extend) =>
      p.ops.push(
        "fill_sweep n=" +
        stops.length().to_string() +
        " e=" +
        extend.raw().to_string(),
      )
  }
}

///|
impl ColorPainter for ColorTravTestPainter with fill_glyph(p, gid, _t, brush) {
  p.ops.push("fill_glyph " + gid.to_string())
  ColorPainter::fill(p, brush)
}

///|
impl ColorPainter for ColorTravTestPainter with paint_cached_color_glyph(
  _p,
  _gid,
) {
  Ok(Unimplemented)
}

///|
impl ColorPainter for ColorTravTestPainter with push_layer(p, mode) {
  p.ops.push("push_layer " + mode.raw().to_string())
}

///|
impl ColorPainter for ColorTravTestPainter with pop_layer(p) {
  p.ops.push("pop_layer")
}

///|
impl ColorPainter for ColorTravTestPainter with pop_layer_with_mode(p, mode) {
  p.ops.push("pop_layer " + mode.raw().to_string())
}

///|
test "COLRv1 traversal: layers + glyph + solid" {
  ColorStop::{ offset: 0.0, palette_index: 0, alpha: 1.0 } |> ignore
  let colr = color_trav_test_build_colr_v1_layers()
  let sfnt = color_trav_test_build_sfnt(
    Array::from_fixed_array([(COLOR_TRAV_TEST_TAG_COLR, colr)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let painter = ColorTravTestPainter::new()
  match font.paint_colr_v1(GlyphId::new((5).to_uint16()), painter) {
    Err(_) => inspect("err", content="ok")
    Ok(_) =>
      inspect(
        painter.dump(),
        content="push_clip_glyph 10|fill_solid pi=1 a=16384|pop_clip|push_clip_glyph 11|fill_solid pi=2 a=16384|pop_clip",
      )
  }
}

///|
test "COLRv1 traversal: transform" {
  let colr = color_trav_test_build_colr_v1_transform()
  let sfnt = color_trav_test_build_sfnt(
    Array::from_fixed_array([(COLOR_TRAV_TEST_TAG_COLR, colr)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let painter = ColorTravTestPainter::new()
  match font.paint_colr_v1(GlyphId::new((7).to_uint16()), painter) {
    Err(_) => inspect("err", content="ok")
    Ok(_) =>
      inspect(
        painter.dump(),
        content="push_transform dx=3 dy=5|fill_solid pi=9 a=16384|pop_transform",
      )
  }
}

///|
test "COLRv1 traversal: composite layering order" {
  let colr = color_trav_test_build_colr_v1_composite()
  let sfnt = color_trav_test_build_sfnt(
    Array::from_fixed_array([(COLOR_TRAV_TEST_TAG_COLR, colr)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let painter = ColorTravTestPainter::new()
  match font.paint_colr_v1(GlyphId::new((12).to_uint16()), painter) {
    Err(_) => inspect("err", content="ok")
    Ok(_) =>
      inspect(
        painter.dump(),
        content="push_layer 3|fill_solid pi=1 a=16384|push_layer 12|fill_solid pi=2 a=16384|pop_layer 12|pop_layer 3",
      )
  }
}

///|
test "COLRv1 traversal: paint cycle detection" {
  let colr = color_trav_test_build_colr_v1_cycle()
  let sfnt = color_trav_test_build_sfnt(
    Array::from_fixed_array([(COLOR_TRAV_TEST_TAG_COLR, colr)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let painter = ColorTravTestPainter::new()
  let ok = match font.paint_colr_v1(GlyphId::new((100).to_uint16()), painter) {
    Err(PaintCycleDetected) => true
    _ => false
  }
  inspect(ok, content="true")
}

///|
test "COLRv1 traversal: linear gradient + clip box" {
  let colr = color_trav_test_build_colr_v1_linear_gradient_with_clip()
  let sfnt = color_trav_test_build_sfnt(
    Array::from_fixed_array([(COLOR_TRAV_TEST_TAG_COLR, colr)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let painter = ColorTravTestPainter::new()
  match font.paint_colr_v1(GlyphId::new((1).to_uint16()), painter) {
    Err(_) => inspect("err", content="ok")
    Ok(_) =>
      inspect(
        painter.dump(),
        content="push_clip_box|push_clip_glyph 5|fill_linear n=2 e=0|pop_clip|pop_clip",
      )
  }
}

///|
test "COLRv1 traversal: var solid alpha delta" {
  let colr = color_trav_test_build_colr_v1_var_solid_alpha()
  let sfnt = color_trav_test_build_sfnt(
    Array::from_fixed_array([(COLOR_TRAV_TEST_TAG_COLR, colr)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let painter0 = ColorTravTestPainter::new()
  match font.paint_colr_v1(GlyphId::new((2).to_uint16()), painter0) {
    Err(_) => inspect("err", content="ok")
    Ok(_) => inspect(painter0.dump(), content="fill_solid pi=3 a=8192")
  }
  let coords = Array::from_fixed_array([16384])
  let painter1 = ColorTravTestPainter::new()
  match
    font.paint_colr_v1_at(
      GlyphId::new((2).to_uint16()),
      LocationRef::new(coords.op_as_view()),
      painter1,
    ) {
    Err(_) => inspect("err", content="ok")
    Ok(_) => inspect(painter1.dump(), content="fill_solid pi=3 a=16384")
  }
}
