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
fn tt_make_engine_for_graphics(scale : Int32, ppem : Int32) -> TtEngine {
  let empty = Bytes::from_array([][:])
  let retained = TtRetainedGraphicsState(scale, ppem, Target::default())
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
test "tt_hint: graphics set vectors to coord axis (SVTCA*)" {
  let engine = tt_make_engine_for_graphics(0x10000, 20)
  let one = 0x4000
  let x_axis = TtVec14::{ x: one, y: 0, }
  let y_axis = TtVec14::{ x: 0, y: one, }
  engine.op_svtca(0x00) |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")
  inspect(engine.graphics.proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == y_axis.y, content="true")
  engine.op_svtca(0x01) |> ignore
  inspect(engine.graphics.freedom_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == x_axis.y, content="true")
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_svtca(0x02) |> ignore
  inspect(engine.graphics.proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == y_axis.y, content="true")
  engine.op_svtca(0x03) |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_svtca(0x04) |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")
  engine.op_svtca(0x05) |> ignore
  inspect(engine.graphics.freedom_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == x_axis.y, content="true")
}

///|
test "tt_hint: graphics set/get vectors from stack (SPVFS/SFVFS/GPV/GFV)" {
  let engine = tt_make_engine_for_graphics(0x10000, 20)
  let one = 0x4000
  let x_axis = TtVec14::{ x: one, y: 0, }
  let y_axis = TtVec14::{ x: 0, y: one, }

  // projection vector
  engine.value_stack.push(x_axis.x) |> ignore
  engine.value_stack.push(x_axis.y) |> ignore
  engine.op_spvfs() |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_gpv() |> ignore
  let y = engine.value_stack.pop()
  let x = engine.value_stack.pop()
  inspect(x == x_axis.x && y == x_axis.y, content="true")

  // freedom vector
  engine.value_stack.push(y_axis.x) |> ignore
  engine.value_stack.push(y_axis.y) |> ignore
  engine.op_sfvfs() |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")
  engine.op_gfv() |> ignore
  let y2 = engine.value_stack.pop()
  let x2 = engine.value_stack.pop()
  inspect(x2 == y_axis.x && y2 == y_axis.y, content="true")
}

///|
test "tt_hint: graphics set vectors to line (SPVTL/SFVTL/SDPVTL)" {
  let engine = tt_make_engine_for_graphics(0x10000, 20)
  let one = 0x4000
  let x_axis = TtVec14::{ x: one, y: 0, }
  let y_axis = TtVec14::{ x: 0, y: one, }

  // Set up a glyph zone with 2 points and 2 original points (26.6 bits).
  engine.graphics.glyph = {
    unscaled: [],
    points: Array::from_fixed_array([{ x: 0, y: 0, }, { x: 64, y: 0, }]),
    original: Array::from_fixed_array([{ x: 0, y: 64, }, { x: 0, y: -64, }]),
    flags: Array::make(2, 0),
    contours: [],
  }

  // Set all zone pointers to glyph.
  engine.value_stack.push(1) |> ignore
  engine.op_szps() |> ignore

  // Push point indices a few times for reuse (each op consumes 2).
  for _ in 0..<6 {
    engine.value_stack.push(1) |> ignore
    engine.value_stack.push(0) |> ignore
  }

  // SPVTL
  engine.op_svtl(0x06) |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.op_svtl(0x07) |> ignore
  inspect(engine.graphics.proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == y_axis.y, content="true")

  // SFVTL
  engine.op_svtl(0x08) |> ignore
  inspect(engine.graphics.freedom_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == x_axis.y, content="true")
  engine.op_svtl(0x09) |> ignore
  inspect(engine.graphics.freedom_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.freedom_vector.y == y_axis.y, content="true")

  // SDPVTL (uses original points)
  engine.op_sdpvtl(0x86) |> ignore
  inspect(engine.graphics.dual_proj_vector.x == y_axis.x, content="true")
  inspect(engine.graphics.dual_proj_vector.y == -y_axis.y, content="true")
  engine.op_sdpvtl(0x87) |> ignore
  inspect(engine.graphics.dual_proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.dual_proj_vector.y == x_axis.y, content="true")
}

///|
test "tt_hint: graphics simple state setting + INSTCTRL + SCANCTRL" {
  // Use scale=64 to exercise SSW math.
  let engine = tt_make_engine_for_graphics(64, 20)

  // SRP*
  engine.value_stack.push(111) |> ignore
  engine.op_srp0() |> ignore
  inspect(engine.graphics.rp0 == 111, content="true")
  engine.value_stack.push(222) |> ignore
  engine.op_srp1() |> ignore
  inspect(engine.graphics.rp1 == 222, content="true")
  engine.value_stack.push(333) |> ignore
  engine.op_srp2() |> ignore
  inspect(engine.graphics.rp2 == 333, content="true")

  // ZP*
  engine.value_stack.push(1) |> ignore
  engine.op_szp0() |> ignore
  inspect(engine.graphics.zp0 is Glyph, content="true")
  engine.value_stack.push(0) |> ignore
  engine.op_szp1() |> ignore
  inspect(engine.graphics.zp1 is Twilight, content="true")
  engine.value_stack.push(1) |> ignore
  engine.op_szp2() |> ignore
  inspect(engine.graphics.zp2 is Glyph, content="true")
  engine.value_stack.push(0) |> ignore
  engine.op_szps() |> ignore
  inspect(engine.graphics.zp0 is Twilight, content="true")
  inspect(engine.graphics.zp1 is Twilight, content="true")
  inspect(engine.graphics.zp2 is Twilight, content="true")
  engine.value_stack.push(2) |> ignore
  try engine.op_szps() catch {
    InvalidZoneIndex(2) => ()
    _ => fail("expected InvalidZoneIndex(2)")
  } noraise {
    _ => fail("expected InvalidZoneIndex(2)")
  }

  // Round state mode setters.
  engine.op_rtg() |> ignore
  inspect(engine.graphics.round_state.mode is Grid, content="true")
  engine.op_rtdg() |> ignore
  inspect(engine.graphics.round_state.mode is DoubleGrid, content="true")
  engine.op_rdtg() |> ignore
  inspect(engine.graphics.round_state.mode is DownToGrid, content="true")
  engine.op_rutg() |> ignore
  inspect(engine.graphics.round_state.mode is UpToGrid, content="true")
  engine.op_roff() |> ignore
  inspect(engine.graphics.round_state.mode is Off, content="true")
  engine.value_stack.push(0) |> ignore
  engine.op_sround() |> ignore
  inspect(engine.graphics.round_state.mode is Super, content="true")
  engine.value_stack.push(0) |> ignore
  engine.op_s45round() |> ignore
  inspect(engine.graphics.round_state.mode is Super45, content="true")

  // SLOOP
  engine.value_stack.push(10) |> ignore
  engine.op_sloop() |> ignore
  inspect(engine.graphics.loop_counter == 10, content="true")
  engine.value_stack.push(-10) |> ignore
  try engine.op_sloop() catch {
    NegativeLoopCounter => ()
    _ => fail("expected NegativeLoopCounter")
  } noraise {
    _ => fail("expected NegativeLoopCounter")
  }

  // SMD/SCANTYPE/SCVTCI/SSWCI
  engine.value_stack.push(64) |> ignore
  engine.op_smd() |> ignore
  inspect(engine.graphics.retained.min_distance == 64, content="true")
  engine.value_stack.push(50) |> ignore
  engine.op_scantype() |> ignore
  inspect(engine.graphics.retained.scan_type == 50, content="true")
  engine.value_stack.push(128) |> ignore
  engine.op_scvtci() |> ignore
  inspect(engine.graphics.retained.control_value_cutin == 128, content="true")
  engine.value_stack.push(100) |> ignore
  engine.op_sswci() |> ignore
  inspect(engine.graphics.retained.single_width_cutin == 100, content="true")

  // SSW (scale=64)
  engine.value_stack.push(100) |> ignore
  engine.op_ssw() |> ignore
  inspect(
    engine.graphics.retained.single_width == tt_hint_mul_16_16(100, 64),
    content="true",
  )

  // FLIPON/OFF
  engine.op_flipoff() |> ignore
  inspect(!engine.graphics.retained.auto_flip, content="true")
  engine.op_flipon() |> ignore
  inspect(engine.graphics.retained.auto_flip, content="true")

  // SDB/SDS (delta_shift clamped to <= 6)
  engine.value_stack.push(172) |> ignore
  engine.op_sdb() |> ignore
  inspect(engine.graphics.retained.delta_base == 172, content="true")
  engine.value_stack.push(4) |> ignore
  engine.op_sds() |> ignore
  inspect(engine.graphics.retained.delta_shift == 4, content="true")
  engine.value_stack.push(7) |> ignore
  try engine.op_sds() catch {
    InvalidStackValue(7) => ()
    _ => fail("expected InvalidStackValue(7)")
  } noraise {
    _ => fail("expected InvalidStackValue(7)")
  }

  // INSTCTRL (control value program): toggle instruct_control bits.
  engine.program.current = ControlValue
  for selector in 1..<4 {
    let enable_mask = 1 << (selector - 1)
    engine.value_stack.push(enable_mask) |> ignore
    engine.value_stack.push(selector) |> ignore
    engine.op_instctrl() |> ignore
    inspect(
      (engine.graphics.retained.instruct_control & enable_mask) != 0,
      content="true",
    )
    engine.value_stack.push(0) |> ignore
    engine.value_stack.push(selector) |> ignore
    engine.op_instctrl() |> ignore
    inspect(
      (engine.graphics.retained.instruct_control & enable_mask) == 0,
      content="true",
    )
  }

  // INSTCTRL avoid overflow when selector=0
  engine.value_stack.push(0) |> ignore
  engine.value_stack.push(0) |> ignore
  engine.op_instctrl() |> ignore

  // INSTCTRL (glyph program): selector 3 toggles backward_compatibility.
  engine.program.current = Glyph
  engine.value_stack.push(4) |> ignore
  engine.value_stack.push(3) |> ignore
  engine.op_instctrl() |> ignore
  inspect(!engine.graphics.backward_compatibility, content="true")
  engine.value_stack.push(0) |> ignore
  engine.value_stack.push(3) |> ignore
  engine.op_instctrl() |> ignore
  inspect(engine.graphics.backward_compatibility, content="true")

  // SCANCTRL examples: 0 disables, 0xFF enables.
  engine.value_stack.push(0x0000) |> ignore
  engine.op_scanctrl() |> ignore
  inspect(!engine.graphics.retained.scan_control, content="true")
  engine.value_stack.push(0x01FF) |> ignore
  engine.op_scanctrl() |> ignore
  inspect(engine.graphics.retained.scan_control, content="true")

  // Conditional dropout control: 0x0A10 => if rotated and ppem < 16.
  let prev = engine.graphics.retained
  engine.graphics.retained = TtRetainedGraphicsState::new_with_flags(
    prev.scale,
    12,
    prev.target,
    true,
    prev.is_stretched,
  )
  engine.value_stack.push(0x0A10) |> ignore
  engine.op_scanctrl() |> ignore
  inspect(engine.graphics.retained.scan_control, content="true")
}

///|
test "tt_hint: graphics set vectors to line handles equal points (x-axis default)" {
  let engine = tt_make_engine_for_graphics(0x10000, 20)
  let one = 0x4000
  let x_axis = TtVec14::{ x: one, y: 0, }
  engine.graphics.glyph = {
    unscaled: [],
    points: Array::from_fixed_array([{ x: 0, y: 0, }, { x: 0, y: 0, }]),
    original: Array::from_fixed_array([{ x: 0, y: 0, }, { x: 0, y: 0, }]),
    flags: Array::make(2, 0),
    contours: [],
  }
  engine.value_stack.push(1) |> ignore
  engine.op_szps() |> ignore

  // If the points are equal, fontations/FreeType default the line vector to the x-axis
  // (even for the perpendicular form).
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(0) |> ignore
  engine.op_svtl(0x06) |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
  engine.value_stack.push(1) |> ignore
  engine.value_stack.push(0) |> ignore
  engine.op_svtl(0x07) |> ignore
  inspect(engine.graphics.proj_vector.x == x_axis.x, content="true")
  inspect(engine.graphics.proj_vector.y == x_axis.y, content="true")
}
