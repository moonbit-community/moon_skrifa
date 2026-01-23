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
/// Internal "small" style collection types.
///
/// Ported from `fontations/skrifa/src/collections.rs` (Apache-2.0 OR MIT).
///
/// NOTE: Upstream uses const-generics for inline capacity. In MoonBit we keep
/// `inline_cap` as a runtime parameter; this preserves behavior while still
/// allowing the inline/heap split used by later ports.
priv enum Storage[T] {
  Inline(FixedArray[T], Int)
  Heap(Array[T])
}

///|
/// A growable vector type with a logical "inline" storage mode.
///
/// Unlike upstream, `inline_cap` is a runtime value.
struct SmallVec[T] {
  storage : Storage[T]
  inline_cap : Int
}

///|
fn[T : Default] SmallVec::new(inline_cap : Int) -> SmallVec[T] {
  let buf = FixedArray::make(inline_cap, T::default())
  SmallVec::{ storage: Inline(buf, 0), inline_cap }
}

///|
fn[T] SmallVec::with_len(len : Int, value : T, inline_cap : Int) -> SmallVec[T] {
  if len <= inline_cap {
    let buf = FixedArray::make(inline_cap, value)
    SmallVec::{ storage: Inline(buf, len), inline_cap }
  } else {
    let vec = Array::make(len, value)
    SmallVec::{ storage: Heap(vec), inline_cap }
  }
}

///|
fn[T] SmallVec::len(self : SmallVec[T]) -> Int {
  match self.storage {
    Inline(_buf, len) => len
    Heap(vec) => vec.length()
  }
}

///|
fn[T] SmallVec::is_inline(self : SmallVec[T]) -> Bool {
  match self.storage {
    Inline(_, _) => true
    Heap(_) => false
  }
}

///|
fn[T] SmallVec::as_view(self : SmallVec[T]) -> ArrayView[T] {
  match self.storage {
    Inline(buf, len) => buf.sub(end=len)
    Heap(vec) => vec.op_as_view()
  }
}

///|
fn[T] SmallVec::to_array(self : SmallVec[T]) -> Array[T] {
  match self.storage {
    Inline(buf, len) => {
      let out = Array::new(capacity=len)
      for i in 0..<len {
        out.push(buf.at(i))
      }
      out
    }
    Heap(vec) => vec.copy()
  }
}

///|
fn[T] SmallVec::clear(self : SmallVec[T]) -> SmallVec[T] {
  match self.storage {
    Inline(buf, _len) =>
      SmallVec::{ storage: Inline(buf, 0), inline_cap: self.inline_cap }
    Heap(vec) => {
      vec.clear()
      SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }
    }
  }
}

///|
fn[T] SmallVec::try_reserve(
  self : SmallVec[T],
  additional : Int,
) -> (SmallVec[T], Bool) {
  match self.storage {
    Inline(buf, len) => {
      let need = len + additional
      if need > self.inline_cap {
        let vec = Array::new(capacity=need)
        for i in 0..<len {
          vec.push(buf.at(i))
        }
        (SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }, true)
      } else {
        (self, true)
      }
    }
    Heap(vec) => {
      vec.reserve_capacity(vec.length() + additional)
      (SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }, true)
    }
  }
}

///|
fn[T] SmallVec::push(self : SmallVec[T], value : T) -> SmallVec[T] {
  match self.storage {
    Inline(buf, len) =>
      if len + 1 > self.inline_cap {
        let vec = Array::new(capacity=len + 1)
        for i in 0..<len {
          vec.push(buf.at(i))
        }
        vec.push(value)
        SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }
      } else {
        buf.set(len, value)
        SmallVec::{ storage: Inline(buf, len + 1), inline_cap: self.inline_cap }
      }
    Heap(vec) => {
      vec.push(value)
      SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }
    }
  }
}

///|
fn[T] SmallVec::pop(self : SmallVec[T]) -> (SmallVec[T], T?) {
  match self.storage {
    Inline(buf, len) =>
      if len > 0 {
        let v = buf.at(len - 1)
        (
          SmallVec::{
            storage: Inline(buf, len - 1),
            inline_cap: self.inline_cap,
          },
          Some(v),
        )
      } else {
        (self, None)
      }
    Heap(vec) => {
      let v = vec.pop()
      (SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }, v)
    }
  }
}

///|
fn[T] SmallVec::truncate(self : SmallVec[T], new_len : Int) -> SmallVec[T] {
  match self.storage {
    Inline(buf, len) => {
      let next_len = if new_len < len { new_len } else { len }
      SmallVec::{ storage: Inline(buf, next_len), inline_cap: self.inline_cap }
    }
    Heap(vec) => {
      vec.truncate(new_len)
      SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }
    }
  }
}

///|
fn[T] SmallVec::get(self : SmallVec[T], i : Int) -> T? {
  match self.storage {
    Inline(buf, len) => if i >= 0 && i < len { Some(buf.at(i)) } else { None }
    Heap(vec) => vec.get(i)
  }
}

