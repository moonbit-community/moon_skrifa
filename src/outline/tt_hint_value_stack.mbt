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
/// Fixed-capacity value stack for the TrueType interpreter.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/value_stack.rs`
/// (Apache-2.0 OR MIT).
priv struct TtValueStack {
  buf : Array[Int32]
  mut len : Int32
  mut check : Bool
}

///|
fn TtValueStack::TtValueStack(buf : Array[Int32], check : Bool) -> TtValueStack {
  { buf, len: 0, check, }
}

///|
fn TtValueStack::clear(self : TtValueStack) -> Unit {
  self.len = 0
}

///|
fn TtValueStack::length(self : TtValueStack) -> Int32 {
  self.len
}

///|
fn TtValueStack::push(
  self : TtValueStack,
  value : Int32,
) -> Unit raise HintError {
  if self.len >= self.buf.length() {
    if self.check {
      raise ValueStackOverflow
    } else {
      ()
    }
  } else {
    self.buf.set(self.len, value)
    self.len = self.len + 1
    ()
  }
}

///|
fn TtValueStack::pop(self : TtValueStack) -> Int32 raise HintError {
  if self.len <= 0 {
    if self.check {
      raise ValueStackUnderflow
    } else {
      0
    }
  } else {
    self.len = self.len - 1
    self.buf.at(self.len)
  }
}

///|
/// Pops a stack value and validates it as a point index (>= 0).
fn TtValueStack::pop_usize(self : TtValueStack) -> Int32 raise HintError {
  let v = self.pop()
  if v < 0 {
    raise InvalidStackValue(v)
  } else {
    v
  }
}

///|
fn TtValueStack::peek(
  self : TtValueStack,
  depth_from_top : Int32,
) -> Int32 raise HintError {
  // depth_from_top: 0 == top
  if depth_from_top < 0 {
    raise InvalidStackValue(depth_from_top)
  }
  let idx = self.len - 1 - depth_from_top
  if idx < 0 || idx >= self.len {
    raise ValueStackUnderflow
  } else {
    self.buf.at(idx)
  }
}

///|
