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
/// CFF2 outline extraction tests using synthetic SFNT bytes.
fn cff2_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn cff2_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn cff2_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn cff2_test_index2(objects : Array[Array[Byte]]) -> Array[Byte] {
  let count = objects.length()
  let out : Array[Byte] = Array::new()
  cff2_test_push_u32_be(out, cff2_test_u32(count))
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
fn cff2_test_dict_i32(out : Array[Byte], v : Int) -> Unit {
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
fn cff2_test_cs_int(v : Int) -> Byte {
  (v + 139).to_byte()
}

///|
fn cff2_test_build_cff2_table() -> Bytes {
  // CharStrings:
  let g0 : Array[Byte] = Array::from_fixed_array([14 |> Int::to_byte])
  // 0 0 rmoveto; 100 0 rlineto; endchar
  let g1 : Array[Byte] = Array::from_fixed_array([
    cff2_test_cs_int(0),
    cff2_test_cs_int(0),
    21 |> Int::to_byte,
    cff2_test_cs_int(100),
    cff2_test_cs_int(0),
    5 |> Int::to_byte,
    14 |> Int::to_byte,
  ])
  let charstrings = cff2_test_index2(Array::from_fixed_array([g0, g1]))
  let header_size = 5
  let global_subrs = cff2_test_index2(Array::new()) // empty Index2 => 4 bytes

  // Top DICT: CharStrings offset only.
  let top_dict_template : Array[Byte] = Array::new()
  cff2_test_dict_i32(top_dict_template, 0)
  top_dict_template.push(17 |> Int::to_byte)
  let top_len = top_dict_template.length()
  let charstrings_off = header_size + top_len + global_subrs.length()
  let top_dict : Array[Byte] = Array::new()
  cff2_test_dict_i32(top_dict, charstrings_off)
  top_dict.push(17 |> Int::to_byte)
  let out : Array[Byte] = Array::new()
  // Header: major=2 minor=0 headerSize=5 topDictLength=7
  out.push(2 |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  out.push(header_size |> Int::to_byte)
  cff2_test_push_u16_be(out, top_len)
  for b in top_dict.iter() {
    out.push(b)
  }
  for b in global_subrs.iter() {
    out.push(b)
  }
  for b in charstrings.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn cff2_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  cff2_test_push_u32_be(out, cff2_test_u32(0x00010000))
  cff2_test_push_u16_be(out, num_tables)
  cff2_test_push_u16_be(out, 0)
  cff2_test_push_u16_be(out, 0)
  cff2_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    cff2_test_push_u32_be(out, tag)
    cff2_test_push_u32_be(out, cff2_test_u32(0))
    cff2_test_push_u32_be(out, cff2_test_u32(offset))
    cff2_test_push_u32_be(out, cff2_test_u32(data.length()))
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
fn cff2_test_elem_eq(a : PathElement, b : PathElement) -> Bool {
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

///|
fn cff2_test_path_eq(a : Array[PathElement], b : Array[PathElement]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let n = a.length()
  for i in 0..<n {
    if !cff2_test_elem_eq(a.at(i), b.at(i)) {
      return false
    }
  }
  true
}

///|
test "CFF2 outline path basic" {
  let cff2 = cff2_test_build_cff2_table()
  let sfnt = cff2_test_build_sfnt(Array::from_fixed_array([(TAG_CFF2, cff2)]))
  let font = @moon_skrifa.FontRef::new(sfnt).unwrap()
  let c = OutlineGlyphCollection::from_font(font)
  let path = c.path(1).unwrap()
  let expected = Array::from_fixed_array([
    PathElement::MoveTo(0, 0),
    PathElement::LineTo(100, 0),
    PathElement::LineTo(0, 0),
    PathElement::Close,
  ])
  inspect(cff2_test_path_eq(path, expected), content="true")
}