///|
fn[T] SmallVec::set(self : SmallVec[T], i : Int, v : T) -> SmallVec[T] {
  match self.storage {
    Inline(buf, len) => {
      if i >= 0 && i < len {
        buf.set(i, v)
      } else {
        // Keep behavior simple: ignore out-of-range writes (only used in tests).
        i |> ignore
      }
      SmallVec::{ storage: Inline(buf, len), inline_cap: self.inline_cap }
    }
    Heap(vec) => {
      if i >= 0 && i < vec.length() {
        vec.set(i, v)
      } else {
        i |> ignore
      }
      SmallVec::{ storage: Heap(vec), inline_cap: self.inline_cap }
    }
  }
}

///|
test "choose_inline" {
  let vec = SmallVec::with_len(4, 0, 4)
  inspect(vec.is_inline(), content="true")
  inspect(vec.len(), content="4")
}

///|
test "choose_heap" {
  let vec = SmallVec::with_len(5, 0, 4)
  inspect(vec.is_inline(), content="false")
  inspect(vec.len(), content="5")
}

///|
test "store_and_read_inline" {
  let mut vec = SmallVec::with_len(8, 0, 8)
  for i in 0..<vec.len() {
    vec = vec.set(i, i * 2)
  }
  inspect(vec.to_array(), content="[0, 2, 4, 6, 8, 10, 12, 14]")
}

///|
test "store_and_read_heap" {
  let mut vec = SmallVec::with_len(8, 0, 4)
  for i in 0..<vec.len() {
    vec = vec.set(i, i * 2)
  }
  inspect(vec.to_array(), content="[0, 2, 4, 6, 8, 10, 12, 14]")
}

///|
test "spill_to_heap" {
  let mut vec : SmallVec[Int] = SmallVec::new(4)
  for i in 0..<4 {
    vec = vec.push(i)
  }
  inspect(vec.is_inline(), content="true")
  vec = vec.push(4)
  inspect(vec.is_inline(), content="false")
  inspect(vec.to_array(), content="[0, 1, 2, 3, 4]")
}

///|
test "clear_inline" {
  let mut vec : SmallVec[Int] = SmallVec::new(4)
  for i in 0..<4 {
    vec = vec.push(i)
  }
  inspect(vec.is_inline(), content="true")
  inspect(vec.len(), content="4")
  vec = vec.clear()
  inspect(vec.len(), content="0")
}

///|
test "clear_heap" {
  let mut vec : SmallVec[Int] = SmallVec::new(3)
  for i in 0..<4 {
    vec = vec.push(i)
  }
  inspect(vec.is_inline(), content="false")
  inspect(vec.len(), content="4")
  vec = vec.clear()
  inspect(vec.len(), content="0")
}

///|
test "reserve" {
  let mut vec : SmallVec[Int] = SmallVec::new(3)
  for i in 0..<2 {
    vec = vec.push(i)
  }
  inspect(vec.is_inline(), content="true")
  let (v1, ok1) = vec.try_reserve(1)
  inspect(ok1, content="true")
  inspect(v1.is_inline(), content="true")
  let (v2, ok2) = v1.try_reserve(2)
  inspect(ok2, content="true")
  inspect(v2.is_inline(), content="false")
}

///|
test "pop_inline" {
  let mut vec = SmallVec::with_len(0, 0, 4)
  vec = vec.push(1)
  vec = vec.push(2)
  let (v1, p1) = vec.pop()
  inspect(p1, content="Some(2)")
  let (_v2, p2) = v1.pop()
  inspect(p2, content="Some(1)")
}

///|
test "truncate_inline" {
  let vec = SmallVec::with_len(4, 7, 4)
  let v2 = vec.truncate(2)
  inspect(v2.len(), content="2")
  inspect(v2.to_array(), content="[7, 7]")
}

///|
test "get_bounds" {
  let vec = SmallVec::with_len(2, 9, 4)
  inspect(vec.get(0), content="Some(9)")
  inspect(vec.get(1), content="Some(9)")
  inspect(vec.get(2), content="None")
}

///|
test "iter" {
  let mut vec : SmallVec[Int] = SmallVec::new(3)
  for i in 0..<3 {
    vec = vec.push(i)
  }
  let expected = [0, 1, 2]
  inspect(vec.to_array(), content="[0, 1, 2]")
  inspect(Array::from_iter(vec.as_view().iter()), content="[0, 1, 2]")
  inspect(expected, content="[0, 1, 2]")
}

///|
test "into_iter" {
  let mut vec : SmallVec[Int] = SmallVec::new(3)
  for i in 0..<3 {
    vec = vec.push(i)
  }
  // MoonBit doesn't have the same IntoIterator trait shape as Rust; we just
  // validate that iteration yields the same elements.
  inspect(Array::from_iter(vec.as_view().iter()), content="[0, 1, 2]")
}
