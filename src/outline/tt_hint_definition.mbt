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
}

///|
fn TtDefinition::default() -> TtDefinition {
  TtDefinition::{ code: None, start: -1, end_: -1 }
}

///|
fn TtDefinition::is_defined(self : TtDefinition) -> Bool {
  self.code is Some(_) && self.start >= 0 && self.end_ >= self.start
}

///|
fn TtDefinition::set(
  self : TtDefinition,
  code : BytesView,
  start : Int,
  end_ : Int,
) -> Unit {
  self.code = Some(code)
  self.start = start
  self.end_ = end_
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
  if index < 0 || index >= self.defs.length() {
    None
  } else {
    let d = self.defs.at(index)
    if d.is_defined() {
      Some(d)
    } else {
      None
    }
  }
}

///|
fn TtDefinitionSet::set_definition(
  self : TtDefinitionSet,
  index : Int,
  code : BytesView,
  start : Int,
  end_ : Int,
) -> Result[Unit, HintError] {
  if index < 0 || index >= self.defs.length() {
    return Err(HintError::InvalidDefinition(index))
  }
  if start < 0 || end_ < start || end_ > code.length() {
    return Err(HintError::InvalidDefinition(index))
  }
  let d = self.defs.at(index)
  d.set(code, start, end_)
  self.defs.set(index, d)
  Ok(())
}
