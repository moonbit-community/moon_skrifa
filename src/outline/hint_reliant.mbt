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
/// Hint reliant font detection.
///
/// This is a direct port of `fontations/skrifa/src/outline/hint_reliant.rs`,
/// which itself follows FreeType's "tricky font" heuristics.
fn require_interpreter(_font : @moon_skrifa.FontRef) -> Bool {
  // "tricky font" detection by family name substring or cvt/fpgm/prep IDs.
  is_hint_reliant_by_name(_font) || matches_hint_reliant_id_list(_font)
}

///|
const TAG_CVT : UInt = 0x63767420 // "cvt "

///|
const MAX_HINT_RELIANT_NAME_LEN : Int = 18

///|
fn is_hint_reliant_by_name(font : @moon_skrifa.FontRef) -> Bool {
  match
    font
    .localized_strings(@moon_skrifa.STRING_ID_FAMILY_NAME)
    .english_or_first() {
    None => false
    Some(ls) => {
      let name = ls.to_string()
      // Ensure the name is short enough (FreeType compares fixed-size buffers).
      let mut n_chars = 0
      for c in name {
        // Keep this compatible with upstream's ASCII-only matching by
        // rejecting non-ASCII names.
        if c.to_int() > 0x7F {
          return false
        }
        n_chars = n_chars + 1
        if n_chars > MAX_HINT_RELIANT_NAME_LEN {
          return false
        }
      }
      matches_hint_reliant_name_list(name)
    }
  }
}

///|
fn matches_hint_reliant_name_list(name0 : String) -> Bool {
  let name = skip_pdf_random_tag(name0)
  // FreeType uses strstr(name, tricky_name): match via contains().
  for tricky in hint_reliant_names {
    if name.contains(tricky) {
      return true
    }
  }
  false
}

///|
fn skip_pdf_random_tag(name : String) -> String {
  // Random tag is 6 uppercase letters followed by a +.
  if name.length() < 8 {
    return name
  }
  if name.code_unit_at(6).to_int() != 43 {
    return name
  }
  for i in 0..<6 {
    let b = name.code_unit_at(i).to_int()
    if b < 65 || b > 90 {
      return name
    }
  }
  // Strip the `ABCDEF+` prefix.
  let out : Array[Char] = Array::new()
  let mut idx = 0
  for c in name {
    if idx >= 7 {
      out.push(c)
    }
    idx = idx + 1
  }
  String::from_array(out.op_as_view())
}

///|
let hint_reliant_names : Array[String] = Array::from_fixed_array([
  "cpop", "DFGirl-W6-WIN-BF", "DFGothic-EB", "DFGyoSho-Lt", "DFHei", "DFHSGothic-W5",
  "DFHSMincho-W3", "DFHSMincho-W7", "DFKaiSho-SB", "DFKaiShu", "DFKai-SB", "DFMing",
  "DLC", "HuaTianKaiTi?", "HuaTianSongTi?", "Ming(for ISO10646)", "MingLiU", "MingMedium",
  "PMingLiU", "MingLi43",
])

///|
priv struct TableId {
  checksum : UInt
  len : UInt
}

///|
fn TableId::default() -> TableId {
  TableId::{ checksum: 0, len: 0 }
}

///|
fn compute_checksum(data : BytesView) -> UInt {
  // OpenType checksum: sum of big-endian u32 values, padding with zeros.
  let mut sum : UInt = 0
  let n = data.length()
  let mut i = 0
  while i < n {
    let b0 = data.at(i).to_uint()
    let b1 = if i + 1 < n { data.at(i + 1).to_uint() } else { 0 }
    let b2 = if i + 2 < n { data.at(i + 2).to_uint() } else { 0 }
    let b3 = if i + 3 < n { data.at(i + 3).to_uint() } else { 0 }
    let word = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    sum = sum + word
    i = i + 4
  }
  sum
}

///|
fn TableId::from_font_and_tag(
  font : @moon_skrifa.FontRef,
  tag : UInt,
) -> TableId? {
  match font.table(tag) {
    None => None
    Some(view) =>
      Some(TableId::{
        checksum: compute_checksum(view),
        len: view.length().reinterpret_as_uint(),
      })
  }
}

///|
priv struct FontId {
  cvt : TableId
  fpgm : TableId
  prep : TableId
}

