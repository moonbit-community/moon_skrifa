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
/// Minimal metrics tests using synthetic SFNT bytes.
fn metrics_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn metrics_test_push_i16_be(out : Array[Byte], v : Int) -> Unit {
  metrics_test_push_u16_be(out, v & 0xFFFF)
}

///|
fn metrics_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn metrics_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn metrics_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()

  // sfnt version
  metrics_test_push_u32_be(out, metrics_test_u32(0x00010000))
  // numTables + unused search parameters
  metrics_test_push_u16_be(out, num_tables)
  metrics_test_push_u16_be(out, 0)
  metrics_test_push_u16_be(out, 0)
  metrics_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    metrics_test_push_u32_be(out, tag)
    metrics_test_push_u32_be(out, metrics_test_u32(0))
    metrics_test_push_u32_be(out, metrics_test_u32(offset))
    metrics_test_push_u32_be(out, metrics_test_u32(data.length()))
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
fn metrics_test_make_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  // version 1.0
  metrics_test_push_u32_be(out, metrics_test_u32(0x00010000))
  metrics_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn metrics_test_make_hhea(num_hmetrics : Int) -> Bytes {
  // numberOfHMetrics at offset 34.
  let out : Array[Byte] = Array::make(36, 0 |> Int::to_byte)
  let hi = ((num_hmetrics >> 8) & 0xFF) |> Int::to_byte
  let lo = (num_hmetrics & 0xFF) |> Int::to_byte
  out.set(34, hi)
  out.set(35, lo)
  Bytes::from_array(out.op_as_view())
}

///|
fn metrics_test_make_hmtx() -> Bytes {
  // numGlyphs=3, numberOfHMetrics=2
  // gid0: adv=500, lsb=-10
  // gid1: adv=600, lsb=20
  // gid2: adv=600 (repeat last), lsb=30 (extra)
  let out : Array[Byte] = Array::new()
  metrics_test_push_u16_be(out, 500)
  metrics_test_push_i16_be(out, -10)
  metrics_test_push_u16_be(out, 600)
  metrics_test_push_i16_be(out, 20)
  metrics_test_push_i16_be(out, 30)
  Bytes::from_array(out.op_as_view())
}

///|
const TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
const TAG_HHEA : UInt = 0x68686561 // "hhea"

///|
const TAG_HMTX : UInt = 0x686D7478 // "hmtx"

///|
test "Metrics basic accessors and lookup" {
  let sfnt = metrics_test_build_sfnt(
    Array::from_fixed_array([
      (TAG_MAXP, metrics_test_make_maxp(3)),
      (TAG_HHEA, metrics_test_make_hhea(2)),
      (TAG_HMTX, metrics_test_make_hmtx()),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let m = Metrics::new(font).unwrap()
  inspect(m.num_glyphs(), content="3")
  inspect(m.number_of_hmetrics(), content="2")
  inspect(m.advance_width(0), content="Some(500)")
  inspect(m.lsb(0), content="Some(-10)")
  inspect(m.advance_width(1), content="Some(600)")
  inspect(m.lsb(1), content="Some(20)")
  inspect(m.advance_width(2), content="Some(600)")
  inspect(m.lsb(2), content="Some(30)")
}

///|
test "Metrics out of range glyph id" {
  let sfnt = metrics_test_build_sfnt(
    Array::from_fixed_array([
      (TAG_MAXP, metrics_test_make_maxp(1)),
      (TAG_HHEA, metrics_test_make_hhea(1)),
      (
        TAG_HMTX,
        Bytes::from_array(
          Array::from_fixed_array([
            0 |> Int::to_byte,
            10 |> Int::to_byte,
            0 |> Int::to_byte,
            0 |> Int::to_byte,
          ]).op_as_view(),
        ),
      ),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let m = Metrics::new(font).unwrap()
  inspect(m.advance_width(1), content="None")
  inspect(m.lsb(1), content="None")
}

///|
test "Metrics::new returns None when table missing" {
  let sfnt = metrics_test_build_sfnt(
    Array::from_fixed_array([
      (TAG_MAXP, metrics_test_make_maxp(1)),
      (TAG_HHEA, metrics_test_make_hhea(1)),
    ]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let ok = match Metrics::new(font) {
    None => true
    Some(_) => false
  }
  inspect(ok, content="true")
}
