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
/// Rounding state for the TrueType interpreter.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/round.rs` (Apache-2.0 OR MIT).
priv enum TtRoundMode {
  Grid
  HalfGrid
  DoubleGrid
  DownToGrid
  UpToGrid
  Off
  Super
  Super45
}

///|
priv struct TtRoundState {
  mode : TtRoundMode
  threshold : Int
  phase : Int
  period : Int
}

///|
fn TtRoundState::default() -> TtRoundState {
  TtRoundState::{ mode: TtRoundMode::Grid, threshold: 0, phase: 0, period: 64 }
}

///|
fn TtRoundState::round(self : TtRoundState, distance_bits : Int) -> Int {
  match self.mode {
    TtRoundMode::HalfGrid =>
      if distance_bits >= 0 {
        (tt_hint_floor_26(distance_bits) + 32).max(0)
      } else {
        (-(tt_hint_floor_26(-distance_bits) + 32)).min(0)
      }
    TtRoundMode::Grid =>
      if distance_bits >= 0 {
        tt_hint_round_26(distance_bits).max(0)
      } else {
        (-tt_hint_round_26(-distance_bits)).min(0)
      }
    TtRoundMode::DoubleGrid =>
      if distance_bits >= 0 {
        tt_hint_round_pad(distance_bits, 32).max(0)
      } else {
        (-tt_hint_round_pad(-distance_bits, 32)).min(0)
      }
    TtRoundMode::DownToGrid =>
      if distance_bits >= 0 {
        tt_hint_floor_26(distance_bits).max(0)
      } else {
        (-tt_hint_floor_26(-distance_bits)).min(0)
      }
    TtRoundMode::UpToGrid =>
      if distance_bits >= 0 {
        tt_hint_ceil_26(distance_bits).max(0)
      } else {
        (-tt_hint_ceil_26(-distance_bits)).min(0)
      }
    TtRoundMode::Super =>
      if distance_bits >= 0 {
        let val = (
            (distance_bits + (self.threshold - self.phase)) & -self.period
          ) +
          self.phase
        if val < 0 {
          self.phase
        } else {
          val
        }
      } else {
        let val = -((self.threshold - self.phase - distance_bits) & -self.period) -
          self.phase
        if val > 0 {
          -self.phase
        } else {
          val
        }
      }
    TtRoundMode::Super45 =>
      if distance_bits >= 0 {
        let val = (distance_bits + (self.threshold - self.phase)) /
          self.period *
          self.period +
          self.phase
        if val < 0 {
          self.phase
        } else {
          val
        }
      } else {
        let val = -((self.threshold - self.phase - distance_bits) /
          self.period *
          self.period) -
          self.phase
        if val > 0 {
          -self.phase
        } else {
          val
        }
      }
    TtRoundMode::Off => distance_bits
  }
}
