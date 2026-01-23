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
fn glyph_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn glyph_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn glyph_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn glyph_test_index1(objects : Array[Array[Byte]]) -> Array[Byte] {
  let count = objects.length()
  let out : Array[Byte] = Array::new()
  glyph_test_push_u16_be(out, count)
  if count == 0 {
    return out
  }
  out.push(1 |> Int::to_byte) // offSize=1
  let offsets : Array[Int] = Array::new()
  let mut off = 1
  offsets.push(off)
  for obj in objects {
    off = off + obj.length()
    offsets.push(off)
  }
  for o in offsets {
    out.push(o |> Int::to_byte)
  }
  for obj in objects {
    for b in obj.iter() {
      out.push(b)
    }
  }
  out
}

///|
fn glyph_test_dict_i32(out : Array[Byte], v : Int) -> Unit {
  // 29 + i32 big endian.
  out.push(29 |> Int::to_byte)
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 24) & mask).to_byte())
  out.push(((u >> 16) & mask).to_byte())
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn glyph_test_build_post_v2() -> Bytes {
  let out : Array[Byte] = Array::new()
  // version 0x00020000
  glyph_test_push_u32_be(out, glyph_test_u32(0x00020000))
  // italicAngle etc, fill zero for 28 bytes
  for _ in 0..<28 {
    out.push(0 |> Int::to_byte)
  }
  // numberOfGlyphs = 1
  glyph_test_push_u16_be(out, 1)
  // glyphNameIndex[0] = 258 => first custom string
  glyph_test_push_u16_be(out, 258)
  // stringData: pascal string "Test"
  out.push(4 |> Int::to_byte)
  out.push(84 |> Int::to_byte)
  out.push(101 |> Int::to_byte)
  out.push(115 |> Int::to_byte)
  out.push(116 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_test_build_cff_custom_charset() -> Bytes {
  // Header (4)
  let out : Array[Byte] = Array::new()
  out.push(1 |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  out.push(4 |> Int::to_byte)
  out.push(1 |> Int::to_byte)

  // Name INDEX ("T")
  let name_ix = glyph_test_index1(
    Array::from_fixed_array([Array::from_fixed_array([84 |> Int::to_byte])]),
  )

  // String INDEX: 1 custom string, for SID=391 => index 0.
  let str_ix = glyph_test_index1(
    Array::from_fixed_array([
      Array::from_fixed_array([65 |> Int::to_byte], // 'A'
      ),
    ]),
  )

  // Global Subrs INDEX (empty)
  let global_ix = glyph_test_index1(Array::new())

  // CharStrings INDEX: 2 glyphs with empty charstrings.
  let char_ix = glyph_test_index1(
    Array::from_fixed_array([Array::new(), Array::new()]),
  )
  let header_len = 4
  let name_len = name_ix.length()

  // Top DICT: charset offset + charstrings offset.
  // We'll place it right after global subrs, so compute offsets.
  // Header + NameIX + TopIX + StrIX + GlobalIX + Charset + CharStrings
  let charset_len = 1 + 2 // format 0 + one SID for gid1
  // Top DICT bytes: charset(i32+op) + charstrings(i32+op) => 6+6=12
  let top_dict_len = 12
  let top_ix_len = 2 + 1 + 2 + top_dict_len
  let string_len = str_ix.length()
  let global_len = global_ix.length()
  let charset_off = header_len + name_len + top_ix_len + string_len + global_len
  let charstrings_off = charset_off + charset_len
  let top_dict : Array[Byte] = Array::new()
  glyph_test_dict_i32(top_dict, charset_off)
  top_dict.push(15 |> Int::to_byte) // charset
  glyph_test_dict_i32(top_dict, charstrings_off)
  top_dict.push(17 |> Int::to_byte) // CharStrings
  let top_ix = glyph_test_index1(Array::from_fixed_array([top_dict]))
  for b in name_ix.iter() {
    out.push(b)
  }
  for b in top_ix.iter() {
    out.push(b)
  }
  for b in str_ix.iter() {
    out.push(b)
  }
  for b in global_ix.iter() {
    out.push(b)
  }

  // Charset at charset_off: format0 + sid for glyph 1 = 391 (0x0187)
  out.push(0 |> Int::to_byte)
  glyph_test_push_u16_be(out, 391)
  for b in char_ix.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn glyph_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  glyph_test_push_u32_be(out, glyph_test_u32(0x00010000))
  glyph_test_push_u16_be(out, num_tables)
  glyph_test_push_u16_be(out, 0)
  glyph_test_push_u16_be(out, 0)
  glyph_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    glyph_test_push_u32_be(out, tag)
    glyph_test_push_u32_be(out, glyph_test_u32(0))
    glyph_test_push_u32_be(out, glyph_test_u32(offset))
    glyph_test_push_u32_be(out, glyph_test_u32(data.length()))
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
const GLYPH_TEST_TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
const GLYPH_TEST_TAG_POST : UInt = 0x706F7374 // "post"

///|
const GLYPH_TEST_TAG_CFF : UInt = 0x43464620 // "CFF "

///|
fn glyph_test_build_maxp(num_glyphs : Int) -> Bytes {
  // maxp: version u32 + numGlyphs u16 (at offset 4); fill minimal 6 bytes.
  let out : Array[Byte] = Array::new()
  glyph_test_push_u32_be(out, glyph_test_u32(0x00010000))
  glyph_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
test "glyph_names from post v2 custom string" {
  let maxp = glyph_test_build_maxp(1)
  let post = glyph_test_build_post_v2()
  let sfnt = glyph_test_build_sfnt(
    Array::from_fixed_array([
      (GLYPH_TEST_TAG_MAXP, maxp),
      (GLYPH_TEST_TAG_POST, post),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let names = font.glyph_names()
  let ok = if names.source() is GlyphNameSource::Post { true } else { false }
  inspect(ok, content="true")
  inspect(names.get(0).unwrap().as_str(), content="Test")
}

///|
test "glyph_names from CFF custom charset + string index" {
  let maxp = glyph_test_build_maxp(2)
  let cff = glyph_test_build_cff_custom_charset()
  let sfnt = glyph_test_build_sfnt(
    Array::from_fixed_array([
      (GLYPH_TEST_TAG_MAXP, maxp),
      (GLYPH_TEST_TAG_CFF, cff),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let names = font.glyph_names()
  let ok = if names.source() is GlyphNameSource::Cff { true } else { false }
  inspect(ok, content="true")
  inspect(names.get(1).unwrap().as_str(), content="A")
}
