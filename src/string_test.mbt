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
/// Localized strings tests using synthetic SFNT bytes.
fn string_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn string_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn string_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn string_test_encode_utf16be(s : String) -> Array[Byte] {
  let out : Array[Byte] = Array::new()
  for ch in s {
    let cp = ch.to_int()
    if cp < 0 || cp > 0x10FFFF {
      continue
    }
    if cp <= 0xFFFF {
      // Skip surrogate code points.
      if cp >= 0xD800 && cp <= 0xDFFF {
        continue
      }
      string_test_push_u16_be(out, cp)
    } else {
      let v = cp - 0x10000
      let hi = 0xD800 + (v >> 10)
      let lo = 0xDC00 + (v & 0x3FF)
      string_test_push_u16_be(out, hi)
      string_test_push_u16_be(out, lo)
    }
  }
  out
}

///|
fn string_test_build_name_table_v0(
  records : Array[(Int, Int, Int, Int, String)],
) -> Bytes {
  let count = records.length()
  let storage : Array[Byte] = Array::new()
  let rec_meta : Array[(Int, Int)] = Array::new()
  for r in records {
    let (platform_id, _, _, _, value) = r
    let off = storage.length()
    let bytes = match platform_id {
      0 | 3 => string_test_encode_utf16be(value)
      _ => {
        let tmp : Array[Byte] = Array::new()
        for ch in value {
          let b = ch.to_int()
          if b >= 0 && b <= 255 {
            tmp.push(b.to_byte())
          }
        }
        tmp
      }
    }
    for b in bytes.iter() {
      storage.push(b)
    }
    rec_meta.push((bytes.length(), off))
  }
  let out : Array[Byte] = Array::new()
  // format=0
  string_test_push_u16_be(out, 0)
  string_test_push_u16_be(out, count)
  let string_offset = 6 + count * 12
  string_test_push_u16_be(out, string_offset)
  for i in 0..<count {
    let (platform_id, encoding_id, language_id, name_id, _) = records.at(i)
    let (len, off) = rec_meta.at(i)
    string_test_push_u16_be(out, platform_id)
    string_test_push_u16_be(out, encoding_id)
    string_test_push_u16_be(out, language_id)
    string_test_push_u16_be(out, name_id)
    string_test_push_u16_be(out, len)
    string_test_push_u16_be(out, off)
  }
  for b in storage.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn string_test_build_name_table_v0_raw(
  records : Array[(Int, Int, Int, Int, Array[Byte])],
) -> Bytes {
  let count = records.length()
  let storage : Array[Byte] = Array::new()
  let rec_meta : Array[(Int, Int)] = Array::new()
  for r in records {
    let (_, _, _, _, bytes) = r
    let off = storage.length()
    for b in bytes.iter() {
      storage.push(b)
    }
    rec_meta.push((bytes.length(), off))
  }
  let out : Array[Byte] = Array::new()
  // format=0
  string_test_push_u16_be(out, 0)
  string_test_push_u16_be(out, count)
  let string_offset = 6 + count * 12
  string_test_push_u16_be(out, string_offset)
  for i in 0..<count {
    let (platform_id, encoding_id, language_id, name_id, _) = records.at(i)
    let (len, off) = rec_meta.at(i)
    string_test_push_u16_be(out, platform_id)
    string_test_push_u16_be(out, encoding_id)
    string_test_push_u16_be(out, language_id)
    string_test_push_u16_be(out, name_id)
    string_test_push_u16_be(out, len)
    string_test_push_u16_be(out, off)
  }
  for b in storage.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn string_test_build_name_table_v1(
  records : Array[(Int, Int, Int, Int, String)],
  lang_tags : Array[String],
) -> Bytes {
  let count = records.length()
  let tag_count = lang_tags.length()
  let storage : Array[Byte] = Array::new()
  let rec_meta : Array[(Int, Int)] = Array::new()
  for r in records {
    let (platform_id, _, _, _, value) = r
    let off = storage.length()
    let bytes = match platform_id {
      0 | 3 => string_test_encode_utf16be(value)
      _ => {
        let tmp : Array[Byte] = Array::new()
        for ch in value {
          let b = ch.to_int()
          if b >= 0 && b <= 255 {
            tmp.push(b.to_byte())
          }
        }
        tmp
      }
    }
    for b in bytes.iter() {
      storage.push(b)
    }
    rec_meta.push((bytes.length(), off))
  }
  let tag_meta : Array[(Int, Int)] = Array::new()
  for tag in lang_tags {
    let off = storage.length()
    let bytes = string_test_encode_utf16be(tag)
    for b in bytes.iter() {
      storage.push(b)
    }
    tag_meta.push((bytes.length(), off))
  }
  let out : Array[Byte] = Array::new()
  // format=1
  string_test_push_u16_be(out, 1)
  string_test_push_u16_be(out, count)
  let string_offset = 6 + count * 12 + 2 + tag_count * 4
  string_test_push_u16_be(out, string_offset)
  for i in 0..<count {
    let (platform_id, encoding_id, language_id, name_id, _) = records.at(i)
    let (len, off) = rec_meta.at(i)
    string_test_push_u16_be(out, platform_id)
    string_test_push_u16_be(out, encoding_id)
    string_test_push_u16_be(out, language_id)
    string_test_push_u16_be(out, name_id)
    string_test_push_u16_be(out, len)
    string_test_push_u16_be(out, off)
  }
  string_test_push_u16_be(out, tag_count)
  for i in 0..<tag_count {
    let (len, off) = tag_meta.at(i)
    string_test_push_u16_be(out, len)
    string_test_push_u16_be(out, off)
  }
  for b in storage.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn string_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  string_test_push_u32_be(out, string_test_u32(0x00010000))
  string_test_push_u16_be(out, num_tables)
  string_test_push_u16_be(out, 0)
  string_test_push_u16_be(out, 0)
  string_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    string_test_push_u32_be(out, tag)
    string_test_push_u32_be(out, string_test_u32(0))
    string_test_push_u32_be(out, string_test_u32(offset))
    string_test_push_u32_be(out, string_test_u32(data.length()))
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
fn string_test_find_by_lang(
  pairs : Array[(String, String)],
  lang : String,
) -> String? {
  for p in pairs {
    let (l, v) = p
    if l == lang {
      return Some(v)
    }
  }
  None
}

///|
const TAG_NAME : UInt = 0x6E616D65 // "name"

///|
test "localized() from name v0" {
  let name = string_test_build_name_table_v0(
    Array::from_fixed_array([
      (3, 1, 0x0401, STRING_ID_SUBFAMILY_NAME.to_int(), "عادي"),
      (3, 1, 0x0408, STRING_ID_SUBFAMILY_NAME.to_int(), "Κανονικά"),
      // Prefer the Mac language-id mapping: 0 => "en".
      (1, 0, 0x0000, STRING_ID_SUBFAMILY_NAME.to_int(), "Regular"),
      (3, 1, 0x042D, STRING_ID_SUBFAMILY_NAME.to_int(), "Arrunta"),
      (3, 1, 0x0415, STRING_ID_SUBFAMILY_NAME.to_int(), "Normalny"),
      (3, 1, 0x0804, STRING_ID_SUBFAMILY_NAME.to_int(), "正常"),
    ]),
  )
  let sfnt = string_test_build_sfnt(Array::from_fixed_array([(TAG_NAME, name)]))
  let font = FontRef::new(sfnt).unwrap()
  let strings = font.localized_strings(STRING_ID_SUBFAMILY_NAME)
  let pairs : Array[(String, String)] = Array::new()
  for s in strings.strings().iter() {
    pairs.push((s.language().unwrap(), s.to_string()))
  }
  inspect(pairs.length(), content="6")
  inspect(string_test_find_by_lang(pairs, "ar-SA").unwrap(), content="عادي")
  inspect(
    string_test_find_by_lang(pairs, "el-GR").unwrap(),
    content="Κανονικά",
  )
  inspect(string_test_find_by_lang(pairs, "en").unwrap(), content="Regular")
  inspect(string_test_find_by_lang(pairs, "eu-ES").unwrap(), content="Arrunta")
  inspect(string_test_find_by_lang(pairs, "pl-PL").unwrap(), content="Normalny")
  inspect(string_test_find_by_lang(pairs, "zh-Hans").unwrap(), content="正常")
}

///|
test "find_by_language" {
  let name = string_test_build_name_table_v0(
    Array::from_fixed_array([
      (3, 1, 0x0409, STRING_ID_SUBFAMILY_NAME.to_int(), "Regular"),
      (3, 1, 0x0415, STRING_ID_SUBFAMILY_NAME.to_int(), "Normalny"),
    ]),
  )
  let sfnt = string_test_build_sfnt(Array::from_fixed_array([(TAG_NAME, name)]))
  let font = FontRef::new(sfnt).unwrap()
  let strings = font.localized_strings(STRING_ID_SUBFAMILY_NAME)
  let mut found : String? = None
  for s in strings.strings().iter() {
    if s.language() == Some("pl-PL") {
      found = Some(s.to_string())
    }
  }
  inspect(found.unwrap(), content="Normalny")
}

///|
test "LocalizedString::chars" {
  let name = string_test_build_name_table_v0(
    Array::from_fixed_array([
      (3, 1, 0x0409, STRING_ID_SUBFAMILY_NAME.to_int(), "Aé"),
    ]),
  )
  let sfnt = string_test_build_sfnt(Array::from_fixed_array([(TAG_NAME, name)]))
  let font = FontRef::new(sfnt).unwrap()
  let s = font.localized_strings(STRING_ID_SUBFAMILY_NAME).strings().at(0)
  let cs = s.chars()
  inspect(cs.length(), content="2")
  inspect(cs.at(0).to_string(), content="A")
  inspect(cs.at(1).to_string(), content="é")
}

///|
test "english_or_first" {
  let name = string_test_build_name_table_v0(
    Array::from_fixed_array([
      (3, 1, 0x0415, STRING_ID_SUBFAMILY_NAME.to_int(), "Normalny"),
      (3, 1, 0x0409, STRING_ID_SUBFAMILY_NAME.to_int(), "Regular"),
    ]),
  )
  let sfnt = string_test_build_sfnt(Array::from_fixed_array([(TAG_NAME, name)]))
  let font = FontRef::new(sfnt).unwrap()
  inspect(
    font
    .localized_strings(STRING_ID_SUBFAMILY_NAME)
    .english_or_first()
    .unwrap()
    .to_string(),
    content="Regular",
  )
}

///|
test "name v1 language tags win over langid mapping" {
  let name = string_test_build_name_table_v1(
    Array::from_fixed_array([
      // Language ID 0x8000 refers to langTags[0] ("en-US").
      (3, 1, 0x8000, STRING_ID_SUBFAMILY_NAME.to_int(), "Regular-US"),
      (3, 1, 0x0415, STRING_ID_SUBFAMILY_NAME.to_int(), "Normalny"),
      (3, 1, 0x0409, STRING_ID_SUBFAMILY_NAME.to_int(), "Regular"),
    ]),
    Array::from_fixed_array(["en-US"]),
  )
  let sfnt = string_test_build_sfnt(Array::from_fixed_array([(TAG_NAME, name)]))
  let font = FontRef::new(sfnt).unwrap()
  inspect(
    font
    .localized_strings(STRING_ID_SUBFAMILY_NAME)
    .english_or_first()
    .unwrap()
    .to_string(),
    content="Regular-US",
  )
}

///|
test "macroman decoding (platform 1, encoding 0)" {
  let bytes : Array[Byte] = Array::new()
  // 0x8E in MacRoman is U+00E9 (é).
  bytes.push(0x8E |> Int::to_byte)
  let name = string_test_build_name_table_v0_raw(
    Array::from_fixed_array([
      (1, 0, 0, STRING_ID_SUBFAMILY_NAME.to_int(), bytes),
    ]),
  )
  let sfnt = string_test_build_sfnt(Array::from_fixed_array([(TAG_NAME, name)]))
  let font = FontRef::new(sfnt).unwrap()
  inspect(
    font.localized_strings(STRING_ID_SUBFAMILY_NAME).strings().at(0).to_string(),
    content="é",
  )
}

///|
test "expanded language mapping includes de-DE" {
  let name = string_test_build_name_table_v0(
    Array::from_fixed_array([
      (3, 1, 0x0407, STRING_ID_SUBFAMILY_NAME.to_int(), "Regular"),
    ]),
  )
  let sfnt = string_test_build_sfnt(Array::from_fixed_array([(TAG_NAME, name)]))
  let font = FontRef::new(sfnt).unwrap()
  inspect(
    font
    .localized_strings(STRING_ID_SUBFAMILY_NAME)
    .strings()
    .at(0)
    .language()
    .unwrap(),
    content="de-DE",
  )
}

///|
test "StringId::predefined" {
  let ids = string_id_predefined()
  inspect(ids.length(), content="25")
  inspect(ids.at(0).to_int(), content="0")
  inspect(ids.at(14).to_int(), content="14")
  inspect(ids.at(15).to_int(), content="16")
  inspect(ids.at(24).to_int(), content="25")
}
