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
/// Storage/CVT + delta instruction implementations for the TT engine.
///
/// Ported from `fontations/skrifa/src/outline/glyf/hint/engine/{storage.rs,cvt.rs,delta.rs}`
/// (Apache-2.0 OR MIT).
fn tt_scale_funits_to_26_6(value : Int, scale_bits : Int) -> Int {
  // value (font units) * scale_bits (16.16, includes *64) => 26.6
  let v = value.to_int64() * scale_bits.to_int64()
  let adj = 0x8000 - (if v < 0 { 1 } else { 0 })
  ((v + adj.to_int64()) >> 16).to_int()
}

///|
fn TtEngine::op_rs(self : TtEngine) -> Result[Unit, HintError] {
  let loc = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if loc < 0 || loc >= self.storage.length() {
    if self.graphics.is_pedantic {
      Err(HintError::InvalidStorageIndex(loc))
    } else {
      self.value_stack.push(0)
    }
  } else {
    self.value_stack.push(self.storage.at(loc))
  }
}

///|
fn TtEngine::op_ws(self : TtEngine) -> Result[Unit, HintError] {
  let value = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let loc = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if loc < 0 || loc >= self.storage.length() {
    if self.graphics.is_pedantic {
      Err(HintError::InvalidStorageIndex(loc))
    } else {
      Ok(())
    }
  } else {
    self.storage.set(loc, value)
    Ok(())
  }
}

///|
fn TtEngine::op_wcvtp(self : TtEngine) -> Result[Unit, HintError] {
  let value = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let loc = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if loc < 0 || loc >= self.cvt.length() {
    if self.graphics.is_pedantic {
      Err(HintError::InvalidCvtIndex(loc))
    } else {
      Ok(())
    }
  } else {
    self.cvt.set(loc, value)
    Ok(())
  }
}

///|
fn TtEngine::op_wcvtf(self : TtEngine) -> Result[Unit, HintError] {
  let value_funits = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let loc = match self.value_stack.pop_usize() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if loc < 0 || loc >= self.cvt.length() {
    if self.graphics.is_pedantic {
      Err(HintError::InvalidCvtIndex(loc))
    } else {
      Ok(())
    }
  } else {
    let value = tt_scale_funits_to_26_6(
      value_funits,
      self.graphics.retained.scale,
    )
    self.cvt.set(loc, value)
    Ok(())
  }
}

///|
fn TtEngine::op_rcvt(self : TtEngine) -> Result[Unit, HintError] {
  let loc = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if loc < 0 || loc >= self.cvt.length() {
    if self.graphics.is_pedantic {
      Err(HintError::InvalidCvtIndex(loc))
    } else {
      self.value_stack.push(0)
    }
  } else {
    self.value_stack.push(self.cvt.at(loc))
  }
}

///|
fn tt_delta_adjust(gs : TtGraphicsState, b0 : Int) -> Int {
  // See FreeType packing scheme.
  let mut b = (b0 & 0xF) - 8
  if b >= 0 {
    b = b + 1
  }
  b * (1 << (6 - gs.retained.delta_shift))
}

///|
fn TtEngine::op_deltap(
  self : TtEngine,
  opcode : Int,
) -> Result[Unit, HintError] {
  let ppem_u = self.graphics.retained.ppem.reinterpret_as_uint()
  let point_count = self.graphics.zp0_zone().points.length()
  let n0 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if n0 < 0 {
    if self.graphics.is_pedantic {
      return Err(HintError::InvalidStackValue(n0))
    } else {
      return Ok(())
    }
  }
  // Each entry consumes 2 stack values.
  let n = n0.min(self.value_stack.length() / 2)
  let bias0 : UInt = (match opcode {
    0x71 => 16
    0x72 => 32
    _ => 0
  }).reinterpret_as_uint()
  let bias = bias0 + self.graphics.retained.delta_base.reinterpret_as_uint()
  let back_compat = self.graphics.backward_compatibility
  let did_iup = self.graphics.did_iup_x && self.graphics.did_iup_y
  for _ in 0..<n {
    let point_ix = match self.value_stack.pop_usize() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let b0 = match self.value_stack.pop() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    if point_ix < 0 || point_ix >= point_count {
      continue
    }
    let c : UInt = ((b0.reinterpret_as_uint() & 0xF0) >> 4) + bias
    if ppem_u == c {
      let adj = tt_delta_adjust(self.graphics, b0)
      if back_compat {
        let touched_y = match
          self.graphics.zp0_zone().is_touched(point_ix, TtAxis::Y) {
          Err(e) => return Err(e)
          Ok(v) => v
        }
        if !did_iup &&
          (
            (self.graphics.is_composite && self.graphics.freedom_vector.y != 0) ||
            touched_y
          ) {
          match self.graphics.move_point(self.graphics.zp0, point_ix, adj) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        }
      } else {
        match self.graphics.move_point(self.graphics.zp0, point_ix, adj) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
    }
  }
  Ok(())
}

///|
fn TtEngine::op_deltac(
  self : TtEngine,
  opcode : Int,
) -> Result[Unit, HintError] {
  let ppem_u = self.graphics.retained.ppem.reinterpret_as_uint()
  let n0 = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if n0 < 0 {
    if self.graphics.is_pedantic {
      return Err(HintError::InvalidStackValue(n0))
    } else {
      return Ok(())
    }
  }
  let n = n0.min(self.value_stack.length() / 2)
  let bias0 : UInt = (match opcode {
    0x74 => 16
    0x75 => 32
    _ => 0
  }).reinterpret_as_uint()
  let bias = bias0 + self.graphics.retained.delta_base.reinterpret_as_uint()
  for _ in 0..<n {
    let cvt_ix = match self.value_stack.pop_usize() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let b0 = match self.value_stack.pop() {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    let c : UInt = ((b0.reinterpret_as_uint() & 0xF0) >> 4) + bias
    if ppem_u == c {
      if cvt_ix < 0 || cvt_ix >= self.cvt.length() {
        if self.graphics.is_pedantic {
          return Err(HintError::InvalidCvtIndex(cvt_ix))
        } else {
          continue
        }
      }
      let adj = tt_delta_adjust(self.graphics, b0)
      self.cvt.set(cvt_ix, self.cvt.at(cvt_ix) + adj)
    }
  }
  Ok(())
}

///|
fn TtEngine::op_sdb(self : TtEngine) -> Result[Unit, HintError] {
  let b = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.retained.delta_base = b
  Ok(())
}

///|
fn TtEngine::op_sds(self : TtEngine) -> Result[Unit, HintError] {
  let s = match self.value_stack.pop() {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  self.graphics.retained.delta_shift = s
  Ok(())
}
