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
/// CFF outline extraction tests using synthetic SFNT bytes.
const CFF_TEST_TAG_CFF : UInt = 0x43464620 // "CFF "

///|
fn cff_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn cff_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn cff_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn cff_test_index1(objects : Array[Array[Byte]]) -> Array[Byte] {
  let count = objects.length()
  let out : Array[Byte] = Array::new()
  cff_test_push_u16_be(out, count)
  if count == 0 {
    return out
  }
  // offSize = 1
  out.push(1 |> Int::to_byte)
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
fn cff_test_dict_i32(out : Array[Byte], v : Int) -> Unit {
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
fn cff_test_cs_int(v : Int) -> Byte {
  // Enough for [-107,107] and [0,100] in this test.
  (v + 139).to_byte()
}

///|
fn cff_test_build_cff_table() -> Bytes {
  // CharStrings:
  let g0 : Array[Byte] = Array::from_fixed_array([14 |> Int::to_byte])
  // 0 0 rmoveto; -107 callsubr; endchar
  let g1 : Array[Byte] = Array::from_fixed_array([
    cff_test_cs_int(0),
    cff_test_cs_int(0),
    21 |> Int::to_byte,
    cff_test_cs_int(-107),
    10 |> Int::to_byte,
    14 |> Int::to_byte,
  ])
  let charstrings = cff_test_index1(Array::from_fixed_array([g0, g1]))

  // Local Subrs:
  // 100 0 rlineto; return
  let s0 : Array[Byte] = Array::from_fixed_array([
    cff_test_cs_int(100),
    cff_test_cs_int(0),
    5 |> Int::to_byte,
    11 |> Int::to_byte,
  ])
  let subrs = cff_test_index1(Array::from_fixed_array([s0]))

  // Private DICT: Subrs offset points right after the dict bytes.
  let private_dict : Array[Byte] = Array::new()
  cff_test_dict_i32(private_dict, 6)
  private_dict.push(19 |> Int::to_byte)
  let private_data : Array[Byte] = Array::new()
  for b in private_dict.iter() {
    private_data.push(b)
  }
  for b in subrs.iter() {
    private_data.push(b)
  }
  let private_size = private_data.length()

  // Header + Name INDEX + Top DICT INDEX + String INDEX + GlobalSubrs INDEX
  // (sizes are constant with our fixed encoding choices).
  let header_len = 4
  let name_ix = cff_test_index1(
    Array::from_fixed_array([
      Array::from_fixed_array([
        84 |> Int::to_byte, // 'T'
        101 |> Int::to_byte, // 'e'
        115 |> Int::to_byte, // 's'
        116 |> Int::to_byte, // 't'
      ]),
    ]),
  )
  let name_len = name_ix.length()
  // CharStrings (i32 + op) + Private (i32 + i32 + op) with our fixed encoding.
  let top_dict_len = 5 + 1 + (5 + 5 + 1)
  let top_ix_len = 2 + 1 + 2 + top_dict_len
  let string_ix_len = 2
  let global_subrs_len = 2
  let charstrings_off = header_len +
    name_len +
    top_ix_len +
    string_ix_len +
    global_subrs_len
  let private_off = charstrings_off + charstrings.length()

  // Top DICT: CharStrings offset + Private range.
  let top_dict : Array[Byte] = Array::new()
  cff_test_dict_i32(top_dict, charstrings_off)
  top_dict.push(17 |> Int::to_byte)
  cff_test_dict_i32(top_dict, private_size)
  cff_test_dict_i32(top_dict, private_off)
  top_dict.push(18 |> Int::to_byte)
  let top_ix = cff_test_index1(Array::from_fixed_array([top_dict]))
  let out : Array[Byte] = Array::new()
  // CFF header: major=1 minor=0 hdrSize=4 offSize=1
  out.push(1 |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  out.push(4 |> Int::to_byte)
  out.push(1 |> Int::to_byte)
  for b in name_ix.iter() {
    out.push(b)
  }
  for b in top_ix.iter() {
    out.push(b)
  }
  // String INDEX (empty)
  cff_test_push_u16_be(out, 0)
  // Global Subrs INDEX (empty)
  cff_test_push_u16_be(out, 0)
  for b in charstrings.iter() {
    out.push(b)
  }
  for b in private_data.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn cff_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  cff_test_push_u32_be(out, cff_test_u32(0x00010000))
  cff_test_push_u16_be(out, num_tables)
  cff_test_push_u16_be(out, 0)
  cff_test_push_u16_be(out, 0)
  cff_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    cff_test_push_u32_be(out, tag)
    cff_test_push_u32_be(out, cff_test_u32(0))
    cff_test_push_u32_be(out, cff_test_u32(offset))
    cff_test_push_u32_be(out, cff_test_u32(data.length()))
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
fn cff_test_elem_eq(a : PathElement, b : PathElement) -> Bool {
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
fn cff_test_path_eq(a : Array[PathElement], b : Array[PathElement]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let n = a.length()
  for i in 0..<n {
    if !cff_test_elem_eq(a.at(i), b.at(i)) {
      return false
    }
  }
  true
}

///|
test "CFF outline path uses callsubr (local subrs)" {
  let cff = cff_test_build_cff_table()
  let sfnt = cff_test_build_sfnt(
    Array::from_fixed_array([(CFF_TEST_TAG_CFF, cff)]),
  )
  let font = @moon_skrifa.FontRef::new(sfnt).unwrap()
  let c = OutlineGlyphCollection::from_font(font)
  let path = c.path(1, DrawSettings::default()).unwrap()
  let expected = Array::from_fixed_array([
    PathElement::MoveTo(0, 0),
    PathElement::LineTo(100, 0),
    PathElement::LineTo(0, 0),
    PathElement::Close,
  ])
  inspect(cff_test_path_eq(path, expected), content="true")
}
