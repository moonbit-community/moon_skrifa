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
fn tt_make_engine_for_logical() -> TtEngine {
  let empty = Bytes::from_array([][:])
  let retained = TtRetainedGraphicsState(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = []
  TtEngine(
    empty[:],
    empty[:],
    empty[:],
    retained,
    [],
    [],
    None,
    0,
    coords0[:],
    64,
    32,
    64,
    64,
  )
}

///|
test "tt_hint: logical compare ops" {
  let engine = tt_make_engine_for_logical()
  for a in -10..<11 {
    for b in -10..<11 {
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_cmp_lt() |> ignore
      inspect(
        engine.value_stack.pop() == (if a < b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_cmp_lteq() |> ignore
      inspect(
        engine.value_stack.pop() == (if a <= b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_cmp_gt() |> ignore
      inspect(
        engine.value_stack.pop() == (if a > b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_cmp_gteq() |> ignore
      inspect(
        engine.value_stack.pop() == (if a >= b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_cmp_eq() |> ignore
      inspect(
        engine.value_stack.pop() == (if a == b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_cmp_neq() |> ignore
      inspect(
        engine.value_stack.pop() == (if a != b { 1 } else { 0 }),
        content="true",
      )
    }
  }
}

///|
test "tt_hint: logical parity ops (odd/even)" {
  let engine = tt_make_engine_for_logical()
  // These operate on 26.6 so values are multiple of 64, but also include a non-grid case.
  let cases : Array[(Int32, Bool)] = Array::from_fixed_array([
    (0, true),
    (64, false),
    (128, true),
    (192, false),
    (256, true),
    (57, false),
    (-128, true),
  ])
  for entry in cases.iter() {
    let (input, is_even) = entry
    engine.value_stack.clear()
    engine.value_stack.push(input) |> ignore
    engine.op_even() |> ignore
    inspect(
      engine.value_stack.pop() == (if is_even { 1 } else { 0 }),
      content="true",
    )
  }
  for entry in cases.iter() {
    let (input, is_even) = entry
    engine.value_stack.clear()
    engine.value_stack.push(input) |> ignore
    engine.op_odd() |> ignore
    inspect(
      engine.value_stack.pop() == (if !is_even { 1 } else { 0 }),
      content="true",
    )
  }
}

///|
test "tt_hint: logical NOT" {
  let engine = tt_make_engine_for_logical()
  engine.value_stack.clear()
  engine.value_stack.push(0) |> ignore
  engine.op_not() |> ignore
  inspect(engine.value_stack.pop() == 1, content="true")
  engine.value_stack.clear()
  engine.value_stack.push(234234) |> ignore
  engine.op_not() |> ignore
  inspect(engine.value_stack.pop() == 0, content="true")
}

///|
test "tt_hint: logical AND/OR" {
  let engine = tt_make_engine_for_logical()
  for a in -10..<11 {
    for b in -10..<11 {
      let a0 = a != 0
      let b0 = b != 0
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_and() |> ignore
      inspect(
        engine.value_stack.pop() == (if a0 && b0 { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a) |> ignore
      engine.value_stack.push(b) |> ignore
      engine.op_or() |> ignore
      inspect(
        engine.value_stack.pop() == (if a0 || b0 { 1 } else { 0 }),
        content="true",
      )
    }
  }
}
