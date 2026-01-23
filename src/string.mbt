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
/// Localized strings (OpenType `name` table).
///
/// Ported from `fontations/skrifa/src/string.rs` (Apache-2.0 OR MIT).
const TAG_NAME : UInt = 0x6E616D65 // "name"

///|
/// OpenType name identifier (NameID).
///
/// This is a `UInt16` in the OpenType spec.
pub type StringId = UInt16

///|
pub const STRING_ID_FAMILY_NAME : StringId = 1

///|
pub const STRING_ID_SUBFAMILY_NAME : StringId = 2

///|
fn string_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn string_decode_utf16be(view : BytesView) -> String? {
  let len = view.length()
  if len < 0 || (len & 1) != 0 {
    return None
  }
  let chars : Array[Char] = Array::new()
  let mut i = 0
  while i + 1 < len {
    let u = string_read_u16_be(view, i).unwrap_or(-1)
    if u < 0 {
      return None
    }
    if u >= 0xD800 && u <= 0xDBFF {
      if i + 3 >= len {
        return None
      }
      let u2 = string_read_u16_be(view, i + 2).unwrap_or(-1)
      if u2 < 0xDC00 || u2 > 0xDFFF {
        return None
      }
      let hi = u - 0xD800
      let lo = u2 - 0xDC00
      let code_point = 0x10000 + (hi << 10) + lo
      if code_point > 0x10FFFF {
        return None
      }
      chars.push(code_point.unsafe_to_char())
      i = i + 4
    } else if u >= 0xDC00 && u <= 0xDFFF {
      return None
    } else {
      chars.push(u.unsafe_to_char())
      i = i + 2
    }
  }
  Some(String::from_array(chars.op_as_view()))
}

///|
fn string_mac_roman_code_point(b : Int) -> Int {
  if b >= 0 && b <= 0x7F {
    b
  } else {
    match b {
      0x80 => 0x00C4
      0x81 => 0x00C5
      0x82 => 0x00C7
      0x83 => 0x00C9
      0x84 => 0x00D1
      0x85 => 0x00D6
      0x86 => 0x00DC
      0x87 => 0x00E1
      0x88 => 0x00E0
      0x89 => 0x00E2
      0x8A => 0x00E4
      0x8B => 0x00E3
      0x8C => 0x00E5
      0x8D => 0x00E7
      0x8E => 0x00E9
      0x8F => 0x00E8
      0x90 => 0x00EA
      0x91 => 0x00EB
      0x92 => 0x00ED
      0x93 => 0x00EC
      0x94 => 0x00EE
      0x95 => 0x00EF
      0x96 => 0x00F1
      0x97 => 0x00F3
      0x98 => 0x00F2
      0x99 => 0x00F4
      0x9A => 0x00F6
      0x9B => 0x00F5
      0x9C => 0x00FA
      0x9D => 0x00F9
      0x9E => 0x00FB
      0x9F => 0x00FC
      0xA0 => 0x2020
      0xA1 => 0x00B0
      0xA2 => 0x00A2
      0xA3 => 0x00A3
      0xA4 => 0x00A7
      0xA5 => 0x2022
      0xA6 => 0x00B6
      0xA7 => 0x00DF
      0xA8 => 0x00AE
      0xA9 => 0x00A9
      0xAA => 0x2122
      0xAB => 0x00B4
      0xAC => 0x00A8
      0xAD => 0x2260
      0xAE => 0x00C6
      0xAF => 0x00D8
      0xB0 => 0x221E
      0xB1 => 0x00B1
      0xB2 => 0x2264
      0xB3 => 0x2265
      0xB4 => 0x00A5
      0xB5 => 0x00B5
      0xB6 => 0x2202
      0xB7 => 0x2211
      0xB8 => 0x220F
      0xB9 => 0x03C0
      0xBA => 0x222B
      0xBB => 0x00AA
      0xBC => 0x00BA
      0xBD => 0x03A9
      0xBE => 0x00E6
      0xBF => 0x00F8
      0xC0 => 0x00BF
      0xC1 => 0x00A1
      0xC2 => 0x00AC
      0xC3 => 0x221A
      0xC4 => 0x0192
      0xC5 => 0x2248
      0xC6 => 0x2206
      0xC7 => 0x00AB
      0xC8 => 0x00BB
      0xC9 => 0x2026
      0xCA => 0x00A0
      0xCB => 0x00C0
      0xCC => 0x00C3
      0xCD => 0x00D5
      0xCE => 0x0152
      0xCF => 0x0153
      0xD0 => 0x2013
      0xD1 => 0x2014
      0xD2 => 0x201C
      0xD3 => 0x201D
      0xD4 => 0x2018
      0xD5 => 0x2019
      0xD6 => 0x00F7
      0xD7 => 0x25CA
      0xD8 => 0x00FF
      0xD9 => 0x0178
      0xDA => 0x2044
      0xDB => 0x20AC
      0xDC => 0x2039
      0xDD => 0x203A
      0xDE => 0xFB01
      0xDF => 0xFB02
      0xE0 => 0x2021
      0xE1 => 0x00B7
      0xE2 => 0x201A
      0xE3 => 0x201E
      0xE4 => 0x2030
      0xE5 => 0x00C2
      0xE6 => 0x00CA
      0xE7 => 0x00C1
      0xE8 => 0x00CB
      0xE9 => 0x00C8
      0xEA => 0x00CD
      0xEB => 0x00CE
      0xEC => 0x00CF
      0xED => 0x00CC
      0xEE => 0x00D3
      0xEF => 0x00D4
      0xF0 => 0xF8FF
      0xF1 => 0x00D2
      0xF2 => 0x00DA
      0xF3 => 0x00DB
      0xF4 => 0x00D9
      0xF5 => 0x0131
      0xF6 => 0x02C6
      0xF7 => 0x02DC
      0xF8 => 0x00AF
      0xF9 => 0x02D8
      0xFA => 0x02D9
      0xFB => 0x02DA
      0xFC => 0x00B8
      0xFD => 0x02DD
      0xFE => 0x02DB
      0xFF => 0x02C7
      _ => 0xFFFD
    }
  }
}

