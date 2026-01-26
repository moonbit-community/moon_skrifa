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
/// Persistent state for TrueType embedded hinting.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/instance.rs`
/// (Apache-2.0 OR MIT).
const TAG_MAXP_TT : UInt = 0x6D617870 // "maxp"

///|
const TAG_FPGM_TT : UInt = 0x6670676D // "fpgm"

///|
const TAG_PREP_TT : UInt = 0x70726570 // "prep"

///|
const TAG_CVT_TT : UInt = 0x63767420 // "cvt "

///|
let tt_empty_bytes : Bytes = Bytes::from_array(Array::new().op_as_view())

///|
fn tt_empty_bytes_view() -> BytesView {
  tt_empty_bytes.op_as_view()
}

///|
fn tt_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn tt_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match tt_read_u16_be(view, offset) {
    None => None
    Some(u) => Some(if u >= 0x8000 { u - 0x10000 } else { u })
  }
}

///|
priv struct TtHintInstance {
  mut functions : TtDefinitionSet
  mut instructions : TtDefinitionSet
  mut cvt : Array[Int]
  mut storage : Array[Int]
  mut retained : TtRetainedGraphicsState
  mut twilight_points : Array[TtPoint]
  mut twilight_original : Array[TtPoint]
  mut twilight_flags : Array[Int]
  mut max_stack : Int
  max_call_depth : Int
  mut max_function_defs : Int
  mut max_instruction_defs : Int
}

///|
fn TtHintInstance::default() -> TtHintInstance {
  TtHintInstance::{
    functions: TtDefinitionSet::new(0),
    instructions: TtDefinitionSet::new(0),
    cvt: Array::new(),
    storage: Array::new(),
    retained: TtRetainedGraphicsState::default(),
    twilight_points: Array::new(),
    twilight_original: Array::new(),
    twilight_flags: Array::new(),
    max_stack: 0,
    max_call_depth: 32,
    max_function_defs: 0,
    max_instruction_defs: 0,
  }
}

///|
fn TtHintInstance::is_enabled(self : TtHintInstance) -> Bool {
  (self.retained.instruct_control & 1) == 0
}

///|
fn TtHintInstance::backward_compatibility(self : TtHintInstance) -> Bool {
  if self.retained.target.preserve_linear_metrics() {
    true
  } else if self.retained.target.is_smooth() {
    (self.retained.instruct_control & 0x4) == 0
  } else {
    false
  }
}

///|
fn tt_parse_maxp_limits(maxp : BytesView) -> (Int, Int, Int, Int, Int) {
  // Returns (max_function_defs, max_instruction_defs, max_twilight_points, max_stack, max_storage).
  let max_function_defs = tt_read_u16_be(maxp, 20).unwrap_or(0)
  let max_instruction_defs = tt_read_u16_be(maxp, 22).unwrap_or(0)
  let max_twilight_points = tt_read_u16_be(maxp, 16).unwrap_or(0) + 4
  let max_stack = tt_read_u16_be(maxp, 24).unwrap_or(0) + 32
  let max_storage = tt_read_u16_be(maxp, 18).unwrap_or(0)
  (
    max_function_defs, max_instruction_defs, max_twilight_points, max_stack, max_storage,
  )
}

///|
fn tt_load_cvt(font : @moon_skrifa.FontRef) -> Array[Int] {
  match font.table(TAG_CVT_TT) {
    None => Array::new()
    Some(cvt) => {
      let n = cvt.length() / 2
      let out : Array[Int] = Array::new()
      for i in 0..<n {
        let v = tt_read_i16_be(cvt, i * 2).unwrap_or(0)
        out.push(v * 64)
      }
      out
    }
  }
}

///|
fn tt_scale_cvt_for_size(cvt : Array[Int], scale_bits : Int) -> Array[Int] {
  // CVT values are already in 26.6; scale by (scale_bits >> 6) (16.16).
  let s = scale_bits >> 6
  let out : Array[Int] = Array::new()
  for v in cvt.iter() {
    let vv = v.to_int64() * s.to_int64()
    let adj = 0x8000 - (if vv < 0 { 1 } else { 0 })
    out.push(((vv + adj.to_int64()) >> 16).to_int())
  }
  out
}

///|
fn tt_make_twilight_zone(point_count : Int) -> TtZone {
  let pts : Array[TtPoint] = Array::make(point_count, TtPoint::{ x: 0, y: 0 })
  let orig : Array[TtPoint] = Array::make(point_count, TtPoint::{ x: 0, y: 0 })
  let flags : Array[Int] = Array::make(point_count, 0)
  let contours : Array[Int] = Array::from_fixed_array([point_count])
  TtZone::{
    unscaled: Array::new(),
    original: orig,
    points: pts,
    flags,
    contours,
  }
}

