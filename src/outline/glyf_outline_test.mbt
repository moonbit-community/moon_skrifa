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
/// TrueType `glyf` outline tests using synthetic SFNT bytes.
fn glyf_outline_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn glyf_outline_test_push_i16_be(out : Array[Byte], v : Int) -> Unit {
  // Encode low 16 bits in big-endian.
  glyf_outline_test_push_u16_be(out, v)
}

///|
fn glyf_outline_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn glyf_outline_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn glyf_outline_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  glyf_outline_test_push_u32_be(out, glyf_outline_test_u32(0x00010000))
  glyf_outline_test_push_u16_be(out, num_tables)
  glyf_outline_test_push_u16_be(out, 0)
  glyf_outline_test_push_u16_be(out, 0)
  glyf_outline_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    glyf_outline_test_push_u32_be(out, tag)
    glyf_outline_test_push_u32_be(out, glyf_outline_test_u32(0))
    glyf_outline_test_push_u32_be(out, glyf_outline_test_u32(offset))
    glyf_outline_test_push_u32_be(out, glyf_outline_test_u32(data.length()))
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
fn glyf_outline_test_make_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  glyf_outline_test_push_u32_be(out, glyf_outline_test_u32(0x00010000))
  glyf_outline_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyf_outline_test_make_head_long_loca() -> Bytes {
  let out : Array[Byte] = Array::make(54, 0 |> Int::to_byte)
  // head.indexToLocFormat at offset 50: 1 => long offsets.
  out.set(50, 0 |> Int::to_byte)
  out.set(51, 1 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyf_outline_test_make_head_long_loca_with_upem(upem : Int) -> Bytes {
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
fn glyf_outline_test_make_loca_long(offsets : Array[Int]) -> Bytes {
  let out : Array[Byte] = Array::new()
  for off in offsets {
    glyf_outline_test_push_u32_be(out, glyf_outline_test_u32(off))
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn glyf_outline_test_make_font(glyphs : Array[Bytes]) -> @moon_skrifa.FontRef {
  let offsets : Array[Int] = Array::new()
  let glyf_out : Array[Byte] = Array::new()
  let mut off = 0
  offsets.push(off)
  for g in glyphs {
    for b in g.iter() {
      glyf_out.push(b)
    }
    off = off + g.length()
    offsets.push(off)
  }
  let sfnt = glyf_outline_test_build_sfnt(
    Array::from_fixed_array([
      (
        0x6D617870, // "maxp"
        glyf_outline_test_make_maxp(glyphs.length()),
      ),
      (0x68656164, glyf_outline_test_make_head_long_loca()), // "head"
      (0x6C6F6361, glyf_outline_test_make_loca_long(offsets)), // "loca"
      (0x676C7966, Bytes::from_array(glyf_out.op_as_view())), // "glyf"
    ]),
  )
  @moon_skrifa.FontRef::new(sfnt).unwrap()
}

///|
fn glyf_outline_test_make_font_with_head(
  head : Bytes,
  glyphs : Array[Bytes],
) -> @moon_skrifa.FontRef {
  let offsets : Array[Int] = Array::new()
  let glyf_out : Array[Byte] = Array::new()
  let mut off = 0
  offsets.push(off)
  for g in glyphs {
    for b in g.iter() {
      glyf_out.push(b)
    }
    off = off + g.length()
    offsets.push(off)
  }
  let sfnt = glyf_outline_test_build_sfnt(
    Array::from_fixed_array([
      (
        0x6D617870, // "maxp"
        glyf_outline_test_make_maxp(glyphs.length()),
      ),
      (0x68656164, head), // "head"
      (0x6C6F6361, glyf_outline_test_make_loca_long(offsets)), // "loca"
      (0x676C7966, Bytes::from_array(glyf_out.op_as_view())), // "glyf"
    ]),
  )
  @moon_skrifa.FontRef::new(sfnt).unwrap()
}

///|
fn glyf_outline_test_glyph_simple_quad() -> Bytes {
  // One contour with 3 points:
  // (0,0) on, (50,100) off, (100,0) on.
  let out : Array[Byte] = Array::new()
  glyf_outline_test_push_i16_be(out, 1)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 100)
  glyf_outline_test_push_i16_be(out, 100)
  glyf_outline_test_push_u16_be(out, 2) // endPts[0]
  glyf_outline_test_push_u16_be(out, 0) // instructionLength
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
fn glyf_outline_test_glyph_implied_midpoint() -> Bytes {
  // One contour with 4 points:
  // (0,0) on, (50,100) off, (100,100) off, (150,0) on.
  let out : Array[Byte] = Array::new()
  glyf_outline_test_push_i16_be(out, 1)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 150)
  glyf_outline_test_push_i16_be(out, 100)
  glyf_outline_test_push_u16_be(out, 3) // endPts[0]
  glyf_outline_test_push_u16_be(out, 0) // instructionLength
  out.push(0x31 |> Int::to_byte)
  out.push(0x36 |> Int::to_byte)
  out.push(0x32 |> Int::to_byte)
  out.push(0x17 |> Int::to_byte)
  // x bytes: 50, 50, 50
  out.push(50 |> Int::to_byte)
  out.push(50 |> Int::to_byte)
  out.push(50 |> Int::to_byte)
  // y bytes: 100, 100 (last is negative)
  out.push(100 |> Int::to_byte)
  out.push(100 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyf_outline_test_glyph_first_off_second_on() -> Bytes {
  // One contour with 3 points:
  // (50,100) off, (100,0) on, (0,0) on.
  let out : Array[Byte] = Array::new()
  glyf_outline_test_push_i16_be(out, 1)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 100)
  glyf_outline_test_push_i16_be(out, 100)
  glyf_outline_test_push_u16_be(out, 2) // endPts[0]
  glyf_outline_test_push_u16_be(out, 0) // instructionLength
  // flags: off, on, on
  out.push(0x36 |> Int::to_byte)
  out.push(0x17 |> Int::to_byte)
  out.push(0x23 |> Int::to_byte)
  // x bytes: +50, +50, -100
  out.push(50 |> Int::to_byte)
  out.push(50 |> Int::to_byte)
  out.push(100 |> Int::to_byte)
  // y bytes: +100, -100
  out.push(100 |> Int::to_byte)
  out.push(100 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyf_outline_test_glyph_composite_translate(
  comp_gid : Int,
  dx : Int,
  dy : Int,
) -> Bytes {
  // Composite glyph with a single component using XY translation.
  let out : Array[Byte] = Array::new()
  glyf_outline_test_push_i16_be(out, -1)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 0)
  glyf_outline_test_push_i16_be(out, 0)
  // flags = ARG_1_AND_2_ARE_WORDS | ARGS_ARE_XY_VALUES
  glyf_outline_test_push_u16_be(out, 0x0001 | 0x0002)
  glyf_outline_test_push_u16_be(out, comp_gid)
  glyf_outline_test_push_i16_be(out, dx)
  glyf_outline_test_push_i16_be(out, dy)
  Bytes::from_array(out.op_as_view())
}

///|
test "OutlineGlyphCollection::path empty glyph is empty path" {
  let font = glyf_outline_test_make_font(
    Array::from_fixed_array([
      Bytes::from_array(Array::new().op_as_view()),
      glyf_outline_test_glyph_simple_quad(),
    ]),
  )
  let c = OutlineGlyphCollection::from_font(font)
  inspect(c.path(0, DrawSettings::default()).unwrap().length(), content="0")
}

///|
test "glyf simple outline uses MoveTo/QuadTo/Close" {
  let font = glyf_outline_test_make_font(
    Array::from_fixed_array([
      Bytes::from_array(Array::new().op_as_view()),
      glyf_outline_test_glyph_simple_quad(),
    ]),
  )
  let c = OutlineGlyphCollection::from_font(font)
  let path = c.path(1, DrawSettings::default()).unwrap()
  let expected = Array::from_fixed_array([
    PathElement::MoveTo(0, 0),
    PathElement::QuadTo(50, 100, 100, 0),
    PathElement::LineTo(0, 0),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(path, expected), content="true")
}

///|
test "glyf consecutive off-curve points insert implied on-curve midpoint" {
  let font = glyf_outline_test_make_font(
    Array::from_fixed_array([
      Bytes::from_array(Array::new().op_as_view()),
      glyf_outline_test_glyph_implied_midpoint(),
    ]),
  )
  let c = OutlineGlyphCollection::from_font(font)
  let path = c.path(1, DrawSettings::default()).unwrap()
  let expected = Array::from_fixed_array([
    PathElement::MoveTo(0, 0),
    PathElement::QuadTo(50, 100, 75, 100),
    PathElement::QuadTo(100, 100, 150, 0),
    PathElement::LineTo(0, 0),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(path, expected), content="true")
}

///|
test "glyf composite outline translates component path" {
  let font = glyf_outline_test_make_font(
    Array::from_fixed_array([
      Bytes::from_array(Array::new().op_as_view()),
      glyf_outline_test_glyph_simple_quad(),
      glyf_outline_test_glyph_composite_translate(1, 10, 20),
    ]),
  )
  let c = OutlineGlyphCollection::from_font(font)
  let path = c.path(2, DrawSettings::default()).unwrap()
  let expected = Array::from_fixed_array([
    PathElement::MoveTo(10, 20),
    PathElement::QuadTo(60, 120, 110, 20),
    PathElement::LineTo(10, 20),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(path, expected), content="true")
}

///|
test "glyf composite recursion is guarded" {
  let font = glyf_outline_test_make_font(
    Array::from_fixed_array([
      Bytes::from_array(Array::new().op_as_view()),
      glyf_outline_test_glyph_composite_translate(1, 0, 0),
    ]),
  )
  let c = OutlineGlyphCollection::from_font(font)
  let ok = match c.path(1, DrawSettings::default()) {
    None => true
    Some(_) => false
  }
  inspect(ok, content="true")
}

///|
test "path scales with size when unitsPerEm is available" {
  let font = glyf_outline_test_make_font_with_head(
    glyf_outline_test_make_head_long_loca_with_upem(1000),
    Array::from_fixed_array([
      Bytes::from_array(Array::new().op_as_view()),
      glyf_outline_test_glyph_simple_quad(),
    ]),
  )
  let c = OutlineGlyphCollection::from_font(font)
  let settings = DrawSettings::unhinted(
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
  )
  let path = c.path(1, settings).unwrap()
  let expected = Array::from_fixed_array([
    PathElement::MoveTo(0, 0),
    PathElement::QuadTo(1, 2, 2, 0),
    PathElement::LineTo(0, 0),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(path, expected), content="true")
}

///|
test "path_style affects start point selection when first point is off-curve" {
  let font = glyf_outline_test_make_font(
    Array::from_fixed_array([
      Bytes::from_array(Array::new().op_as_view()),
      glyf_outline_test_glyph_first_off_second_on(),
    ]),
  )
  let c = OutlineGlyphCollection::from_font(font)
  let free = c.path(1, DrawSettings::default()).unwrap()
  let expected_free = Array::from_fixed_array([
    PathElement::MoveTo(0, 0),
    PathElement::QuadTo(50, 100, 100, 0),
    PathElement::LineTo(0, 0),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(free, expected_free), content="true")
  let hb = c.path(
    1,
    DrawSettings::default().with_path_style(PathStyle::HarfBuzz),
  )
  let expected_hb = Array::from_fixed_array([
    PathElement::MoveTo(100, 0),
    PathElement::LineTo(0, 0),
    PathElement::QuadTo(50, 100, 100, 0),
    PathElement::Close,
  ])
  inspect(glyf_outline_test_path_eq(hb.unwrap(), expected_hb), content="true")
}

///|
fn glyf_outline_test_path_eq(
  a : Array[PathElement],
  b : Array[PathElement],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let n = a.length()
  for i in 0..<n {
    if !glyf_outline_test_elem_eq(a.at(i), b.at(i)) {
      return false
    }
  }
  true
}

///|
fn glyf_outline_test_elem_eq(a : PathElement, b : PathElement) -> Bool {
  match (a, b) {
    (PathElement::MoveTo(ax, ay), PathElement::MoveTo(bx, by)) =>
      ax == bx && ay == by
    (PathElement::LineTo(ax, ay), PathElement::LineTo(bx, by)) =>
      ax == bx && ay == by
    (
      PathElement::QuadTo(ax0, ay0, ax, ay),
      PathElement::QuadTo(bx0, by0, bx, by),
    ) => ax0 == bx0 && ay0 == by0 && ax == bx && ay == by
    (
      PathElement::CurveTo(ax0, ay0, ax1, ay1, ax, ay),
      PathElement::CurveTo(bx0, by0, bx1, by1, bx, by),
    ) =>
      ax0 == bx0 &&
      ay0 == by0 &&
      ax1 == bx1 &&
      ay1 == by1 &&
      ax == bx &&
      ay == by
    (PathElement::Close, PathElement::Close) => true
    _ => false
  }
}
