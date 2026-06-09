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
test "tt_hint: round to grid" {
  let cases = [(0, 0), (32, 64), (-32, -64), (64, 64), (50, 64)]
  for pair in cases {
    let (v, expected) = pair
    let state = TtRoundState::default()
    state.mode = Grid
    let got = state.round(v)
    inspect(got == expected, content="true")
  }
}

///|
test "tt_hint: round to half grid" {
  let cases = [(0, 32), (32, 32), (-32, -32), (64, 96), (50, 32)]
  for pair in cases {
    let (v, expected) = pair
    let state = TtRoundState::default()
    state.mode = HalfGrid
    let got = state.round(v)
    inspect(got == expected, content="true")
  }
}

///|
test "tt_hint: round to double grid" {
  let cases = [(0, 0), (32, 32), (-32, -32), (64, 64), (50, 64)]
  for pair in cases {
    let (v, expected) = pair
    let state = TtRoundState::default()
    state.mode = DoubleGrid
    let got = state.round(v)
    inspect(got == expected, content="true")
  }
}

///|
test "tt_hint: round down to grid" {
  let cases = [(0, 0), (32, 0), (-32, 0), (64, 64), (50, 0)]
  for pair in cases {
    let (v, expected) = pair
    let state = TtRoundState::default()
    state.mode = DownToGrid
    let got = state.round(v)
    inspect(got == expected, content="true")
  }
}

///|
test "tt_hint: round up to grid" {
  let cases = [(0, 0), (32, 64), (-32, -64), (64, 64), (50, 64)]
  for pair in cases {
    let (v, expected) = pair
    let state = TtRoundState::default()
    state.mode = UpToGrid
    let got = state.round(v)
    inspect(got == expected, content="true")
  }
}

///|
test "tt_hint: round off" {
  let cases = [(0, 0), (32, 32), (-32, -32), (64, 64), (50, 50)]
  for pair in cases {
    let (v, expected) = pair
    let state = TtRoundState::default()
    state.mode = Off
    let got = state.round(v)
    inspect(got == expected, content="true")
  }
}
