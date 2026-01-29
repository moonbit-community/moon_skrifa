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
fn tt_make_engine_for_cvt_storage() -> TtEngine {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(0x10000, 20, Target::default())
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  TtEngine::new(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::make(16, 0), // cvt
    Array::make(16, 0), // storage
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
test "tt_hint: storage WS/RS write and read" {
  let engine = tt_make_engine_for_cvt_storage()
  for i in 0..<8 {
    engine.value_stack.push(i).unwrap() |> ignore
    engine.value_stack.push(i * 2).unwrap() |> ignore
    engine.op_ws().unwrap() |> ignore
  }
  for i in 0..<8 {
    engine.value_stack.push(i).unwrap() |> ignore
    engine.op_rs().unwrap() |> ignore
    inspect(engine.value_stack.pop().unwrap() == i * 2, content="true")
  }
}

///|
test "tt_hint: storage pedantry (OOB read/write)" {
  let engine = tt_make_engine_for_cvt_storage()
  let oob_index = 1000

  // Non-pedantic: OOB writes are ignored, OOB reads push 0.
  engine.graphics.is_pedantic = false
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_ws().unwrap() |> ignore
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.op_rs().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 0, content="true")

  // Pedantic: OOB reads/writes error.
  engine.graphics.is_pedantic = true
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  match engine.op_ws() {
    Err(HintError::InvalidStorageIndex(i)) =>
      inspect(i == oob_index, content="true")
    Ok(_) => fail("expected InvalidStorageIndex")
    Err(_) => fail("expected InvalidStorageIndex")
  }
  engine.value_stack.push(oob_index).unwrap() |> ignore
  match engine.op_rs() {
    Err(HintError::InvalidStorageIndex(i)) =>
      inspect(i == oob_index, content="true")
    Ok(_) => fail("expected InvalidStorageIndex")
    Err(_) => fail("expected InvalidStorageIndex")
  }
}

///|
test "tt_hint: CVT WCVTP/WCVTF/RCVT write and read" {
  let engine = tt_make_engine_for_cvt_storage()
  for i in 0..<8 {
    engine.value_stack.push(i).unwrap() |> ignore
    engine.value_stack.push(i * 2).unwrap() |> ignore
    engine.op_wcvtp().unwrap() |> ignore
  }
  for i in 0..<8 {
    engine.value_stack.push(i).unwrap() |> ignore
    engine.op_rcvt().unwrap() |> ignore
    inspect(engine.value_stack.pop().unwrap() == i * 2, content="true")
  }
}

///|
test "tt_hint: CVT WCVTF scaling uses 16.16 mul (fontations parity)" {
  let engine = tt_make_engine_for_cvt_storage()
  let scale = 64
  engine.graphics.retained = TtRetainedGraphicsState::new(
    scale,
    engine.graphics.retained.ppem,
    engine.graphics.retained.target,
  )
  for i in 0..<8 {
    engine.value_stack.push(i).unwrap() |> ignore
    engine.value_stack.push(i * 2).unwrap() |> ignore
    engine.op_wcvtf().unwrap() |> ignore
  }
  for i in 0..<8 {
    engine.value_stack.push(i).unwrap() |> ignore
    engine.op_rcvt().unwrap() |> ignore
    let value = engine.value_stack.pop().unwrap()
    inspect(value == tt_hint_mul_16_16(i * 2, scale), content="true")
  }
}

///|
test "tt_hint: CVT pedantry (OOB read/write)" {
  let engine = tt_make_engine_for_cvt_storage()
  let oob_index = 1000

  // Non-pedantic: OOB writes are ignored, OOB reads push 0.
  engine.graphics.is_pedantic = false
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_wcvtp().unwrap() |> ignore
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_wcvtf().unwrap() |> ignore
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.op_rcvt().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 0, content="true")

  // Pedantic: OOB reads/writes error.
  engine.graphics.is_pedantic = true
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  match engine.op_wcvtp() {
    Err(HintError::InvalidCvtIndex(i)) =>
      inspect(i == oob_index, content="true")
    Ok(_) => fail("expected InvalidCvtIndex")
    Err(_) => fail("expected InvalidCvtIndex")
  }
  engine.value_stack.push(oob_index).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  match engine.op_wcvtf() {
    Err(HintError::InvalidCvtIndex(i)) =>
      inspect(i == oob_index, content="true")
    Ok(_) => fail("expected InvalidCvtIndex")
    Err(_) => fail("expected InvalidCvtIndex")
  }
  engine.value_stack.push(oob_index).unwrap() |> ignore
  match engine.op_rcvt() {
    Err(HintError::InvalidCvtIndex(i)) =>
      inspect(i == oob_index, content="true")
    Ok(_) => fail("expected InvalidCvtIndex")
    Err(_) => fail("expected InvalidCvtIndex")
  }
}
