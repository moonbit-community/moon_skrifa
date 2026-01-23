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
/// Attributes tests using synthetic SFNT bytes.
fn attr_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn attr_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn attr_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn attr_test_set_u16_be(buf : Array[Byte], offset : Int, v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  buf.set(offset, ((u >> 8) & mask).to_byte())
  buf.set(offset + 1, (u & mask).to_byte())
}

///|
fn attr_test_set_i32_be(buf : Array[Byte], offset : Int, v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  buf.set(offset, ((u >> 24) & mask).to_byte())
  buf.set(offset + 1, ((u >> 16) & mask).to_byte())
  buf.set(offset + 2, ((u >> 8) & mask).to_byte())
  buf.set(offset + 3, (u & mask).to_byte())
}

///|
fn attr_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  attr_test_push_u32_be(out, attr_test_u32(0x00010000))
  attr_test_push_u16_be(out, num_tables)
  attr_test_push_u16_be(out, 0)
  attr_test_push_u16_be(out, 0)
  attr_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    attr_test_push_u32_be(out, tag)
    attr_test_push_u32_be(out, attr_test_u32(0))
    attr_test_push_u32_be(out, attr_test_u32(offset))
    attr_test_push_u32_be(out, attr_test_u32(data.length()))
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
const TAG_HEAD : UInt = 0x68656164 // "head"

///|
const TAG_OS2 : UInt = 0x4F532F32 // "OS/2"

///|
const TAG_POST : UInt = 0x706F7374 // "post"

///|
test "missing_os2 uses head.macStyle italic+bold" {
  let head : Array[Byte] = Array::make(46, 0 |> Int::to_byte)
  // macStyle at offset 44.
  attr_test_set_u16_be(head, 44, 0x0001 | 0x0002)
  let sfnt = attr_test_build_sfnt(
    Array::from_fixed_array([(TAG_HEAD, Bytes::from_array(head.op_as_view()))]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let attrs = font.attributes()
  inspect(attrs.stretch().ratio(), content="1")
  let style_ok = match attrs.style() {
    Italic => true
    _ => false
  }
  inspect(style_ok, content="true")
  inspect(attrs.weight().value(), content="700")
}

///|
test "so_stylish uses OS/2 + post italicAngle" {
  let os2 : Array[Byte] = Array::make(64, 0 |> Int::to_byte)
  // usWeightClass (offset 4) = 800
  attr_test_set_u16_be(os2, 4, 800)
  // usWidthClass (offset 6) = 4 (semi-condensed)
  attr_test_set_u16_be(os2, 6, 4)
  // fsSelection (offset 62): OBLIQUE bit 9 (0x0200)
  attr_test_set_u16_be(os2, 62, 0x0200)
  let post : Array[Byte] = Array::make(8, 0 |> Int::to_byte)
  // version (ignored here)
  attr_test_set_i32_be(post, 0, 0x00030000)
  // italicAngle Fixed 16.16 at offset 4: -14.0 -> -14 * 65536
  attr_test_set_i32_be(post, 4, -14 * 65536)
  let sfnt = attr_test_build_sfnt(
    Array::from_fixed_array([
      (TAG_OS2, Bytes::from_array(os2.op_as_view())),
      (TAG_POST, Bytes::from_array(post.op_as_view())),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let attrs = font.attributes()
  inspect(attrs.stretch().ratio(), content="0.875")
  let style_ok = match attrs.style() {
    Oblique(Some(angle)) => angle == -14.0
    _ => false
  }
  inspect(style_ok, content="true")
  inspect(attrs.weight().value(), content="800")
}
