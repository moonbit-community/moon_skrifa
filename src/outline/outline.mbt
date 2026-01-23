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
/// Outline module (skeleton).
///
/// Ported from `fontations/skrifa/src/outline/*` (Apache-2.0 OR MIT).
///
/// For now this module only exposes a minimal "outline format detection" API,
/// based on table presence (glyf/CFF/CFF2).
const TAG_GLYF : UInt = 0x676C7966 // "glyf"

///|
const TAG_CFF : UInt = 0x43464620 // "CFF "

///|
const TAG_CFF2 : UInt = 0x43464632 // "CFF2"

///|
pub struct OutlineGlyphCollection {
  font : @moon_skrifa.FontRef?
}

///|
pub fn OutlineGlyphCollection::new() -> OutlineGlyphCollection {
  OutlineGlyphCollection::{ font: None }
}

///|
pub fn OutlineGlyphCollection::from_font(
  font : @moon_skrifa.FontRef,
) -> OutlineGlyphCollection {
  OutlineGlyphCollection::{ font: Some(font) }
}

///|
pub fn OutlineGlyphCollection::format(self : OutlineGlyphCollection) -> UInt? {
  if self.font is Some(font) {
    if font.table(TAG_GLYF) is Some(_) {
      Some(TAG_GLYF)
    } else if font.table(TAG_CFF) is Some(_) {
      Some(TAG_CFF)
    } else if font.table(TAG_CFF2) is Some(_) {
      Some(TAG_CFF2)
    } else {
      None
    }
  } else {
    None
  }
}

///|
pub struct HintingInstance {
  dummy : Int
}

///|
pub fn HintingInstance::new() -> HintingInstance {
  HintingInstance::{ dummy: 0 }
}
