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
/// Error types associated with outlines.
///
/// Ported from `fontations/skrifa/src/outline/error.rs` (Apache-2.0 OR MIT).

///|
/// Errors that can occur when converting an outline to a path.
pub(all) suberror ToPathError {
  Unsupported
}

///|
/// Errors that may occur when drawing glyphs.
pub(all) suberror DrawError {
  /// No viable sources were available.
  NoSources
  /// The requested glyph was not present in the font.
  GlyphNotFound(@moon_skrifa.GlyphId)
  /// Exceeded memory limits when loading a glyph.
  InsufficientMemory
  /// Exceeded a recursion limit when loading a glyph.
  RecursionLimitExceeded(@moon_skrifa.GlyphId)
  /// Glyph outline contains too many points.
  TooManyPoints(@moon_skrifa.GlyphId)
  /// Error occurred during hinting.
  HintingFailed(HintError)
  /// An anchor point had invalid indices.
  InvalidAnchorPoint(@moon_skrifa.GlyphId, UInt16)
  /// Error occurred while loading a PostScript (CFF/CFF2) glyph.
  PostScript
  /// Conversion from outline to path failed.
  ToPath(ToPathError)
  /// Error occurred when reading font data.
  Read
  /// HarfBuzz style drawing with hints is not supported.
  HarfBuzzHintingUnsupported
}
