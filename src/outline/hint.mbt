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
