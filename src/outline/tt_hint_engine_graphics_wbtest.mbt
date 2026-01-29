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
fn tt_make_engine_for_graphics(scale : Int, ppem : Int) -> TtEngine {
  let empty = Bytes::from_array(Array::new().op_as_view())
  let retained = TtRetainedGraphicsState::new(scale, ppem, Target::default())
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
test "tt_hint: graphics set vectors to coord axis (SVTCA*)" {
  let engine = tt_make_engine_for_graphics(0x10000, 20)
  let one = 0x4000
  let x_axis = TtVec14::{ x: one, y: 0 }
  let y_axis = TtVec14::{ x: 0, y: one }
  engine.op_svtca(0x00).unwrap() |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")
  inspect(engine.graphics.proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == y_axis.y, content="true")
  engine.op_svtca(0x01).unwrap() |> ignore
  inspect(engine.graphics.freedom_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == x_axis.y, content="true")
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_svtca(0x02).unwrap() |> ignore
  inspect(engine.graphics.proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == y_axis.y, content="true")
  engine.op_svtca(0x03).unwrap() |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_svtca(0x04).unwrap() |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")
  engine.op_svtca(0x05).unwrap() |> ignore
  inspect(engine.graphics.freedom_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == x_axis.y, content="true")
}

///|
test "tt_hint: graphics set/get vectors from stack (SPVFS/SFVFS/GPV/GFV)" {
  let engine = tt_make_engine_for_graphics(0x10000, 20)
  let one = 0x4000
  let x_axis = TtVec14::{ x: one, y: 0 }
  let y_axis = TtVec14::{ x: 0, y: one }

  // projection vector
  engine.value_stack.push(x_axis.x).unwrap() |> ignore
  engine.value_stack.push(x_axis.y).unwrap() |> ignore
  engine.op_spvfs().unwrap() |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_gpv().unwrap() |> ignore
  let y = engine.value_stack.pop().unwrap()
  let x = engine.value_stack.pop().unwrap()
  inspect(x == x_axis.x && y == x_axis.y, content="true")

  // freedom vector
  engine.value_stack.push(y_axis.x).unwrap() |> ignore
  engine.value_stack.push(y_axis.y).unwrap() |> ignore
  engine.op_sfvfs().unwrap() |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")
  engine.op_gfv().unwrap() |> ignore
  let y2 = engine.value_stack.pop().unwrap()
  let x2 = engine.value_stack.pop().unwrap()
  inspect(x2 == y_axis.x && y2 == y_axis.y, content="true")
}

///|
test "tt_hint: graphics set vectors to line (SPVTL/SFVTL/SDPVTL)" {
  let engine = tt_make_engine_for_graphics(0x10000, 20)
  let one = 0x4000
  let x_axis = TtVec14::{ x: one, y: 0 }
  let y_axis = TtVec14::{ x: 0, y: one }

  // Set up a glyph zone with 2 points and 2 original points (26.6 bits).
  engine.graphics.glyph = TtZone::{
    unscaled: Array::new(),
    points: Array::from_fixed_array([
      TtPoint::{ x: 0, y: 0 },
      TtPoint::{ x: 64, y: 0 },
    ]),
    original: Array::from_fixed_array([
      TtPoint::{ x: 0, y: 64 },
      TtPoint::{ x: 0, y: -64 },
    ]),
    flags: Array::make(2, 0),
    contours: Array::new(),
  }

  // Set all zone pointers to glyph.
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_szps().unwrap() |> ignore

  // Push point indices a few times for reuse (each op consumes 2).
  for _ in 0..<6 {
    engine.value_stack.push(1).unwrap() |> ignore
    engine.value_stack.push(0).unwrap() |> ignore
  }

  // SPVTL
  engine.op_svtl(0x06).unwrap() |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_svtl(0x07).unwrap() |> ignore
  inspect(engine.graphics.proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == y_axis.y, content="true")

  // SFVTL
  engine.op_svtl(0x08).unwrap() |> ignore
  inspect(engine.graphics.freedom_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == x_axis.y, content="true")
  engine.op_svtl(0x09).unwrap() |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")

  // SDPVTL (uses original points)
  engine.op_sdpvtl(0x86).unwrap() |> ignore
  inspect(engine.graphics.dual_proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.dual_proj_vector.y == -y_axis.y, content="true")
  engine.op_sdpvtl(0x87).unwrap() |> ignore
  inspect(engine.graphics.dual_proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.dual_proj_vector.y == x_axis.y, content="true")
}

///|
test "tt_hint: graphics simple state setting + INSTCTRL + SCANCTRL" {
  // Use scale=64 to exercise SSW math.
  let engine = tt_make_engine_for_graphics(64, 20)

  // SRP*
  engine.value_stack.push(111).unwrap() |> ignore
  engine.op_srp0().unwrap() |> ignore
  inspect(engine.graphics.rp0 == 111, content="true")
  engine.value_stack.push(222).unwrap() |> ignore
  engine.op_srp1().unwrap() |> ignore
  inspect(engine.graphics.rp1 == 222, content="true")
  engine.value_stack.push(333).unwrap() |> ignore
  engine.op_srp2().unwrap() |> ignore
  inspect(engine.graphics.rp2 == 333, content="true")

  // ZP*
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_szp0().unwrap() |> ignore
  inspect(engine.graphics.zp0 is TtZonePointer::Glyph, content="true")
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_szp1().unwrap() |> ignore
  inspect(engine.graphics.zp1 is TtZonePointer::Twilight, content="true")
  engine.value_stack.push(1).unwrap() |> ignore
  engine.op_szp2().unwrap() |> ignore
  inspect(engine.graphics.zp2 is TtZonePointer::Glyph, content="true")
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_szps().unwrap() |> ignore
  inspect(engine.graphics.zp0 is TtZonePointer::Twilight, content="true")
  inspect(engine.graphics.zp1 is TtZonePointer::Twilight, content="true")
  inspect(engine.graphics.zp2 is TtZonePointer::Twilight, content="true")
  engine.value_stack.push(2).unwrap() |> ignore
  match engine.op_szps() {
    Err(HintError::InvalidZoneIndex(2)) => ()
    Ok(_) => fail("expected InvalidZoneIndex(2)")
    Err(_) => fail("expected InvalidZoneIndex(2)")
  }

  // Round state mode setters.
  engine.op_rtg().unwrap() |> ignore
  inspect(engine.graphics.round_state.mode is TtRoundMode::Grid, content="true")
  engine.op_rtdg().unwrap() |> ignore
  inspect(
    engine.graphics.round_state.mode is TtRoundMode::DoubleGrid,
    content="true",
  )
  engine.op_rdtg().unwrap() |> ignore
  inspect(
    engine.graphics.round_state.mode is TtRoundMode::DownToGrid,
    content="true",
  )
  engine.op_rutg().unwrap() |> ignore
  inspect(
    engine.graphics.round_state.mode is TtRoundMode::UpToGrid,
    content="true",
  )
  engine.op_roff().unwrap() |> ignore
  inspect(engine.graphics.round_state.mode is TtRoundMode::Off, content="true")
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_sround().unwrap() |> ignore
  inspect(
    engine.graphics.round_state.mode is TtRoundMode::Super,
    content="true",
  )
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_s45round().unwrap() |> ignore
  inspect(
    engine.graphics.round_state.mode is TtRoundMode::Super45,
    content="true",
  )

  // SLOOP
  engine.value_stack.push(10).unwrap() |> ignore
  engine.op_sloop().unwrap() |> ignore
  inspect(engine.graphics.loop_counter == 10, content="true")
  engine.value_stack.push(-10).unwrap() |> ignore
  match engine.op_sloop() {
    Err(HintError::NegativeLoopCounter) => ()
    Ok(_) => fail("expected NegativeLoopCounter")
    Err(_) => fail("expected NegativeLoopCounter")
  }

  // SMD/SCANTYPE/SCVTCI/SSWCI
  engine.value_stack.push(64).unwrap() |> ignore
  engine.op_smd().unwrap() |> ignore
  inspect(engine.graphics.retained.min_distance == 64, content="true")
  engine.value_stack.push(50).unwrap() |> ignore
  engine.op_scantype().unwrap() |> ignore
  inspect(engine.graphics.retained.scan_type == 50, content="true")
  engine.value_stack.push(128).unwrap() |> ignore
  engine.op_scvtci().unwrap() |> ignore
  inspect(engine.graphics.retained.control_value_cutin == 128, content="true")
  engine.value_stack.push(100).unwrap() |> ignore
  engine.op_sswci().unwrap() |> ignore
  inspect(engine.graphics.retained.single_width_cutin == 100, content="true")

  // SSW (scale=64)
  engine.value_stack.push(100).unwrap() |> ignore
  engine.op_ssw().unwrap() |> ignore
  inspect(
    engine.graphics.retained.single_width == tt_hint_mul_16_16(100, 64),
    content="true",
  )

  // FLIPON/OFF
  engine.op_flipoff().unwrap() |> ignore
  inspect(!engine.graphics.retained.auto_flip, content="true")
  engine.op_flipon().unwrap() |> ignore
  inspect(engine.graphics.retained.auto_flip, content="true")

  // SDB/SDS (delta_shift clamped to <= 6)
  engine.value_stack.push(172).unwrap() |> ignore
  engine.op_sdb().unwrap() |> ignore
  inspect(engine.graphics.retained.delta_base == 172, content="true")
  engine.value_stack.push(4).unwrap() |> ignore
  engine.op_sds().unwrap() |> ignore
  inspect(engine.graphics.retained.delta_shift == 4, content="true")
  engine.value_stack.push(7).unwrap() |> ignore
  match engine.op_sds() {
    Err(HintError::InvalidStackValue(7)) => ()
    Ok(_) => fail("expected InvalidStackValue(7)")
    Err(_) => fail("expected InvalidStackValue(7)")
  }

  // INSTCTRL (control value program): toggle instruct_control bits.
  engine.program.current = TtProgram::ControlValue
  for selector in 1..<4 {
    let enable_mask = 1 << (selector - 1)
    engine.value_stack.push(enable_mask).unwrap() |> ignore
    engine.value_stack.push(selector).unwrap() |> ignore
    engine.op_instctrl().unwrap() |> ignore
    inspect(
      (engine.graphics.retained.instruct_control & enable_mask) != 0,
      content="true",
    )
    engine.value_stack.push(0).unwrap() |> ignore
    engine.value_stack.push(selector).unwrap() |> ignore
    engine.op_instctrl().unwrap() |> ignore
    inspect(
      (engine.graphics.retained.instruct_control & enable_mask) == 0,
      content="true",
    )
  }

  // INSTCTRL avoid overflow when selector=0
  engine.value_stack.push(0).unwrap() |> ignore
  engine.value_stack.push(0).unwrap() |> ignore
  engine.op_instctrl().unwrap() |> ignore

  // INSTCTRL (glyph program): selector 3 toggles backward_compatibility.
  engine.program.current = TtProgram::Glyph
  engine.value_stack.push(4).unwrap() |> ignore
  engine.value_stack.push(3).unwrap() |> ignore
  engine.op_instctrl().unwrap() |> ignore
  inspect(!engine.graphics.backward_compatibility, content="true")
  engine.value_stack.push(0).unwrap() |> ignore
  engine.value_stack.push(3).unwrap() |> ignore
  engine.op_instctrl().unwrap() |> ignore
  inspect(engine.graphics.backward_compatibility, content="true")

  // SCANCTRL examples: 0 disables, 0xFF enables.
  engine.value_stack.push(0x0000).unwrap() |> ignore
  engine.op_scanctrl().unwrap() |> ignore
  inspect(!engine.graphics.retained.scan_control, content="true")
  engine.value_stack.push(0x01FF).unwrap() |> ignore
  engine.op_scanctrl().unwrap() |> ignore
  inspect(engine.graphics.retained.scan_control, content="true")
}
