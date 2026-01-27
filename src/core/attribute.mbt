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
/// Primary attributes typically used for font classification and selection.
///
/// Ported from `fontations/skrifa/src/attribute.rs` (Apache-2.0 OR MIT).
const TAG_HEAD : UInt = 0x68656164 // "head"

///|
const TAG_OS2 : UInt = 0x4F532F32 // "OS/2"

///|
const TAG_POST : UInt = 0x706F7374 // "post"

///|
const MACSTYLE_BOLD : Int = 0x0001

///|
const MACSTYLE_ITALIC : Int = 0x0002

///|
const FSSELECTION_ITALIC : Int = 0x0001

///|
const FSSELECTION_OBLIQUE : Int = 0x0200

///|
fn attr_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn attr_read_u32_be(view : BytesView, offset : Int) -> UInt? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_uint()
    let b1 = view.at(offset + 1).to_uint()
    let b2 = view.at(offset + 2).to_uint()
    let b3 = view.at(offset + 3).to_uint()
    Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
}

///|
fn attr_read_i32_be(view : BytesView, offset : Int) -> Int? {
  match attr_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.reinterpret_as_int())
  }
}

///|
/// Stretch, style and weight attributes of a font.
pub struct Attributes {
  stretch : Stretch
  style : Style
  weight : Weight
}

///|
pub fn Attributes::new(font : FontRef) -> Attributes {
  font.attributes()
}

///|
pub fn Attributes::stretch(self : Attributes) -> Stretch {
  self.stretch
}

///|
pub fn Attributes::style(self : Attributes) -> Style {
  self.style
}

///|
pub fn Attributes::weight(self : Attributes) -> Weight {
  self.weight
}

///|
pub struct Stretch {
  priv ratio : Double
}

///|
pub fn Stretch::ultra_condensed() -> Stretch {
  Stretch::new(0.5)
}

///|
pub fn Stretch::extra_condensed() -> Stretch {
  Stretch::new(0.625)
}

///|
pub fn Stretch::condensed() -> Stretch {
  Stretch::new(0.75)
}

///|
pub fn Stretch::semi_condensed() -> Stretch {
  Stretch::new(0.875)
}

///|
pub fn Stretch::normal() -> Stretch {
  Stretch::new(1.0)
}

///|
pub fn Stretch::semi_expanded() -> Stretch {
  Stretch::new(1.125)
}

///|
pub fn Stretch::expanded() -> Stretch {
  Stretch::new(1.25)
}

///|
pub fn Stretch::extra_expanded() -> Stretch {
  Stretch::new(1.5)
}

///|
pub fn Stretch::ultra_expanded() -> Stretch {
  Stretch::new(2.0)
}

///|
pub fn Stretch::new(ratio : Double) -> Stretch {
  Stretch::{ ratio, }
}

///|
pub fn Stretch::default() -> Stretch {
  Stretch::normal()
}

///|
pub fn Stretch::ratio(self : Stretch) -> Double {
  self.ratio
}

///|
pub fn Stretch::percentage(self : Stretch) -> Double {
  self.ratio * 100.0
}

///|
fn Stretch::from_width_class(width_class : Int) -> Stretch {
  match width_class {
    0 | 1 => Stretch::ultra_condensed()
    2 => Stretch::extra_condensed()
    3 => Stretch::condensed()
    4 => Stretch::semi_condensed()
    5 => Stretch::normal()
    6 => Stretch::semi_expanded()
    7 => Stretch::expanded()
    8 => Stretch::extra_expanded()
    _ => Stretch::ultra_expanded()
  }
}

///|
pub(all) enum Style {
  Normal
  Italic
  Oblique(Double?)
}

///|
pub struct Weight {
  priv value : Double
}

///|
pub fn Weight::thin() -> Weight {
  Weight::new(100.0)
}

///|
pub fn Weight::extra_light() -> Weight {
  Weight::new(200.0)
}

///|
pub fn Weight::light() -> Weight {
  Weight::new(300.0)
}

///|
pub fn Weight::semi_light() -> Weight {
  Weight::new(350.0)
}

///|
pub fn Weight::normal() -> Weight {
  Weight::new(400.0)
}

///|
pub fn Weight::medium() -> Weight {
  Weight::new(500.0)
}

///|
pub fn Weight::semi_bold() -> Weight {
  Weight::new(600.0)
}

///|
pub fn Weight::bold() -> Weight {
  Weight::new(700.0)
}

///|
pub fn Weight::extra_bold() -> Weight {
  Weight::new(800.0)
}

///|
pub fn Weight::black() -> Weight {
  Weight::new(900.0)
}

///|
pub fn Weight::extra_black() -> Weight {
  Weight::new(950.0)
}

///|
pub fn Weight::new(value : Double) -> Weight {
  Weight::{ value, }
}

///|
pub fn Weight::default() -> Weight {
  Weight::normal()
}

///|
pub fn Weight::value(self : Weight) -> Double {
  self.value
}

///|
pub fn FontRef::attributes(self : FontRef) -> Attributes {
  // Prefer OS/2 if present, otherwise fall back to head.macStyle.
  match self.table(TAG_OS2) {
    Some(os2) => {
      let width_class = attr_read_u16_be(os2, 6).unwrap_or(5)
      let weight_class = attr_read_u16_be(os2, 4).unwrap_or(400)
      let fs_selection = attr_read_u16_be(os2, 62).unwrap_or(0)
      let stretch = Stretch::from_width_class(width_class)
      let style = if (fs_selection & FSSELECTION_ITALIC) != 0 {
        Italic
      } else if (fs_selection & FSSELECTION_OBLIQUE) != 0 {
        let angle = match self.table(TAG_POST) {
          None => None
          Some(post) =>
            // post.italicAngle is a signed 16.16 fixed point at offset 4.
            match attr_read_i32_be(post, 4) {
              None => None
              Some(bits) => Some(bits.to_double() / 65536.0)
            }
        }
        Oblique(angle)
      } else {
        Normal
      }
      Attributes::{
        stretch,
        style,
        weight: Weight::new(weight_class.to_double()),
      }
    }
    None =>
      match self.table(TAG_HEAD) {
        Some(head) => {
          let mac_style = attr_read_u16_be(head, 44).unwrap_or(0)
          let style = if (mac_style & MACSTYLE_ITALIC) != 0 {
            Italic
          } else {
            Normal
          }
          let weight = if (mac_style & MACSTYLE_BOLD) != 0 {
            Weight::bold()
          } else {
            Weight::default()
          }
          Attributes::{ stretch: Stretch::default(), style, weight }
        }
        None =>
          Attributes::{
            stretch: Stretch::default(),
            style: Normal,
            weight: Weight::default(),
          }
      }
  }
}