///|
fn string_decode_bytes_mac_roman(view : BytesView) -> String {
  let chars : Array[Char] = Array::new()
  for b in view.iter() {
    let cp = string_mac_roman_code_point(b.to_int())
    chars.push(cp.unsafe_to_char())
  }
  String::from_array(chars.op_as_view())
}

///|
fn string_decode_name_string(
  platform_id : Int,
  encoding_id : Int,
  view : BytesView,
) -> String? {
  match platform_id {
    // Unicode
    0 => string_decode_utf16be(view)
    // Macintosh (MacRoman is the most common encoding).
    1 =>
      if encoding_id == 0 {
        Some(string_decode_bytes_mac_roman(view))
      } else {
        None
      }
    // Windows
    3 => string_decode_utf16be(view)
    _ => None
  }
}

///|
fn string_is_ascii(s : String) -> Bool {
  for ch in s {
    if !ch.is_ascii() {
      return false
    }
  }
  true
}

///|
fn string_language_id_to_bcp47(language_id : Int) -> String? {
  // Borrowed from Skia (`SkOTTable_name.cpp`) via skrifa-reference.
  match language_id {
    0x0000 => Some("en")
    0x0001 => Some("fr")
    0x0002 => Some("de")
    0x0003 => Some("it")
    0x0004 => Some("nl")
    0x0005 => Some("sv")
    0x0006 => Some("es")
    0x0007 => Some("da")
    0x0008 => Some("pt")
    0x0009 => Some("nb")
    0x000A => Some("he")
    0x000B => Some("ja")
    0x000C => Some("ar")
    0x000D => Some("fi")
    0x000E => Some("el")
    0x000F => Some("is")
    0x0010 => Some("mt")
    0x0011 => Some("tr")
    0x0012 => Some("hr")
    0x0013 => Some("zh-Hant")
    0x0014 => Some("ur")
    0x0015 => Some("hi")
    0x0016 => Some("th")
    0x0017 => Some("ko")
    0x0018 => Some("lt")
    0x0019 => Some("pl")
    0x001A => Some("hu")
    0x001B => Some("et")
    0x001C => Some("lv")
    0x001D => Some("se")
    0x001E => Some("fo")
    0x001F => Some("fa")
    0x0020 => Some("ru")
    0x0021 => Some("zh-Hans")
    0x0022 => Some("nl")
    0x0023 => Some("ga")
    0x0024 => Some("sq")
    0x0025 => Some("ro")
    0x0026 => Some("cs")
    0x0027 => Some("sk")
    0x0028 => Some("sl")
    0x0029 => Some("yi")
    0x002A => Some("sr")
    0x002B => Some("mk")
    0x002C => Some("bg")
    0x002D => Some("uk")
    0x002E => Some("be")
    0x002F => Some("uz")
    0x0030 => Some("kk")
    0x0031 => Some("az-Cyrl")
    0x0032 => Some("az-Arab")
    0x0033 => Some("hy")
    0x0034 => Some("ka")
    0x0035 => Some("mo")
    0x0036 => Some("ky")
    0x0037 => Some("tg")
    0x0038 => Some("tk")
    0x0039 => Some("mn-Mong")
    0x003A => Some("mn-Cyrl")
    0x003B => Some("ps")
    0x003C => Some("ku")
    0x003D => Some("ks")
    0x003E => Some("sd")
    0x003F => Some("bo")
    0x0040 => Some("ne")
    0x0041 => Some("sa")
    0x0042 => Some("mr")
    0x0043 => Some("bn")
    0x0044 => Some("as")
    0x0045 => Some("gu")
    0x0046 => Some("pa")
    0x0047 => Some("or")
    0x0048 => Some("ml")
    0x0049 => Some("kn")
    0x004A => Some("ta")
    0x004B => Some("te")
    0x004C => Some("si")
    0x004D => Some("my")
    0x004E => Some("km")
    0x004F => Some("lo")
    0x0050 => Some("vi")
    0x0051 => Some("id")
    0x0052 => Some("tl")
    0x0053 => Some("ms-Latn")
    0x0054 => Some("ms-Arab")
    0x0055 => Some("am")
    0x0056 => Some("ti")
    0x0057 => Some("om")
    0x0058 => Some("so")
    0x0059 => Some("sw")
    0x005A => Some("rw")
    0x005B => Some("rn")
    0x005C => Some("ny")
    0x005D => Some("mg")
    0x005E => Some("eo")
    0x0080 => Some("cy")
    0x0081 => Some("eu")
    0x0082 => Some("ca")
    0x0083 => Some("la")
    0x0084 => Some("qu")
    0x0085 => Some("gn")
    0x0086 => Some("ay")
    0x0087 => Some("tt")
    0x0088 => Some("ug")
    0x0089 => Some("dz")
    0x008A => Some("jv-Latn")
    0x008B => Some("su-Latn")
    0x008C => Some("gl")
    0x008D => Some("af")
    0x008E => Some("br")
    0x008F => Some("iu")
    0x0090 => Some("gd")
    0x0091 => Some("gv")
    0x0092 => Some("ga")
    0x0093 => Some("to")
    0x0094 => Some("el")
    0x0095 => Some("kl")
    0x0096 => Some("az-Latn")
    0x0097 => Some("nn")
    0x0401 => Some("ar-SA")
    0x0402 => Some("bg-BG")
    0x0403 => Some("ca-ES")
    0x0404 => Some("zh-TW")
    0x0405 => Some("cs-CZ")
    0x0406 => Some("da-DK")
    0x0407 => Some("de-DE")
    0x0408 => Some("el-GR")
    0x0409 => Some("en-US")
    0x040A => Some("es-ES_tradnl")
    0x040B => Some("fi-FI")
    0x040C => Some("fr-FR")
    0x040D => Some("he-IL")
    0x040E => Some("hu-HU")
    0x040F => Some("is-IS")
    0x0410 => Some("it-IT")
    0x0411 => Some("ja-JP")
    0x0412 => Some("ko-KR")
    0x0413 => Some("nl-NL")
    0x0414 => Some("nb-NO")
    0x0415 => Some("pl-PL")
    0x0416 => Some("pt-BR")
    0x0417 => Some("rm-CH")
    0x0418 => Some("ro-RO")
    0x0419 => Some("ru-RU")
    0x041A => Some("hr-HR")
    0x041B => Some("sk-SK")
    0x041C => Some("sq-AL")
    0x041D => Some("sv-SE")
    0x041E => Some("th-TH")
    0x041F => Some("tr-TR")
    0x0420 => Some("ur-PK")
    0x0421 => Some("id-ID")
    0x0422 => Some("uk-UA")
    0x0423 => Some("be-BY")
    0x0424 => Some("sl-SI")
    0x0425 => Some("et-EE")
    0x0426 => Some("lv-LV")
    0x0427 => Some("lt-LT")
    0x0428 => Some("tg-Cyrl-TJ")
    0x0429 => Some("fa-IR")
    0x042A => Some("vi-VN")
    0x042B => Some("hy-AM")
    0x042C => Some("az-Latn-AZ")
    0x042D => Some("eu-ES")
    0x042E => Some("hsb-DE")
    0x042F => Some("mk-MK")
    0x0432 => Some("tn-ZA")
    0x0434 => Some("xh-ZA")
    0x0435 => Some("zu-ZA")
    0x0436 => Some("af-ZA")
    0x0437 => Some("ka-GE")
    0x0438 => Some("fo-FO")
    0x0439 => Some("hi-IN")
    0x043A => Some("mt-MT")
    0x043B => Some("se-NO")
    0x043E => Some("ms-MY")
    0x043F => Some("kk-KZ")
    0x0440 => Some("ky-KG")
    0x0441 => Some("sw-KE")
    0x0442 => Some("tk-TM")
    0x0443 => Some("uz-Latn-UZ")
    0x0444 => Some("tt-RU")
    0x0445 => Some("bn-IN")
    0x0446 => Some("pa-IN")
    0x0447 => Some("gu-IN")
    0x0448 => Some("or-IN")
    0x0449 => Some("ta-IN")
    0x044A => Some("te-IN")
    0x044B => Some("kn-IN")
    0x044C => Some("ml-IN")
    0x044D => Some("as-IN")
    0x044E => Some("mr-IN")
    0x044F => Some("sa-IN")
    0x0450 => Some("mn-Cyrl")
    0x0451 => Some("bo-CN")
    0x0452 => Some("cy-GB")
    0x0453 => Some("km-KH")
    0x0454 => Some("lo-LA")
    0x0456 => Some("gl-ES")
    0x0457 => Some("kok-IN")
    0x045A => Some("syr-SY")
    0x045B => Some("si-LK")
    0x045D => Some("iu-Cans-CA")
    0x045E => Some("am-ET")
    0x0461 => Some("ne-NP")
    0x0462 => Some("fy-NL")
    0x0463 => Some("ps-AF")
    0x0464 => Some("fil-PH")
    0x0465 => Some("dv-MV")
    0x0468 => Some("ha-Latn-NG")
    0x046A => Some("yo-NG")
    0x046B => Some("quz-BO")
    0x046C => Some("nso-ZA")
    0x046D => Some("ba-RU")
    0x046E => Some("lb-LU")
    0x046F => Some("kl-GL")
    0x0470 => Some("ig-NG")
    0x0478 => Some("ii-CN")
    0x047A => Some("arn-CL")
    0x047C => Some("moh-CA")
    0x047E => Some("br-FR")
    0x0480 => Some("ug-CN")
    0x0481 => Some("mi-NZ")
    0x0482 => Some("oc-FR")
    0x0483 => Some("co-FR")
    0x0484 => Some("gsw-FR")
    0x0485 => Some("sah-RU")
    0x0486 => Some("qut-GT")
    0x0487 => Some("rw-RW")
    0x0488 => Some("wo-SN")
    0x048C => Some("prs-AF")
    0x0491 => Some("gd-GB")
    0x0801 => Some("ar-IQ")
    0x0804 => Some("zh-Hans")
    0x0807 => Some("de-CH")
    0x0809 => Some("en-GB")
    0x080A => Some("es-MX")
    0x080C => Some("fr-BE")
    0x0810 => Some("it-CH")
    0x0813 => Some("nl-BE")
    0x0814 => Some("nn-NO")
    0x0816 => Some("pt-PT")
    0x081A => Some("sr-Latn-CS")
    0x081D => Some("sv-FI")
    0x082C => Some("az-Cyrl-AZ")
    0x082E => Some("dsb-DE")
    0x083B => Some("se-SE")
    0x083C => Some("ga-IE")
    0x083E => Some("ms-BN")
    0x0843 => Some("uz-Cyrl-UZ")
    0x0845 => Some("bn-BD")
    0x0850 => Some("mn-Mong-CN")
    0x085D => Some("iu-Latn-CA")
    0x085F => Some("tzm-Latn-DZ")
    0x086B => Some("quz-EC")
    0x0C01 => Some("ar-EG")
    0x0C04 => Some("zh-Hant")
    0x0C07 => Some("de-AT")
    0x0C09 => Some("en-AU")
    0x0C0A => Some("es-ES")
    0x0C0C => Some("fr-CA")
    0x0C1A => Some("sr-Cyrl-CS")
    0x0C3B => Some("se-FI")
    0x0C6B => Some("quz-PE")
    0x1001 => Some("ar-LY")
    0x1004 => Some("zh-SG")
    0x1007 => Some("de-LU")
    0x1009 => Some("en-CA")
    0x100A => Some("es-GT")
    0x100C => Some("fr-CH")
    0x101A => Some("hr-BA")
    0x103B => Some("smj-NO")
    0x1401 => Some("ar-DZ")
    0x1404 => Some("zh-MO")
    0x1407 => Some("de-LI")
    0x1409 => Some("en-NZ")
    0x140A => Some("es-CR")
    0x140C => Some("fr-LU")
    0x141A => Some("bs-Latn-BA")
    0x143B => Some("smj-SE")
    0x1801 => Some("ar-MA")
    0x1809 => Some("en-IE")
    0x180A => Some("es-PA")
    0x180C => Some("fr-MC")
    0x181A => Some("sr-Latn-BA")
    0x183B => Some("sma-NO")
    0x1C01 => Some("ar-TN")
    0x1C09 => Some("en-ZA")
    0x1C0A => Some("es-DO")
    0x1C1A => Some("sr-Cyrl-BA")
    0x1C3B => Some("sma-SE")
    0x2001 => Some("ar-OM")
    0x2009 => Some("en-JM")
    0x200A => Some("es-VE")
    0x201A => Some("bs-Cyrl-BA")
    0x203B => Some("sms-FI")
    0x2401 => Some("ar-YE")
    0x2409 => Some("en-029")
    0x240A => Some("es-CO")
    0x241A => Some("sr-Latn-RS")
    0x243B => Some("smn-FI")
    0x2801 => Some("ar-SY")
    0x2809 => Some("en-BZ")
    0x280A => Some("es-PE")
    0x281A => Some("sr-Cyrl-RS")
    0x2C01 => Some("ar-JO")
    0x2C09 => Some("en-TT")
    0x2C0A => Some("es-AR")
    0x2C1A => Some("sr-Latn-ME")
    0x3001 => Some("ar-LB")
    0x3009 => Some("en-ZW")
    0x300A => Some("es-EC")
    0x301A => Some("sr-Cyrl-ME")
    0x3401 => Some("ar-KW")
    0x3409 => Some("en-PH")
    0x340A => Some("es-CL")
    0x3801 => Some("ar-AE")
    0x380A => Some("es-UY")
    0x3C01 => Some("ar-BH")
    0x3C0A => Some("es-PY")
    0x4001 => Some("ar-QA")
    0x4009 => Some("en-IN")
    0x400A => Some("es-BO")
    0x4409 => Some("en-MY")
    0x440A => Some("es-SV")
    0x4809 => Some("en-SG")
    0x480A => Some("es-HN")
    0x4C0A => Some("es-NI")
    0x500A => Some("es-PR")
    0x540A => Some("es-US")
    _ => None
  }
}

