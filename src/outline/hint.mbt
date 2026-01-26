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
/// Support for applying embedded hinting instructions (no-op skeleton).
///
/// Ported from `fontations/skrifa/src/outline/hint.rs` (Apache-2.0 OR MIT).

///|
pub(all) suberror HintError {
  Unsupported
  /// Execution stopped on an opcode that this port does not yet implement.
  UnhandledOpcode(Int, Int)
  ValueStackOverflow
  ValueStackUnderflow
  InvalidStackValue(Int)
  InvalidPointIndex(Int)
  InvalidCvtIndex(Int)
  InvalidStorageIndex(Int)
  DivideByZero
  InvalidZoneIndex(Int)
  NegativeLoopCounter
  InvalidJump
  ExceededExecutionBudget
}

///|
pub struct HintingOptions {
  engine : Engine
  target : Target
}

///|
pub fn HintingOptions::default() -> HintingOptions {
  HintingOptions::{ engine: Engine::AutoFallback, target: Target::default() }
}

///|
pub(all) enum Engine {
  Interpreter
  /// Automatic hinter that adjusts outlines without embedded instructions.
  ///
  /// Glyph styles can be precomputed per font and may be provided here as an
  /// optimization to avoid recomputing them for each instance.
  Auto(GlyphStyles?)
  AutoFallback
}

///|
/// Resolves `AutoFallback` based on outline collection preference.
pub fn Engine::resolve_auto_fallback(
  self : Engine,
  outlines : OutlineGlyphCollection,
) -> Engine {
  match self {
    Engine::AutoFallback =>
      if outlines.prefer_interpreter() {
        Engine::Interpreter
      } else {
        Engine::Auto(None)
      }
    _ => self
  }
}

///|
pub(all) enum Target {
  Mono
  Smooth(SmoothMode, Bool, Bool)
}

///|
pub fn Target::default() -> Target {
  SmoothMode::Normal.into()
}

///|
pub(all) enum SmoothMode {
  Normal
  Light
  Lcd
  VerticalLcd
}

///|
pub fn SmoothMode::into(self : SmoothMode) -> Target {
  Target::Smooth(self, true, false)
}

///|
/// Modes that control hinting when using embedded instructions.
///
/// This mirrors the legacy FreeType hinting mode selector and is intentionally
/// undocumented upstream.
pub(all) enum HintingMode {
  Strong
  Smooth(LcdLayout?, Bool)
}

///|
/// Specifies direction of pixel layout for LCD-based subpixel hinting.
pub(all) enum LcdLayout {
  Horizontal
  Vertical
}

///|
pub fn HintingMode::into(self : HintingMode) -> HintingOptions {
  let target = match self {
    HintingMode::Strong => Target::Mono
    HintingMode::Smooth(lcd_subpixel, preserve_linear_metrics) => {
      let mode = match lcd_subpixel {
        None => SmoothMode::Normal
        Some(LcdLayout::Horizontal) => SmoothMode::Lcd
        Some(LcdLayout::Vertical) => SmoothMode::VerticalLcd
      }
      Target::Smooth(mode, true, preserve_linear_metrics)
    }
  }
  HintingOptions::{ engine: Engine::AutoFallback, target }
}

///|
pub fn Target::mode(self : Target) -> SmoothMode? {
  match self {
    Target::Smooth(mode, _, _) => Some(mode)
    _ => None
  }
}

///|
pub fn Target::symmetric_rendering(self : Target) -> Bool {
  match self {
    Target::Smooth(_, symmetric, _) => symmetric
    _ => false
  }
}

///|
pub fn Target::preserve_linear_metrics(self : Target) -> Bool {
  match self {
    Target::Smooth(_, _, preserve) => preserve
    _ => false
  }
}

///|
pub fn Target::is_smooth(self : Target) -> Bool {
  match self {
    Target::Smooth(_, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_grayscale_cleartype(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::Normal, _, _) => true
    Target::Smooth(SmoothMode::Light, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_light(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::Light, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_lcd(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::Lcd, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_vertical_lcd(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::VerticalLcd, _, _) => true
    _ => false
  }
}

///|
/// Hinting instance that uses information embedded in the font to perform
/// grid-fitting.
///
/// This port currently only provides the configuration surface; actual hinting
/// is not yet implemented.
pub struct HintingInstance {
  priv mut size : @moon_skrifa.Size
  priv coords : Array[@moon_skrifa.NormalizedCoord]
  priv mut target : Target
  priv mut enabled : Bool
}

///|
pub fn HintingInstance::new(
  outlines : OutlineGlyphCollection,
  size : @moon_skrifa.Size,
  location : @moon_skrifa.LocationRef,
  options : HintingOptions,
) -> Result[HintingInstance, DrawError] {
  let h = HintingInstance::{
    size: @moon_skrifa.Size::unscaled(),
    coords: Array::new(),
    target: options.target,
    enabled: false,
  }
  match h.reconfigure(outlines, size, location, options) {
    Err(e) => Err(e)
    Ok(_) => Ok(h)
  }
}

///|
pub fn HintingInstance::size(self : HintingInstance) -> @moon_skrifa.Size {
  self.size
}

///|
pub fn HintingInstance::location(
  self : HintingInstance,
) -> @moon_skrifa.LocationRef {
  @moon_skrifa.LocationRef::new(self.coords.op_as_view())
}

///|
pub fn HintingInstance::target(self : HintingInstance) -> Target {
  self.target
}

///|
pub fn HintingInstance::is_enabled(self : HintingInstance) -> Bool {
  self.enabled
}

///|
pub fn HintingInstance::reconfigure(
  self : HintingInstance,
  outlines : OutlineGlyphCollection,
  size : @moon_skrifa.Size,
  location : @moon_skrifa.LocationRef,
  options : HintingOptions,
) -> Result[Unit, DrawError] {
  self.size = size
  self.coords.clear()
  for c in location.effective_coords().iter() {
    self.coords.push(c)
  }
  self.target = options.target
  let _resolved = options.engine.resolve_auto_fallback(outlines)
  // TODO: implement interpreter/auto hinter; for now remain disabled.
  self.enabled = false
  Ok(())
}