///|
fn tt_make_empty_glyph_zone() -> TtZone {
  TtZone::{
    unscaled: Array::new(),
    original: Array::new(),
    points: Array::new(),
    flags: Array::new(),
    contours: Array::new(),
  }
}

///|
fn TtHintInstance::reconfigure(
  self : TtHintInstance,
  font : @moon_skrifa.FontRef,
  scale_bits : Int,
  rounded_ppem : Int,
  target : Target,
) -> Result[Unit, HintError] {
  let maxp = match font.table(TAG_MAXP_TT) {
    None => return Err(HintError::Unsupported)
    Some(v) => v
  }
  let (
    max_function_defs,
    max_instruction_defs,
    max_twilight_points,
    max_stack,
    max_storage,
  ) = tt_parse_maxp_limits(maxp)
  self.functions = TtDefinitionSet::new(max_function_defs)
  self.instructions = TtDefinitionSet::new(max_instruction_defs)
  self.max_stack = max_stack
  self.max_function_defs = max_function_defs
  self.max_instruction_defs = max_instruction_defs
  self.storage = Array::make(max_storage, 0)
  // Load and scale CVT.
  self.cvt = tt_scale_cvt_for_size(tt_load_cvt(font), scale_bits)
  // Twilight buffers.
  self.twilight_points = Array::make(max_twilight_points, TtPoint::{
    x: 0,
    y: 0,
  })
  self.twilight_original = Array::make(max_twilight_points, TtPoint::{
    x: 0,
    y: 0,
  })
  self.twilight_flags = Array::make(max_twilight_points, 0)
  // Create engine to run fpgm+prep.
  let fpgm = font.table(TAG_FPGM_TT).unwrap_or(tt_empty_bytes_view())
  let prep = font.table(TAG_PREP_TT).unwrap_or(tt_empty_bytes_view())
  let retained = TtRetainedGraphicsState::new(scale_bits, rounded_ppem, target)
  let engine = TtEngine::new(
    fpgm,
    prep,
    tt_empty_bytes_view(),
    retained,
    self.cvt,
    self.storage,
    max_stack,
    self.max_call_depth,
    max_function_defs,
    max_instruction_defs,
  )
  engine.graphics.twilight = tt_make_twilight_zone(max_twilight_points)
  engine.graphics.glyph = tt_make_empty_glyph_zone()
  // Run fpgm + prep.
  match engine.run_program(TtProgram::Font, false) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match engine.run_program(TtProgram::ControlValue, false) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  // Persist results.
  self.functions = engine.functions
  self.instructions = engine.instructions
  self.cvt = engine.cvt
  self.storage = engine.storage
  self.retained = engine.graphics.retained
  // Capture twilight state after prep.
  self.twilight_points = engine.graphics.twilight.points
  self.twilight_original = engine.graphics.twilight.original
  self.twilight_flags = engine.graphics.twilight.flags
  Ok(())
}

///|
fn TtHintInstance::hint_glyph(
  self : TtHintInstance,
  fpgm : BytesView,
  prep : BytesView,
  glyph_code : BytesView,
  glyph_zone : TtZone,
  is_pedantic : Bool,
) -> Result[TtZone, HintError] {
  // Clone mutable state per glyph (matches upstream's copy-on-write behavior).
  let cvt = self.cvt.copy()
  let storage = self.storage.copy()
  let retained = self.retained
  let engine = TtEngine::new(
    fpgm,
    prep,
    glyph_code,
    retained,
    cvt,
    storage,
    self.max_stack,
    self.max_call_depth,
    self.max_function_defs,
    self.max_instruction_defs,
  )
  // Copy definitions from the instance.
  engine.functions = self.functions
  engine.instructions = self.instructions
  // Reset twilight zone to the instance state for each glyph run.
  let tz = TtZone::{
    unscaled: Array::new(),
    original: self.twilight_original.copy(),
    points: self.twilight_points.copy(),
    flags: self.twilight_flags.copy(),
    contours: Array::from_fixed_array([self.twilight_points.length()]),
  }
  engine.graphics.twilight = tz
  engine.graphics.glyph = glyph_zone
  engine.program.set_glyph_code(glyph_code)
  match engine.run_program(TtProgram::Glyph, is_pedantic) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(engine.graphics.glyph)
}