///|

///|
pub struct LocalizedString {
  priv language : String?
  priv value : String
}

///|
pub fn LocalizedString::language(self : LocalizedString) -> String? {
  self.language
}

///|
pub fn LocalizedString::to_string(self : LocalizedString) -> String {
  self.value
}

///|
pub struct LocalizedStrings {
  priv id : StringId
  priv strings : Array[LocalizedString]
}

///|
pub fn LocalizedStrings::id(self : LocalizedStrings) -> StringId {
  self.id
}

///|
pub fn LocalizedStrings::strings(
  self : LocalizedStrings,
) -> ArrayView[LocalizedString] {
  self.strings.op_as_view()
}

///|
pub fn LocalizedStrings::english_or_first(
  self : LocalizedStrings,
) -> LocalizedString? {
  let mut best_rank = -1
  let mut best : LocalizedString? = None
  let n = self.strings.length()
  for i in 0..<n {
    let s = self.strings.at(i)
    let rank = match s.language {
      Some(lang) =>
        if lang == "en-US" {
          return Some(s)
        } else if lang == "en" {
          2
        } else if i == 0 {
          0
        } else {
          continue
        }
      None => 1
    }
    if rank > best_rank {
      best_rank = rank
      best = Some(s)
    }
  }
  best
}

///|
pub fn FontRef::localized_strings(
  self : FontRef,
  id : StringId,
) -> LocalizedStrings {
  let name = match self.table(TAG_NAME) {
    None => return LocalizedStrings::{ id, strings: Array::new() }
    Some(v) => v
  }
  let format = string_read_u16_be(name, 0).unwrap_or(-1)
  let count = string_read_u16_be(name, 2).unwrap_or(-1)
  let string_offset = string_read_u16_be(name, 4).unwrap_or(-1)
  if format < 0 || count < 0 || string_offset < 0 {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  let records_base = 6
  let records_end = records_base + count * 12
  if records_end < records_base || records_end > name.length() {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  let lang_tags : Array[(Int, Int)] = Array::new()
  if format == 1 {
    if records_end + 2 > name.length() {
      return LocalizedStrings::{ id, strings: Array::new() }
    }
    let tag_count = string_read_u16_be(name, records_end).unwrap_or(-1)
    if tag_count < 0 {
      return LocalizedStrings::{ id, strings: Array::new() }
    }
    let tags_base = records_end + 2
    let tags_end = tags_base + tag_count * 4
    if tags_end < tags_base || tags_end > name.length() {
      return LocalizedStrings::{ id, strings: Array::new() }
    }
    for i in 0..<tag_count {
      let pos = tags_base + i * 4
      let len = string_read_u16_be(name, pos).unwrap_or(-1)
      let off = string_read_u16_be(name, pos + 2).unwrap_or(-1)
      if len < 0 || off < 0 {
        continue
      }
      lang_tags.push((len, off))
    }
  } else if format != 0 {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  if string_offset > name.length() {
    return LocalizedStrings::{ id, strings: Array::new() }
  }
  let strings : Array[LocalizedString] = Array::new()
  for i in 0..<count {
    let pos = records_base + i * 12
    let platform_id = string_read_u16_be(name, pos).unwrap_or(-1)
    let encoding_id = string_read_u16_be(name, pos + 2).unwrap_or(-1)
    let language_id = string_read_u16_be(name, pos + 4).unwrap_or(-1)
    let name_id = string_read_u16_be(name, pos + 6).unwrap_or(-1)
    let len = string_read_u16_be(name, pos + 8).unwrap_or(-1)
    let off = string_read_u16_be(name, pos + 10).unwrap_or(-1)
    if platform_id < 0 ||
      encoding_id < 0 ||
      language_id < 0 ||
      name_id < 0 ||
      len < 0 ||
      off < 0 {
      continue
    }
    if name_id != id.to_uint64().to_int() {
      continue
    }
    let start = string_offset + off
    let end = start + len
    if start < 0 || end < start || end > name.length() {
      continue
    }
    let view = name.sub(start~, end~)
    let value = match
      string_decode_name_string(platform_id, encoding_id, view) {
      None => continue
      Some(s) => s
    }
    let language = if format == 1 && language_id >= 0x8000 {
      let index = language_id - 0x8000
      if index < 0 || index >= lang_tags.length() {
        None
      } else {
        let (tlen, toff) = lang_tags.at(index)
        let start = string_offset + toff
        let end = start + tlen
        if start < 0 || end < start || end > name.length() {
          None
        } else {
          match string_decode_utf16be(name.sub(start~, end~)) {
            None => None
            Some(tag) => if string_is_ascii(tag) { Some(tag) } else { None }
          }
        }
      }
    } else {
      match platform_id {
        1 | 3 => string_language_id_to_bcp47(language_id)
        _ => None
      }
    }
    strings.push(LocalizedString::{ language, value })
  }
  LocalizedStrings::{ id, strings }
}
