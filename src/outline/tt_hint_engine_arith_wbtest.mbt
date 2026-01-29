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
fn tt_make_engine_for_arith() -> TtEngine {
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
test "tt_hint: arith simple binops" {
  let engine = tt_make_engine_for_arith()
  // Parentheses are required for negative range starts.
  for a in -10..<12 {
    for b in -10..<12 {
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_add().unwrap() |> ignore
      inspect(engine.value_stack.pop().unwrap() == a + b, content="true")
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_sub().unwrap() |> ignore
      inspect(engine.value_stack.pop().unwrap() == a - b, content="true")
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_max().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a > b { a } else { b }),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_min().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == (if a < b { a } else { b }),
        content="true",
      )
    }
  }
}

///|
test "tt_hint: arith simple unops" {
  let engine = tt_make_engine_for_arith()
  for a in -10..<12 {
    engine.value_stack.clear()
    engine.value_stack.push(a).unwrap() |> ignore
    engine.op_neg().unwrap() |> ignore
    inspect(engine.value_stack.pop().unwrap() == -a, content="true")
    engine.value_stack.clear()
    engine.value_stack.push(a).unwrap() |> ignore
    engine.op_abs().unwrap() |> ignore
    inspect(engine.value_stack.pop().unwrap() == a.abs(), content="true")
  }
}

///|
test "tt_hint: arith f26dot6 binops (mul/div)" {
  let engine = tt_make_engine_for_arith()
  for a0 in -10..<12 {
    for b0 in -10..<12 {
      let a = a0 * 64 + 30
      let b = b0 * 64 - 30
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      engine.op_mul().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == tt_hint_mul_div_16_16(a, b, 64),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.value_stack.push(b).unwrap() |> ignore
      if b != 0 {
        engine.op_div().unwrap() |> ignore
        inspect(
          engine.value_stack.pop().unwrap() ==
          tt_hint_mul_div_no_round(a, 64, b),
          content="true",
        )
      } else {
        match engine.op_div() {
          Err(HintError::DivideByZero) => ()
          Ok(_) => fail("expected DivideByZero")
          Err(_) => fail("expected DivideByZero")
        }
      }
    }
  }
}

///|
test "tt_hint: arith f26dot6 unops (floor/ceil)" {
  let engine = tt_make_engine_for_arith()
  for a0 in -10..<12 {
    for b in -10..<12 {
      let a = a0 * 64 + b
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.op_floor().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == tt_hint_floor_26(a),
        content="true",
      )
      engine.value_stack.clear()
      engine.value_stack.push(a).unwrap() |> ignore
      engine.op_ceiling().unwrap() |> ignore
      inspect(
        engine.value_stack.pop().unwrap() == tt_hint_ceil_26(a),
        content="true",
      )
    }
  }
}
