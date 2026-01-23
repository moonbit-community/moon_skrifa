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
/// Outline format detection tests (glyf/CFF/CFF2).
fn push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn make_sfnt_with_tags(tags : Array[UInt]) -> Bytes {
  let num_tables = tags.length()
  let dir_end = 12 + num_tables * 16
  let out = Array::new()
  push_u32_be(out, u32(0x00010000))
  push_u16_be(out, num_tables)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  for tag in tags {
    push_u32_be(out, tag)
    push_u32_be(out, u32(0))
    push_u32_be(out, u32(dir_end))
    push_u32_be(out, u32(0))
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn make_font(tags : Array[UInt]) -> @moon_skrifa.FontRef {
  @moon_skrifa.FontRef::new(make_sfnt_with_tags(tags)).unwrap()
}

///|
const TAG_GLYF : UInt = 0x676C7966 // "glyf"

///|
const TAG_CFF : UInt = 0x43464620 // "CFF "

///|
const TAG_CFF2 : UInt = 0x43464632 // "CFF2"

///|
test "OutlineGlyphCollection::format None when no font" {
  let c = OutlineGlyphCollection::new()
  inspect(c.format(), content="None")
}

///|
test "OutlineGlyphCollection::format None when no outline tables" {
  let font = make_font(Array::new())
  let c = OutlineGlyphCollection::from_font(font)
  inspect(c.format(), content="None")
}

///|
test "OutlineGlyphCollection::format glyf" {
  let font = make_font(Array::from_fixed_array([TAG_GLYF]))
  let c = OutlineGlyphCollection::from_font(font)
  inspect(c.format() == Some(TAG_GLYF), content="true")
}

///|
test "OutlineGlyphCollection::format CFF" {
  let font = make_font(Array::from_fixed_array([TAG_CFF]))
  let c = OutlineGlyphCollection::from_font(font)
  inspect(c.format() == Some(TAG_CFF), content="true")
}

///|
test "OutlineGlyphCollection::format CFF2" {
  let font = make_font(Array::from_fixed_array([TAG_CFF2]))
  let c = OutlineGlyphCollection::from_font(font)
  inspect(c.format() == Some(TAG_CFF2), content="true")
}

///|
test "OutlineGlyphCollection::format prefers glyf" {
  let font = make_font(Array::from_fixed_array([TAG_CFF, TAG_GLYF, TAG_CFF2]))
  let c = OutlineGlyphCollection::from_font(font)
  inspect(c.format() == Some(TAG_GLYF), content="true")
}
