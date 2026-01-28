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
test "autohint style tables: style range lookup" {
  let ranges = autohint_style_ranges()
  fn style_bits(cp : Int) -> GlyphStyle? {
    match autohint_style_for_codepoint(ranges, cp |> Int::reinterpret_as_uint) {
      None => None
      Some((_, _, s)) => Some(s)
    }
  }

  guard style_bits(65) is Some(s) &&
    s.style_index() == Some(60) &&
    !s.is_non_base() else {
    fail("U+0041 should map to Latin base style")
  }
  guard style_bits(94) is Some(s) &&
    s.style_index() == Some(60) &&
    s.is_non_base() else {
    fail("U+005E should map to Latin non-base style")
  }
  guard style_bits(0x0301) is Some(s) &&
    s.style_index() == Some(60) &&
    s.is_non_base() else {
    fail("U+0301 should map to Latin combining marks (non-base)")
  }
  guard style_bits(0x0391) is Some(s) &&
    s.style_index() == Some(41) &&
    !s.is_non_base() else {
    fail("U+0391 should map to Greek base style")
  }
  guard style_bits(0x05D0) is Some(s) &&
    s.style_index() == Some(44) &&
    !s.is_non_base() else {
    fail("U+05D0 should map to Hebrew base style")
  }
  guard style_bits(0x05B0) is Some(s) &&
    s.style_index() == Some(44) &&
    s.is_non_base() else {
    fail("U+05B0 should map to Hebrew marks (non-base)")
  }
  guard style_bits(0x0627) is Some(s) &&
    s.style_index() == Some(1) &&
    !s.is_non_base() else {
    fail("U+0627 should map to Arabic base style")
  }
  guard style_bits(0x4E00) is Some(s) &&
    s.style_index() == Some(89) &&
    !s.is_non_base() else {
    fail("U+4E00 should map to CJKV ideographs")
  }
}

///|
test "autohint style tables: script/style metadata" {
  // Latin.
  guard autohint_style_script_ix(60) == 30 else {
    fail("Latin style uses Latn script class")
  }
  guard autohint_style_hint_top_to_bottom(60) == false else {
    fail("Latin is not top-to-bottom")
  }
  guard autohint_style_std_chars(60) == "o O 0" else {
    fail("Latin std chars mismatch")
  }
  let blues = autohint_style_blues(60)
  guard blues.length() >= 1 else { fail("Latin blues should not be empty") }
  guard blues.at(0) is ("T H E Z O C Q S", AUTOHINT_BLUE_TOP) else {
    fail("Latin blue zone 0 mismatch")
  }

  // Bengali: upstream marks this as top-to-bottom.
  guard autohint_style_script_ix(5) == 5 else {
    fail("Bengali style uses Beng script class")
  }
  guard autohint_style_hint_top_to_bottom(5) == true else {
    fail("Bengali should be top-to-bottom")
  }

  // CJKV ideographs.
  guard autohint_style_script_ix(89) == 59 else {
    fail("CJKV ideographs style uses Hani script class")
  }
  guard autohint_style_script_group(89) is AutoHintScriptGroup::Cjk else {
    fail("CJKV ideographs should be CJK group")
  }
}
