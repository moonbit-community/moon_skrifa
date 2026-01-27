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
/// Charmap tests using synthetic SFNT bytes (format 4 / 12 / 14).
fn cmap_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn cmap_test_push_i16_be(out : Array[Byte], v : Int) -> Unit {
  let u = (v & 0xFFFF).reinterpret_as_uint()
  cmap_test_push_u16_be(out, u.to_uint64().to_int())
}

///|
fn cmap_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn cmap_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn cmap_test_push_u24_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 16) & mask).to_byte())
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn make_sfnt_with_table(tag : UInt, table : Bytes) -> Bytes {
  let out : Array[Byte] = Array::new()
  // sfnt version
  cmap_test_push_u32_be(out, cmap_test_u32(0x00010000))
  // numTables=1, searchRange/entrySelector/rangeShift=0
  cmap_test_push_u16_be(out, 1)
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 0)
  // table record
  cmap_test_push_u32_be(out, tag)
  cmap_test_push_u32_be(out, cmap_test_u32(0))
  cmap_test_push_u32_be(out, cmap_test_u32(28))
  cmap_test_push_u32_be(out, cmap_test_u32(table.length()))
  for b in table.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn make_cmap_table(records : Array[(Int, Int, Bytes)]) -> Bytes {
  // cmap header + encoding records + subtables
  let out : Array[Byte] = Array::new()
  let num_tables = records.length()
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, num_tables)
  let header_len = 4 + num_tables * 8
  let mut offset = header_len
  for rec in records {
    let (platform, encoding, sub) = rec
    cmap_test_push_u16_be(out, platform)
    cmap_test_push_u16_be(out, encoding)
    cmap_test_push_u32_be(out, cmap_test_u32(offset))
    offset = offset + sub.length()
  }
  for rec in records {
    let (_, _, sub) = rec
    for b in sub.iter() {
      out.push(b)
    }
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn make_cmap_subtable_format4_delta(
  start_code : Int,
  end_code : Int,
  start_gid : Int,
) -> Bytes {
  // Map [start_code..end_code] to [start_gid..] via idDelta; include required
  // 0xFFFF sentinel segment.
  let seg_count = 2
  let fmt4_len = 32
  let out : Array[Byte] = Array::new()
  cmap_test_push_u16_be(out, 4)
  cmap_test_push_u16_be(out, fmt4_len)
  cmap_test_push_u16_be(out, 0) // language
  cmap_test_push_u16_be(out, seg_count * 2) // segCountX2
  cmap_test_push_u16_be(out, 0) // searchRange
  cmap_test_push_u16_be(out, 0) // entrySelector
  cmap_test_push_u16_be(out, 0) // rangeShift

  // endCode[2]
  cmap_test_push_u16_be(out, end_code)
  cmap_test_push_u16_be(out, 0xFFFF)
  cmap_test_push_u16_be(out, 0) // reservedPad

  // startCode[2]
  cmap_test_push_u16_be(out, start_code)
  cmap_test_push_u16_be(out, 0xFFFF)

  // idDelta[2] = [(start_gid - start_code) mod 65536, 1]
  let delta = (start_gid - start_code) & 0xFFFF
  cmap_test_push_i16_be(out, delta)
  cmap_test_push_i16_be(out, 1)

  // idRangeOffset[2] = [0, 0]
  cmap_test_push_u16_be(out, 0)
  cmap_test_push_u16_be(out, 0)
  Bytes::from_array(out.op_as_view())
}

///|
fn make_cmap_subtable_format12_single(
  start_cp : Int,
  end_cp : Int,
  start_gid : Int,
) -> Bytes {
  let fmt12_len = 28
  let out : Array[Byte] = Array::new()
  cmap_test_push_u16_be(out, 12)
  cmap_test_push_u16_be(out, 0) // reserved
  cmap_test_push_u32_be(out, cmap_test_u32(fmt12_len))
  cmap_test_push_u32_be(out, cmap_test_u32(0)) // language
  cmap_test_push_u32_be(out, cmap_test_u32(1)) // nGroups
  // group: [start_cp..end_cp] -> start_gid
  cmap_test_push_u32_be(out, cmap_test_u32(start_cp))
  cmap_test_push_u32_be(out, cmap_test_u32(end_cp))
  cmap_test_push_u32_be(out, cmap_test_u32(start_gid))
  Bytes::from_array(out.op_as_view())
}

///|
fn make_cmap_subtable_format14(
  selector : Int,
  default_ranges : Array[(Int, Int)], // (start, end)
  non_default : Array[(Int, Int)], // (codepoint, glyph_id)
) -> Bytes {
  // Format 14: one selector record with optional default + non-default tables.
  let out : Array[Byte] = Array::new()
  let num_records = 1
  let header_len = 10
  let records_len = 11 * num_records
  let default_len = 4 + default_ranges.length() * 4
  let non_default_len = 4 + non_default.length() * 5
  let default_off = if default_ranges.is_empty() {
    0
  } else {
    header_len + records_len
  }
  let non_default_off = if non_default.is_empty() {
    0
  } else {
    header_len + records_len + default_len
  }
  let total_len = header_len + records_len + default_len + non_default_len
  cmap_test_push_u16_be(out, 14)
  cmap_test_push_u32_be(out, cmap_test_u32(total_len))
  cmap_test_push_u32_be(out, cmap_test_u32(num_records))

  // VarSelectorRecord
  cmap_test_push_u24_be(out, selector)
  cmap_test_push_u32_be(out, cmap_test_u32(default_off))
  cmap_test_push_u32_be(out, cmap_test_u32(non_default_off))

  // Default UVS table
  cmap_test_push_u32_be(out, cmap_test_u32(default_ranges.length()))
  for r in default_ranges {
    let (start, end) = r
    let addl = (end - start) & 0xFF
    cmap_test_push_u24_be(out, start)
    out.push(addl.to_byte())
  }

  // Non-default UVS table
  cmap_test_push_u32_be(out, cmap_test_u32(non_default.length()))
  for m in non_default {
    let (cp, gid) = m
    cmap_test_push_u24_be(out, cp)
    cmap_test_push_u16_be(out, gid)
  }
  Bytes::from_array(out.op_as_view())
}

///|
const TAG_CMAP : UInt = 0x636D6170 // "cmap"

///|
test "charmap: choose format 12 over 4" {
  let fmt4 = make_cmap_subtable_format4_delta(0x0041, 0x0041, 5)
  let fmt12 = make_cmap_subtable_format12_single(0x1F600, 0x1F600, 100)
  let cmap_table = make_cmap_table(
    Array::from_fixed_array([
      // Windows UCS-2
      (3, 1, fmt4),
      // Windows UCS-4
      (3, 10, fmt12),
    ]),
  )
  let font = FontRef::new(make_sfnt_with_table(TAG_CMAP, cmap_table)).unwrap()
  let cmap = font.charmap()
  inspect(cmap.has_map(), content="true")
  inspect(cmap.map(0x1F600), content="Some(100)")
}

///|
test "charmap: choose format 4 when only BMP mapping" {
  let fmt4 = make_cmap_subtable_format4_delta(0x0041, 0x0041, 5)
  let cmap_table = make_cmap_table(Array::from_fixed_array([(3, 1, fmt4)]))
  let font = FontRef::new(make_sfnt_with_table(TAG_CMAP, cmap_table)).unwrap()
  let cmap = font.charmap()
  inspect(cmap.map(0x41), content="Some(5)")
  inspect(cmap.map(0x1F600), content="None")
}

///|
test "charmap: symbol mapping duplicates 0..FF into F000..F0FF" {
  // Map U+F001..U+F003 -> GID 1..3.
  let fmt4 = make_cmap_subtable_format4_delta(0xF001, 0xF003, 1)
  let fmt12 = make_cmap_subtable_format12_single(0x1F600, 0x1F600, 100)
  let cmap_table = make_cmap_table(
    Array::from_fixed_array([(3, 10, fmt12), (3, 0, fmt4)], // symbol
    ),
  )
  let font = FontRef::new(make_sfnt_with_table(TAG_CMAP, cmap_table)).unwrap()
  let cmap = font.charmap()
  inspect(cmap.is_symbol(), content="true")
  inspect(cmap.map(0xF001), content="Some(1)")
  inspect(cmap.map(0x1), content="Some(1)")
  inspect(cmap.map(0x2), content="Some(2)")
  inspect(cmap.map(0x3), content="Some(3)")
  // Symbol mapping is selected, so UCS-4 mapping is not used.
  inspect(cmap.map(0x1F600), content="None")
}

///|
test "charmap: format 14 map_variant + variant_mappings" {
  // Provide a dummy codepoint map so Charmap::has_map() is true.
  let fmt4 = make_cmap_subtable_format4_delta(0x0041, 0x0041, 1)
  let selector = 0xE0100
  let fmt14 = make_cmap_subtable_format14(
    selector,
    Array::from_fixed_array([(0x4E00, 0x4E06)]),
    Array::from_fixed_array([(0x4E08, 25), (0x4E09, 26)]),
  )
  let cmap_table = make_cmap_table(
    Array::from_fixed_array([(3, 1, fmt4), (0, 5, fmt14)]),
  )
  let font = FontRef::new(make_sfnt_with_table(TAG_CMAP, cmap_table)).unwrap()
  let cmap = font.charmap()
  inspect(cmap.has_variant_map(), content="true")
  let v0 = cmap.map_variant(0x4E00, selector.reinterpret_as_uint())
  inspect(v0 is Some(UseDefault), content="true")
  let v1 = cmap.map_variant(0x4E08, selector.reinterpret_as_uint())
  let v1_ok = match v1 {
    Some(Variant(gid)) => gid == 25
    _ => false
  }
  inspect(v1_ok, content="true")
  inspect(
    cmap.map_variant(0x61, selector.reinterpret_as_uint()) is None,
    content="true",
  )
  for entry in cmap.variant_mappings() {
    let (cp, sel, variant) = entry
    let ok = match (cmap.map_variant(cp, sel), variant) {
      (Some(UseDefault), UseDefault) => true
      (Some(Variant(a)), Variant(b)) => a == b
      _ => false
    }
    inspect(ok, content="true")
  }
}

///|
test "charmap: mappings are consistent with map()" {
  let fmt4 = make_cmap_subtable_format4_delta(0x0041, 0x0043, 1)
  let cmap_table = make_cmap_table(Array::from_fixed_array([(3, 1, fmt4)]))
  let font = FontRef::new(make_sfnt_with_table(TAG_CMAP, cmap_table)).unwrap()
  let cmap = font.charmap()
  for m in cmap.mappings() {
    let (cp, gid) = m
    inspect(gid != 0, content="true")
    inspect(cmap.map(cp), content="Some(" + gid.to_string() + ")")
  }
}
