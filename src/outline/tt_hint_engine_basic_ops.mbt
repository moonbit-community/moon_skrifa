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
/// Misc instruction implementations (logical, rounding, min/max) for the TT engine.

///|
fn TtEngine::op_and(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(if a != 0 && b != 0 { 1 } else { 0 })
}

///|
fn TtEngine::op_or(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(if a != 0 || b != 0 { 1 } else { 0 })
}

///|
fn TtEngine::op_not(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(if a == 0 { 1 } else { 0 })
}

///|
fn TtEngine::op_floor(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_hint_floor_26(a))
}

///|
fn TtEngine::op_ceiling(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(tt_hint_ceil_26(a))
}

///|
fn TtEngine::op_round(self : TtEngine) -> Result[Unit, HintError] {
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(self.graphics.round(a))
}

///|
fn TtEngine::op_max(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(if a > b { a } else { b })
}

///|
fn TtEngine::op_min(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let a = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.value_stack.push(if a < b { a } else { b })
}
