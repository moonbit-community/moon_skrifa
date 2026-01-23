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
fn fm_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn fm_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn fm_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn fm_test_write_u16_be(buf : Array[Byte], pos : Int, v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  buf.set(pos, ((u >> 8) & mask).to_byte())
  buf.set(pos + 1, (u & mask).to_byte())
}

///|
fn fm_test_write_i16_be(buf : Array[Byte], pos : Int, v : Int) -> Unit {
  fm_test_write_u16_be(buf, pos, v & 0xFFFF)
}

///|
fn fm_test_write_u32_be(buf : Array[Byte], pos : Int, v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  buf.set(pos, ((v >> 24) & mask).to_byte())
  buf.set(pos + 1, ((v >> 16) & mask).to_byte())
  buf.set(pos + 2, ((v >> 8) & mask).to_byte())
  buf.set(pos + 3, (v & mask).to_byte())
}

///|
fn fm_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  fm_test_push_u32_be(out, fm_test_u32(0x00010000))
  fm_test_push_u16_be(out, num_tables)
  fm_test_push_u16_be(out, 0)
  fm_test_push_u16_be(out, 0)
  fm_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    fm_test_push_u32_be(out, tag)
    fm_test_push_u32_be(out, fm_test_u32(0))
    fm_test_push_u32_be(out, fm_test_u32(offset))
    fm_test_push_u32_be(out, fm_test_u32(data.length()))
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
const FM_TAG_HEAD : UInt = 0x68656164 // "head"

///|
const FM_TAG_HHEA : UInt = 0x68686561 // "hhea"

///|
const FM_TAG_OS2 : UInt = 0x4F532F32 // "OS/2"

///|
const FM_TAG_POST : UInt = 0x706F7374 // "post"

///|
fn fm_test_build_head(units_per_em : Int) -> Bytes {
  // head needs unitsPerEm at offset 18 (u16).
  let buf : Array[Byte] = Array::make(54, 0 |> Int::to_byte)
  fm_test_write_u16_be(buf, 18, units_per_em)
  Bytes::from_array(buf.op_as_view())
}

///|
fn fm_test_build_hhea(ascent : Int, descent : Int, line_gap : Int) -> Bytes {
  // hhea: ascender at 4, descender at 6, lineGap at 8.
  let buf : Array[Byte] = Array::make(36, 0 |> Int::to_byte)
  fm_test_write_i16_be(buf, 4, ascent)
  fm_test_write_i16_be(buf, 6, descent)
  fm_test_write_i16_be(buf, 8, line_gap)
  Bytes::from_array(buf.op_as_view())
}

///|
fn fm_test_build_post(
  is_fixed_pitch : Bool,
  ul_pos : Int,
  ul_thick : Int,
) -> Bytes {
  // post: italicAngle fixed at 4 (use 0), underline pos/thickness at 8/10, isFixedPitch u32 at 12.
  let buf : Array[Byte] = Array::make(16, 0 |> Int::to_byte)
  // version 3.0 at 0
  fm_test_write_u32_be(buf, 0, fm_test_u32(0x00030000))
  // italicAngle 0
  fm_test_write_u32_be(buf, 4, fm_test_u32(0))
  fm_test_write_i16_be(buf, 8, ul_pos)
  fm_test_write_i16_be(buf, 10, ul_thick)
  fm_test_write_u32_be(buf, 12, fm_test_u32(if is_fixed_pitch { 1 } else { 0 }))
  Bytes::from_array(buf.op_as_view())
}

///|
fn fm_test_build_os2(
  use_typo : Bool,
  typo_a : Int,
  typo_d : Int,
  typo_gap : Int,
) -> Bytes {
  // Only fields we care about: fsSelection at 62, typo asc/desc/gap at 68/70/72.
  let buf : Array[Byte] = Array::make(78, 0 |> Int::to_byte)
  fm_test_write_u16_be(buf, 62, if use_typo { 0x0080 } else { 0 })
  fm_test_write_i16_be(buf, 68, typo_a)
  fm_test_write_i16_be(buf, 70, typo_d)
  fm_test_write_i16_be(buf, 72, typo_gap)
  Bytes::from_array(buf.op_as_view())
}

///|
test "FontMetrics prefers OS/2 typo metrics when flag set" {
  let head = fm_test_build_head(1000)
  let hhea = fm_test_build_hhea(800, -200, 0)
  let os2 = fm_test_build_os2(true, 900, -250, 10)
  let post = fm_test_build_post(true, -50, 20)
  let sfnt = fm_test_build_sfnt(
    Array::from_fixed_array([
      (FM_TAG_HEAD, head),
      (FM_TAG_HHEA, hhea),
      (FM_TAG_OS2, os2),
      (FM_TAG_POST, post),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let m = font.font_metrics(Size::unscaled())
  inspect(m.units_per_em().to_int(), content="1000")
  inspect(m.ascent(), content="900")
  inspect(m.descent(), content="-250")
  inspect(m.leading(), content="10")
  inspect(m.is_monospace(), content="true")
  inspect(m.underline().unwrap().offset(), content="-50")
  inspect(m.underline().unwrap().thickness(), content="20")
}
