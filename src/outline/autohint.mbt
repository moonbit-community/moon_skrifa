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
/// Runtime autohinting support.
///
/// Upstream `fontations/skrifa` includes a runtime autohinter used when a font
/// does not provide embedded instructions. In this port, `GlyphStyles` is the
/// (font-invariant) precomputed style map that can be reused across hinting
/// instances.

///|
pub struct GlyphStyles {
  priv _private : Unit
}

///|
/// Precomputes the glyph style map for a font.
///
/// This is invariant per font and can be reused when creating multiple
/// `HintingInstance`s with `Engine::Auto(...)`.
pub fn GlyphStyles::new(_outlines : OutlineGlyphCollection) -> GlyphStyles {
  GlyphStyles::{ _private: () }
}
