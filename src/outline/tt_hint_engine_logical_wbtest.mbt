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
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  TtEngine::new(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::new(),
    Array::new(),
    None,
    0,
    coords0.op_as_view(),
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
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_cmp_lt().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a < b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_cmp_lteq().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a <= b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_cmp_gt().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a > b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_cmp_gteq().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a >= b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_cmp_eq().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a == b { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_cmp_neq().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a != b { 1 } else { 0 }),
        content="true",
      )
    }
  }
}

///|
test "tt_hint: logical parity ops (odd/even)" {
  let engine = tt_make_engine_for_logical()
  // These operate on 26.6 so values are multiple of 64, but also include a non-grid case.
  let cases : Array[(Int, Bool)] = Array::from_fixed_array([
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
    engine.value_stack.push(input).unwrap() |> ignore
    engine.op_even().unwrap() |> ignore
    inspect(
      engine.value_stack.pop().unwrap() == (if is_even { 1 } else { 0 }),
      content="true",
    )
  }
  for entry in cases.iter() {
    let (input, is_even) = entry
    engine.value_stack.clear()
    engine.value_stack.push(input).unwrap() |> ignore
    engine.op_odd().unwrap() |> ignore
    inspect(
      engine.value_stack.pop().unwrap() == (if !is_even { 1 } else { 0 }),
      content="true",
    )
  }
}

///|
test "tt_hint: logical NOT" {
  let engine = tt_make_engine_for_logical()
  engine.value_stack.clear()
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_not().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 1, content="true")
  engine.value_stack.clear()
  engine.value_stack.push(234234).unwrap() |> ignore
  engine.op_not().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 0, content="true")
}

///|
test "tt_hint: logical AND/OR" {
  let engine = tt_make_engine_for_logical()
  for a in -10..<11 {
    for b in -10..<11 {
      let a0 = a != 0
      let b0 = b != 0
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_and().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a0 && b0 { 1 } else { 0 }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_or().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a0 || b0 { 1 } else { 0 }),
        content="true",
      )
    }
  }
}
