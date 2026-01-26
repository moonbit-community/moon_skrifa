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
/// Function/Instruction definitions for the TrueType interpreter.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/definition.rs`
/// (Apache-2.0 OR MIT).
priv struct TtDefinition {
  mut code : BytesView?
  mut start : Int
  mut end_ : Int
  mut key : Int
  mut active : Bool
}

///|
fn TtDefinition::default() -> TtDefinition {
  TtDefinition::{ code: None, start: -1, end_: -1, key: 0, active: false }
}

///|
fn TtDefinition::is_defined(self : TtDefinition) -> Bool {
  self.active &&
  self.code is Some(_) &&
  self.start >= 0 &&
  self.end_ >= self.start
}

///|
fn TtDefinition::set(
  self : TtDefinition,
  code : BytesView,
  start : Int,
  end_ : Int,
  key : Int,
) -> Unit {
  self.code = Some(code)
  self.start = start
  self.end_ = end_
  self.key = key
  self.active = true
}

///|
fn TtDefinition::slice(self : TtDefinition) -> BytesView? {
  match self.code {
    None => None
    Some(code) =>
      if self.start < 0 || self.end_ < self.start || self.end_ > code.length() {
        None
      } else {
        Some(code[self.start:self.end_])
      }
  }
}

///|
priv struct TtDefinitionSet {
  defs : Array[TtDefinition]
}

///|
fn TtDefinitionSet::new(cap : Int) -> TtDefinitionSet {
  TtDefinitionSet::{ defs: Array::make(cap, TtDefinition::default()) }
}

///|
fn TtDefinitionSet::reset(self : TtDefinitionSet) -> Unit {
  let n = self.defs.length()
  for i in 0..<n {
    self.defs.set(i, TtDefinition::default())
  }
}

///|
fn TtDefinitionSet::get(self : TtDefinitionSet, index : Int) -> TtDefinition? {
  let n = self.defs.length()
  if index >= 0 && index < n {
    let d = self.defs.at(index)
    if d.is_defined() && d.key == index {
      return Some(d)
    }
  }
  for j in 0..<n {
    let i = n - 1 - j
    let d = self.defs.at(i)
    if d.is_defined() && d.key == index {
      return Some(d)
    }
  }
  None
}

///|
fn TtDefinitionSet::set_definition(
  self : TtDefinitionSet,
  index : Int,
  code : BytesView,
  start : Int,
  end_ : Int,
) -> Result[Unit, HintError] {
  if start < 0 || end_ < start || end_ > code.length() {
    return Err(HintError::InvalidDefinition(index))
  }
  let n = self.defs.length()
  if n == 0 {
    return Err(HintError::TooManyDefinitions)
  }
  let mut chosen : Int? = None
  if index >= 0 && index < n {
    let d = self.defs.at(index)
    if !d.active || d.key == index {
      chosen = Some(index)
    }
  }
  if chosen is None {
    let mut last_inactive : Int? = None
    for j in 0..<n {
      let i = n - 1 - j
      let d = self.defs.at(i)
      if d.active {
        if d.key == index {
          last_inactive = Some(i)
          break
        }
      } else if last_inactive is None {
        last_inactive = Some(i)
      }
    }
    chosen = last_inactive
  }
  match chosen {
    None => return Err(HintError::TooManyDefinitions)
    Some(ix) => {
      let d = self.defs.at(ix)
      d.set(code, start, end_, index)
      self.defs.set(ix, d)
    }
  }
  Ok(())
}
