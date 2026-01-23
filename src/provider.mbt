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
/// Facade for types that can provide font metadata.
///
/// Ported from `fontations/skrifa/src/provider.rs` (Apache-2.0 OR MIT).
pub(open) trait MetadataProvider {
  attributes(Self) -> Attributes
  axes(Self) -> AxisCollection
  named_instances(Self) -> NamedInstanceCollection
  localized_strings(Self, StringId) -> LocalizedStrings
  glyph_names(Self) -> GlyphNames
  metrics(Self) -> Metrics?
  charmap(Self) -> Charmap?
  bitmap_strikes(Self) -> BitmapStrikes
}

///|
pub impl MetadataProvider for FontRef with attributes(font) {
  FontRef::attributes(font)
}

///|
pub impl MetadataProvider for FontRef with axes(font) {
  AxisCollection::new(font)
}

///|
pub impl MetadataProvider for FontRef with named_instances(font) {
  NamedInstanceCollection::new(font)
}

///|
pub impl MetadataProvider for FontRef with localized_strings(font, id) {
  FontRef::localized_strings(font, id)
}

///|
pub impl MetadataProvider for FontRef with glyph_names(font) {
  GlyphNames::new(font)
}

///|
pub impl MetadataProvider for FontRef with metrics(font) {
  Metrics::new(font)
}

///|
pub impl MetadataProvider for FontRef with charmap(font) {
  Charmap::new(font)
}

///|
pub impl MetadataProvider for FontRef with bitmap_strikes(font) {
  BitmapStrikes::new(font)
}