///|
fn FontId::from_font(font : @moon_skrifa.FontRef) -> FontId {
  FontId::{
    cvt: TableId::from_font_and_tag(font, TAG_CVT).unwrap_or(TableId::default()),
    fpgm: TableId::from_font_and_tag(font, TAG_FPGM).unwrap_or(
      TableId::default(),
    ),
    prep: TableId::from_font_and_tag(font, TAG_PREP).unwrap_or(
      TableId::default(),
    ),
  }
}

///|
fn matches_hint_reliant_id_list(font : @moon_skrifa.FontRef) -> Bool {
  let id = FontId::from_font(font)
  for entry in hint_reliant_ids {
    if entry.cvt.checksum == id.cvt.checksum &&
      entry.cvt.len == id.cvt.len &&
      entry.fpgm.checksum == id.fpgm.checksum &&
      entry.fpgm.len == id.fpgm.len &&
      entry.prep.checksum == id.prep.checksum &&
      entry.prep.len == id.prep.len {
      return true
    }
  }
  false
}

///|
let hint_reliant_ids : Array[FontId] = Array::from_fixed_array([
  // MingLiU 1995
  FontId::{
    cvt: TableId::{ checksum: 0x05BCF058, len: 0x000002E4 },
    fpgm: TableId::{ checksum: 0x28233BF1, len: 0x000087C4 },
    prep: TableId::{ checksum: 0xA344A1EA, len: 0x000001E1 },
  },
  // MingLiU 1996-
  FontId::{
    cvt: TableId::{ checksum: 0x05BCF058, len: 0x000002E4 },
    fpgm: TableId::{ checksum: 0x28233BF1, len: 0x000087C4 },
    prep: TableId::{ checksum: 0xA344A1EB, len: 0x000001E1 },
  },
  // DFGothic-EB
  FontId::{
    cvt: TableId::{ checksum: 0x12C3EBB2, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0xB680EE64, len: 0x000087A7 },
    prep: TableId::{ checksum: 0xCE939563, len: 0x00000758 },
  },
  // DFGyoSho-Lt
  FontId::{
    cvt: TableId::{ checksum: 0x11E5EAD4, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0xCE5956E9, len: 0x0000BC85 },
    prep: TableId::{ checksum: 0x8272F416, len: 0x00000045 },
  },
  // DFHei-Md-HK-BF
  FontId::{
    cvt: TableId::{ checksum: 0x1257EB46, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0xF699D160, len: 0x0000715F },
    prep: TableId::{ checksum: 0xD222F568, len: 0x000003BC },
  },
  // DFHSGothic-W5
  FontId::{
    cvt: TableId::{ checksum: 0x1262EB4E, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0xE86A5D64, len: 0x00007940 },
    prep: TableId::{ checksum: 0x7850F729, len: 0x000005FF },
  },
  // DFHSMincho-W3
  FontId::{
    cvt: TableId::{ checksum: 0x122DEB0A, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0x3D16328A, len: 0x0000859B },
    prep: TableId::{ checksum: 0xA93FC33B, len: 0x000002CB },
  },
  // DFHSMincho-W7
  FontId::{
    cvt: TableId::{ checksum: 0x125FEB26, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0xA5ACC982, len: 0x00007EE1 },
    prep: TableId::{ checksum: 0x90999196, len: 0x0000041F },
  },
  // DFKaiShu
  FontId::{
    cvt: TableId::{ checksum: 0x11E5EAD4, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0x5A30CA3B, len: 0x00009063 },
    prep: TableId::{ checksum: 0x13A42602, len: 0x0000007E },
  },
  // DFKaiShu, variant
  FontId::{
    cvt: TableId::{ checksum: 0x11E5EAD4, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0xA6E78C01, len: 0x00008998 },
    prep: TableId::{ checksum: 0x13A42602, len: 0x0000007E },
  },
  // DFKaiShu-Md-HK-BF
  FontId::{
    cvt: TableId::{ checksum: 0x11E5EAD4, len: 0x00000360 },
    fpgm: TableId::{ checksum: 0x9DB282B2, len: 0x0000C06E },
    prep: TableId::{ checksum: 0x53E6D7CA, len: 0x00000082 },
  },
  // DFMing-Bd-HK-BF
  FontId::{
    cvt: TableId::{ checksum: 0x1243EB18, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0xBA0A8C30, len: 0x000074AD },
    prep: TableId::{ checksum: 0xF3D83409, len: 0x0000037B },
  },
  // DLCLiShu
  FontId::{
    cvt: TableId::{ checksum: 0x07DCF546, len: 0x00000308 },
    fpgm: TableId::{ checksum: 0x40FE7C90, len: 0x00008E2A },
    prep: TableId::{ checksum: 0x608174B5, len: 0x0000007A },
  },
  // DLCHayBold
  FontId::{
    cvt: TableId::{ checksum: 0xEB891238, len: 0x00000308 },
    fpgm: TableId::{ checksum: 0xD2E4DCD4, len: 0x0000676F },
    prep: TableId::{ checksum: 0x8EA5F293, len: 0x000003B8 },
  },
  // HuaTianKaiTi
  FontId::{
    cvt: TableId::{ checksum: 0xFFFBFFFC, len: 0x00000008 },
    fpgm: TableId::{ checksum: 0x9C9E48B8, len: 0x0000BEA2 },
    prep: TableId::{ checksum: 0x70020112, len: 0x00000008 },
  },
  // HuaTianSongTi
  FontId::{
    cvt: TableId::{ checksum: 0xFFFBFFFC, len: 0x00000008 },
    fpgm: TableId::{ checksum: 0x0A5A0483, len: 0x00017C39 },
    prep: TableId::{ checksum: 0x70020112, len: 0x00000008 },
  },
  // NEC fadpop7.ttf
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x40C92555, len: 0x000000E5 },
    prep: TableId::{ checksum: 0xA39B58E3, len: 0x0000117C },
  },
  // NEC fadrei5.ttf
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x33C41652, len: 0x000000E5 },
    prep: TableId::{ checksum: 0x26D6C52A, len: 0x00000F6A },
  },
  // NEC fangot7.ttf
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x6DB1651D, len: 0x0000019D },
    prep: TableId::{ checksum: 0x6C6E4B03, len: 0x00002492 },
  },
  // NEC fangyo5.ttf
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x40C92555, len: 0x000000E5 },
    prep: TableId::{ checksum: 0xDE51FAD0, len: 0x0000117C },
  },
  // NEC fankyo5.ttf
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x85E47664, len: 0x000000E5 },
    prep: TableId::{ checksum: 0xA6C62831, len: 0x00001CAA },
  },
  // NEC fanrgo5.ttf
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x2D891CFD, len: 0x0000019D },
    prep: TableId::{ checksum: 0xA0604633, len: 0x00001DE8 },
  },
  // NEC fangot5.ttc
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x40AA774C, len: 0x000001CB },
    prep: TableId::{ checksum: 0x9B5CAA96, len: 0x00001F9A },
  },
  // NEC fanmin3.ttc
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x0D3DE9CB, len: 0x00000141 },
    prep: TableId::{ checksum: 0xD4127766, len: 0x00002280 },
  },
  // NEC FA-Gothic, 1996
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x4A692698, len: 0x000001F0 },
    prep: TableId::{ checksum: 0x340D4346, len: 0x00001FCA },
  },
  // NEC FA-Minchou, 1996
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0xCD34C604, len: 0x00000166 },
    prep: TableId::{ checksum: 0x6CF31046, len: 0x000022B0 },
  },
  // NEC FA-RoundGothicB, 1996
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0x5DA75315, len: 0x0000019D },
    prep: TableId::{ checksum: 0x40745A5F, len: 0x000022E0 },
  },
  // NEC FA-RoundGothicM, 1996
  FontId::{
    cvt: TableId::{ checksum: 0x00000000, len: 0x00000000 },
    fpgm: TableId::{ checksum: 0xF055FC48, len: 0x000001C2 },
    prep: TableId::{ checksum: 0x3900DED3, len: 0x00001E18 },
  },
  // MINGLI.TTF, 1992
  FontId::{
    cvt: TableId::{ checksum: 0x00170003, len: 0x00000060 },
    fpgm: TableId::{ checksum: 0xDBB4306E, len: 0x000058AA },
    prep: TableId::{ checksum: 0xD643482A, len: 0x00000035 },
  },
  // DFHei-Bd-WIN-HK-BF, issue #1087
  FontId::{
    cvt: TableId::{ checksum: 0x1269EB58, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0x5CD5957A, len: 0x00006A4E },
    prep: TableId::{ checksum: 0xF758323A, len: 0x00000380 },
  },
  // DFMing-Md-WIN-HK-BF, issue #1087
  FontId::{
    cvt: TableId::{ checksum: 0x122FEB0B, len: 0x00000350 },
    fpgm: TableId::{ checksum: 0x7F10919A, len: 0x000070A9 },
    prep: TableId::{ checksum: 0x7CD7E7B7, len: 0x0000025C },
  },
])
