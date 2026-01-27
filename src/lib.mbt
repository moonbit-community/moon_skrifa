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
/// Re-export the main skrifa APIs from `Milky2018/moon_skrifa/core`.
pub using @skrifa_core {
  type Attributes,
  type Axis,
  type AxisCollection,
  type BitmapFormat,
  type BitmapGlyph,
  type BitmapImageFormat,
  type BitmapStrike,
  type BitmapStrikes,
  type Brush,
  type Charmap,
  type Color,
  type ColorGlyphCollection,
  type ColorLayer,
  type ColorPalettes,
  type ColorStop,
  type CompositeMode,
  type Decoration,
  type Extend,
  type HmtxMetrics,
  type FontRef,
  type GlyphBounds,
  type GlyphMetrics,
  type GlyphName,
  type GlyphNameSource,
  type GlyphNames,
  type LocalizedString,
  type LocalizedStrings,
  type Location,
  type LocationRef,
  type MapVariant,
  type MappingIndex,
  type Metrics,
  type NamedInstance,
  type NamedInstanceCollection,
  type PaintCachedColorGlyph,
  type PaintError,
  type Setting,
  type Size,
  type Stretch,
  type Style,
  type Tag,
  type Transform,
  type Weight,
  type GlyphId,
  type NormalizedCoord,
  type StringId,
  type VariationSetting,
  trait ColorPainter,
  trait TableProvider,
  STRING_ID_COMPATIBLE_FULL_NAME,
  STRING_ID_COPYRIGHT_NOTICE,
  STRING_ID_DARK_BACKGROUND_PALETTE,
  STRING_ID_DESCRIPTION,
  STRING_ID_DESIGNER,
  STRING_ID_DESIGNER_URL,
  STRING_ID_FAMILY_NAME,
  STRING_ID_FULL_NAME,
  STRING_ID_LAST_ALLOWED_NAME_ID,
  STRING_ID_LAST_RESERVED_NAME_ID,
  STRING_ID_LICENSE_DESCRIPTION,
  STRING_ID_LICENSE_URL,
  STRING_ID_LIGHT_BACKGROUND_PALETTE,
  STRING_ID_MANUFACTURER,
  STRING_ID_POSTSCRIPT_CID_NAME,
  STRING_ID_POSTSCRIPT_NAME,
  STRING_ID_SAMPLE_TEXT,
  STRING_ID_SUBFAMILY_NAME,
  STRING_ID_TRADEMARK,
  STRING_ID_TYPOGRAPHIC_FAMILY_NAME,
  STRING_ID_TYPOGRAPHIC_SUBFAMILY_NAME,
  STRING_ID_UNIQUE_ID,
  STRING_ID_VARIATIONS_POSTSCRIPT_NAME_PREFIX,
  STRING_ID_VENDOR_URL,
  STRING_ID_VERSION_STRING,
  STRING_ID_WWS_FAMILY_NAME,
  STRING_ID_WWS_SUBFAMILY_NAME,
  string_id_checked_add,
  string_id_is_reserved,
  string_id_predefined,
}

///|
/// Re-export common outline types from `Milky2018/moon_skrifa/outline`.
pub using @skrifa_outline {type OutlineGlyph, type OutlineGlyphCollection}
