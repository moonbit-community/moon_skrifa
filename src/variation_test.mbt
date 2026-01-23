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
fn variation_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn variation_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn variation_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn variation_test_fixed_16_16(x : Double) -> UInt {
  (x * 65536.0).round().to_int().reinterpret_as_uint()
}

///|
const TAG_FVAR : UInt = 0x66766172 // "fvar"

///|
fn variation_test_build_fvar_table() -> Bytes {
  let out : Array[Byte] = Array::new()
  // fvar header (16 bytes)
  // major=1 minor=0
  variation_test_push_u16_be(out, 1)
  variation_test_push_u16_be(out, 0)
  // axesArrayOffset=16
  variation_test_push_u16_be(out, 16)
  // reserved
  variation_test_push_u16_be(out, 0)
  // axisCount=1 axisSize=20 instanceCount=1 instanceSize=10 (coords + ps name id)
  variation_test_push_u16_be(out, 1)
  variation_test_push_u16_be(out, 20)
  variation_test_push_u16_be(out, 1)
  variation_test_push_u16_be(out, 10)

  // Axis record: tag "wght", min=100, default=400, max=900, flags=0, nameId=257
  variation_test_push_u32_be(out, variation_test_u32(0x77676874))
  variation_test_push_u32_be(out, variation_test_fixed_16_16(100.0))
  variation_test_push_u32_be(out, variation_test_fixed_16_16(400.0))
  variation_test_push_u32_be(out, variation_test_fixed_16_16(900.0))
  variation_test_push_u16_be(out, 0)
  variation_test_push_u16_be(out, 257)

  // Instance record: subfamilyNameId=258, flags=0, coords[0]=100, psNameId=0
  variation_test_push_u16_be(out, 258)
  variation_test_push_u16_be(out, 0)
  variation_test_push_u32_be(out, variation_test_fixed_16_16(100.0))
  variation_test_push_u16_be(out, 0)
  Bytes::from_array(out.op_as_view())
}

///|
fn variation_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  variation_test_push_u32_be(out, variation_test_u32(0x00010000))
  variation_test_push_u16_be(out, num_tables)
  variation_test_push_u16_be(out, 0)
  variation_test_push_u16_be(out, 0)
  variation_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    variation_test_push_u32_be(out, tag)
    variation_test_push_u32_be(out, variation_test_u32(0))
    variation_test_push_u32_be(out, variation_test_u32(offset))
    variation_test_push_u32_be(out, variation_test_u32(data.length()))
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
test "variation axis + named instance basic" {
  let fvar = variation_test_build_fvar_table()
  let sfnt = variation_test_build_sfnt(
    Array::from_fixed_array([(TAG_FVAR, fvar)]),
  )
  let font = FontRef::new(sfnt).unwrap()
  let axes = font.axes()
  inspect(axes.len(), content="1")
  let axis = axes.get(0).unwrap()
  inspect(axis.tag().to_string(), content="wght")
  inspect(axis.min_value(), content="100")
  inspect(axis.default_value(), content="400")
  inspect(axis.max_value(), content="900")
  inspect(axis.name_id().to_int(), content="257")
  inspect(axis.normalize(100.0), content="-16384")
  let instances = font.named_instances()
  inspect(instances.len(), content="1")
  let inst = instances.get(0).unwrap()
  inspect(inst.subfamily_name_id().to_int(), content="258")
  let loc = inst.location()
  inspect(loc.coords().at(0), content="-16384")
}
