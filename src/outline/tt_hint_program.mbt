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
/// Program state for the TrueType interpreter.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/program.rs`
/// (Apache-2.0 OR MIT).
priv struct TtCallFrame {
  decoder : TtDecoder
  return_pc : Int
  kind : TtCallFrameKind
}

///|
priv enum TtCallFrameKind {
  ReturnOnly
  LoopCall(BytesView, Int)
}

///|
priv struct TtProgramState {
  font : BytesView
  prep : BytesView
  mut glyph : BytesView
  mut current : TtProgram
  mut decoder : TtDecoder
  call_stack : Array[TtCallFrame]
  max_call_depth : Int
}

///|
fn TtProgramState::new(
  font : BytesView,
  prep : BytesView,
  glyph : BytesView,
  current : TtProgram,
  max_call_depth : Int,
) -> TtProgramState {
  let code = match current {
    TtProgram::Font => font
    TtProgram::ControlValue => prep
    TtProgram::Glyph => glyph
  }
  TtProgramState::{
    font,
    prep,
    glyph,
    current,
    decoder: TtDecoder::new(code),
    call_stack: Array::new(),
    max_call_depth,
  }
}

///|
fn TtProgramState::reset(self : TtProgramState, program : TtProgram) -> Unit {
  self.current = program
  let code = match program {
    TtProgram::Font => self.font
    TtProgram::ControlValue => self.prep
    TtProgram::Glyph => self.glyph
  }
  self.decoder = TtDecoder::new(code)
  self.call_stack.clear()
}

///|
fn TtProgramState::set_glyph_code(
  self : TtProgramState,
  glyph : BytesView,
) -> Unit {
  self.glyph = glyph
}

///|
fn TtProgramState::push_frame(
  self : TtProgramState,
  callee : BytesView,
  start_pc : Int,
  return_pc : Int,
) -> Result[Unit, HintError] {
  if self.call_stack.length() >= self.max_call_depth {
    return Err(HintError::CallStackOverflow)
  }
  // Save the caller decoder so we can resume there.
  self.call_stack.push(TtCallFrame::{
    decoder: self.decoder,
    return_pc,
    kind: TtCallFrameKind::ReturnOnly,
  })
  // Switch current decoder to callee.
  self.decoder = TtDecoder::{ code: callee, pc: start_pc }
  Ok(())
}

///|
fn TtProgramState::push_loopcall_frame(
  self : TtProgramState,
  callee : BytesView,
  remaining : Int,
  start_pc : Int,
  return_pc : Int,
) -> Result[Unit, HintError] {
  if self.call_stack.length() >= self.max_call_depth {
    return Err(HintError::CallStackOverflow)
  }
  self.call_stack.push(TtCallFrame::{
    decoder: self.decoder,
    return_pc,
    kind: TtCallFrameKind::LoopCall(callee, remaining),
  })
  self.decoder = TtDecoder::{ code: callee, pc: start_pc }
  Ok(())
}

///|
fn TtProgramState::pop_frame(self : TtProgramState) -> Result[Unit, HintError] {
  if self.call_stack.is_empty() {
    return Err(HintError::CallStackUnderflow)
  }
  let frame = self.call_stack.pop().unwrap()
  match frame.kind {
    TtCallFrameKind::ReturnOnly => {
      // Restore previous decoder and continue after return_pc.
      self.decoder = frame.decoder
      self.decoder.pc = frame.return_pc
      Ok(())
    }
    TtCallFrameKind::LoopCall(code, remaining) =>
      if remaining > 0 {
        // Re-run the callee and keep the loopcall frame, decrementing the counter.
        self.call_stack.push(TtCallFrame::{
          decoder: frame.decoder,
          return_pc: frame.return_pc,
          kind: TtCallFrameKind::LoopCall(code, remaining - 1),
        })
        self.decoder = TtDecoder::{ code, pc: 0 }
        Ok(())
      } else {
        self.decoder = frame.decoder
        self.decoder.pc = frame.return_pc
        Ok(())
      }
  }
}
