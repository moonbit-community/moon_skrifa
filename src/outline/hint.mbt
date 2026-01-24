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
  Auto
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
        Engine::Auto
      }
    _ => self
  }
}

///|
pub(all) enum Target {
  Mono
  Smooth(SmoothMode)
}

///|
pub fn Target::default() -> Target {
  Target::Smooth(SmoothMode::Normal)
}

///|
pub(all) enum SmoothMode {
  Normal
  Light
  Lcd
  VerticalLcd
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
