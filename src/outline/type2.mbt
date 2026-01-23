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
/// Type 2 charstring evaluation (path ops only; hints ignored).
///
/// Ported from `read-fonts` CFF/CFF2 charstring evaluator logic.

///|
fn type2_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn type2_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match type2_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
fn type2_read_i32_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    let b2 = view.at(offset + 2).to_int()
    let b3 = view.at(offset + 3).to_int()
    let u = (b0.reinterpret_as_uint() << 24) |
      (b1.reinterpret_as_uint() << 16) |
      (b2.reinterpret_as_uint() << 8) |
      b3.reinterpret_as_uint()
    Some(u.reinterpret_as_int())
  }
}

///|
fn type2_parse_int(data : BytesView, pos : Int, b0 : Int) -> (Int, Int)? {
  // Returns (value, new_pos).
  match b0 {
    28 =>
      match type2_read_i16_be(data, pos) {
        None => None
        Some(v) => Some((v, pos + 2))
      }
    32..=246 => Some((b0 - 139, pos))
    247..=250 =>
      if pos >= data.length() {
        None
      } else {
        let b1 = data.at(pos).to_int()
        Some(((b0 - 247) * 256 + b1 + 108, pos + 1))
      }
    251..=254 =>
      if pos >= data.length() {
        None
      } else {
        let b1 = data.at(pos).to_int()
        Some((-(b0 - 251) * 256 - b1 - 108, pos + 1))
      }
    _ => None
  }
}

///|
fn type2_subr_bias(count : Int) -> Int {
  if count < 1240 {
    107
  } else if count < 33900 {
    1131
  } else {
    32768
  }
}

///|
priv struct Type2Index {
  data : BytesView
  count : Int
  off_size : Int
  offsets_base : Int
  objects_base : Int
  bias : Int
}

///|
fn type2_index1_read(data : BytesView) -> Type2Index? {
  // CFF INDEX (count u16, offSize u8) with 1-based offsets.
  let count = match type2_read_u16_be(data, 0) {
    None => return None
    Some(v) => v
  }
  if count == 0 {
    Some(Type2Index::{
      data,
      count: 0,
      off_size: 0,
      offsets_base: 2,
      objects_base: 2,
      bias: type2_subr_bias(0),
    })
  } else {
    if 3 > data.length() {
      return None
    }
    let off_size = data.at(2).to_int()
    if off_size <= 0 || off_size > 4 {
      return None
    }
    let offsets_base = 3
    let objects_base = offsets_base + (count + 1) * off_size
    if objects_base > data.length() {
      return None
    }
    Some(Type2Index::{
      data,
      count,
      off_size,
      offsets_base,
      objects_base,
      bias: type2_subr_bias(count),
    })
  }
}

///|
fn type2_index2_read(data : BytesView) -> Type2Index? {
  // CFF2 INDEX (count u32, offSize u8) with 1-based offsets.
  if data.length() < 4 {
    return None
  }
  let count_u = match type2_read_i32_be(data, 0) {
    None => return None
    Some(v) => v
  }
  if count_u < 0 {
    return None
  }
  let count = count_u
  if count == 0 {
    Some(Type2Index::{
      data,
      count: 0,
      off_size: 0,
      offsets_base: 4,
      objects_base: 4,
      bias: type2_subr_bias(0),
    })
  } else {
    if data.length() < 5 {
      return None
    }
    let off_size = data.at(4).to_int()
    if off_size <= 0 || off_size > 4 {
      return None
    }
    let offsets_base = 5
    let objects_base = offsets_base + (count + 1) * off_size
    if objects_base > data.length() {
      return None
    }
    Some(Type2Index::{
      data,
      count,
      off_size,
      offsets_base,
      objects_base,
      bias: type2_subr_bias(count),
    })
  }
}

///|
fn type2_index_read_offset(ix : Type2Index, index : Int) -> Int? {
  if ix.count == 0 {
    if index == 0 {
      Some(0)
    } else {
      None
    }
  } else {
    if index < 0 || index > ix.count {
      return None
    }
    let pos = ix.offsets_base + index * ix.off_size
    if pos < 0 || pos + ix.off_size > ix.data.length() {
      return None
    }
    let mut v = 0
    for i in 0..<ix.off_size {
      v = (v << 8) | ix.data.at(pos + i).to_int()
    }
    // Offsets are 1-based.
    Some(v - 1)
  }
}

///|
fn type2_index_get(ix : Type2Index, index : Int) -> BytesView? {
  if index < 0 || index >= ix.count {
    return None
  }
  let start = match type2_index_read_offset(ix, index) {
    None => return None
    Some(v) => v
  }
  let end = match type2_index_read_offset(ix, index + 1) {
    None => return None
    Some(v) => v
  }
  let s = ix.objects_base + start
  let e = ix.objects_base + end
  if s < 0 || e < s || e > ix.data.length() {
    None
  } else {
    Some(ix.data.sub(start=s, end=e))
  }
}

///|
fn type2_index_subr(ix : Type2Index, subr_number : Int) -> BytesView? {
  let idx = subr_number + ix.bias
  type2_index_get(ix, idx)
}

///|
priv struct Type2Eval {
  global_subrs : Type2Index?
  local_subrs : Type2Index?
  out : Array[PathElement]
  mut is_open : Bool
  mut have_read_width : Bool
  mut stem_count : Int
  mut x : Int
  mut y : Int
  mut start_x : Int
  mut start_y : Int
  stack : Array[Int]
  mut stack_ix : Int
}

///|
fn Type2Eval::new(
  global_subrs : Type2Index?,
  local_subrs : Type2Index?,
) -> Type2Eval {
  Type2Eval::{
    global_subrs,
    local_subrs,
    out: Array::new(),
    is_open: false,
    have_read_width: false,
    stem_count: 0,
    x: 0,
    y: 0,
    start_x: 0,
    start_y: 0,
    stack: Array::new(),
    stack_ix: 0,
  }
}

///|
fn Type2Eval::reset_stack(self : Type2Eval) -> Unit {
  self.stack.clear()
  self.stack_ix = 0
}

///|
fn Type2Eval::coords_remaining(self : Type2Eval) -> Int {
  let len = self.stack.length()
  let ix = self.stack_ix
  if len < ix {
    0
  } else {
    len - ix
  }
}

///|
fn Type2Eval::close_path(self : Type2Eval) -> Unit {
  if self.is_open {
    if self.x != self.start_x || self.y != self.start_y {
      self.out.push(LineTo(self.start_x, self.start_y))
    }
    self.out.push(Close)
    self.is_open = false
  }
}

///|
priv enum Type2PointMode {
  DxDy
  XDy
  DxY
  DxInitialY
  DLargerCoordDist
  DxMaybeDy(Bool)
  MaybeDxDy(Bool)
}

///|
fn Type2Eval::emit_curves(
  self : Type2Eval,
  modes : ArrayView[Type2PointMode],
) -> Bool {
  let initial_x = self.x
  let initial_y = self.y
  let mut count = 0
  let mut cx0 = 0
  let mut cy0 = 0
  let mut cx1 = 0
  let mut cy1 = 0
  for mode in modes.iter() {
    let used = match mode {
      DxDy => {
        let dx = self.stack.at(self.stack_ix)
        let dy = self.stack.at(self.stack_ix + 1)
        self.x = self.x + dx
        self.y = self.y + dy
        2
      }
      XDy => {
        let dy = self.stack.at(self.stack_ix)
        self.y = self.y + dy
        1
      }
      DxY => {
        let dx = self.stack.at(self.stack_ix)
        self.x = self.x + dx
        1
      }
      DxInitialY => {
        let dx = self.stack.at(self.stack_ix)
        self.x = self.x + dx
        self.y = initial_y
        1
      }
      DLargerCoordDist => {
        let delta = self.stack.at(self.stack_ix)
        let dx = (self.x - initial_x).abs()
        let dy = (self.y - initial_y).abs()
        if dx > dy {
          self.x = self.x + delta
          self.y = initial_y
        } else {
          self.y = self.y + delta
          self.x = initial_x
        }
        1
      }
      DxMaybeDy(do_dy) => {
        let dx = self.stack.at(self.stack_ix)
        self.x = self.x + dx
        if do_dy {
          let dy = self.stack.at(self.stack_ix + 1)
          self.y = self.y + dy
          2
        } else {
          1
        }
      }
      MaybeDxDy(do_dx) => {
        let dy = self.stack.at(self.stack_ix)
        self.y = self.y + dy
        if do_dx {
          let dx = self.stack.at(self.stack_ix + 1)
          self.x = self.x + dx
          2
        } else {
          1
        }
      }
    }
    self.stack_ix = self.stack_ix + used
    if count == 2 {
      self.out.push(CurveTo(cx0, cy0, cx1, cy1, self.x, self.y))
      count = 0
    } else if count == 0 {
      cx0 = self.x
      cy0 = self.y
      count = 1
    } else {
      cx1 = self.x
      cy1 = self.y
      count = 2
    }
  }
  true
}

///|
fn Type2Eval::read_operator(
  data : BytesView,
  pos : Int,
  b0 : Int,
) -> (Int, Int)? {
  // Returns (operator_code, new_pos). For escaped operators, returns 1200+op2.
  if b0 == 12 {
    if pos >= data.length() {
      None
    } else {
      let b1 = data.at(pos).to_int()
      Some((1200 + b1, pos + 1))
    }
  } else {
    Some((b0, pos))
  }
}

///|
fn Type2Eval::eval(self : Type2Eval, data : BytesView, depth : Int) -> Bool {
  if depth > 10 {
    return false
  }
  let mut pos = 0
  while pos < data.length() {
    let b0 = data.at(pos).to_int()
    pos = pos + 1
    if b0 == 28 || (b0 >= 32 && b0 <= 254) {
      match type2_parse_int(data, pos, b0) {
        None => return false
        Some((v, p)) => {
          self.stack.push(v)
          pos = p
        }
      }
      continue
    }
    if b0 == 255 {
      match type2_read_i32_be(data, pos) {
        None => return false
        Some(bits) => {
          // 16.16 fixed point.
          self.stack.push((bits.to_double() / 65536.0).round().to_int())
          pos = pos + 4
        }
      }
      continue
    }
    match Type2Eval::read_operator(data, pos, b0) {
      None => return false
      Some((op, p)) => {
        pos = p
        match Type2Eval::eval_operator(self, data, op, pos, depth) {
          None => return false
          Some((cont, new_pos)) => {
            pos = new_pos
            if !cont {
              break
            }
          }
        }
      }
    }
  }
  true
}

///|
fn Type2Eval::eval_operator(
  self : Type2Eval,
  data : BytesView,
  op : Int,
  pos : Int,
  depth : Int,
) -> (Bool, Int)? {
  // Returns (continue, new_pos).
  let mut new_pos = pos
  // Two-byte ops are represented as 1200+op2.
  match op {
    // return
    11 => Some((false, new_pos))
    // endchar
    14 => {
      if self.stack.length() != 0 && !self.have_read_width {
        self.have_read_width = true
        self.stack.clear()
      }
      Type2Eval::close_path(self)
      self.reset_stack()
      Some((false, new_pos))
    }
    // hstem/vstem/hstemhm/vstemhm: ignore but consume hints (and possible width).
    1 | 3 | 18 | 23 => {
      let mut i = 0
      if (self.stack.length() & 1) != 0 && !self.have_read_width {
        self.have_read_width = true
        i = 1
      }
      let len = self.stack.length() - i
      self.stem_count = self.stem_count + len / 2
      self.reset_stack()
      Some((true, new_pos))
    }
    // hintmask/cntrmask
    19 | 20 => {
      let mut i = 0
      if (self.stack.length() & 1) != 0 && !self.have_read_width {
        self.have_read_width = true
        i = 1
      }
      let len = self.stack.length() - i
      self.stem_count = self.stem_count + len / 2
      let mask_bytes = (self.stem_count + 7) / 8
      if new_pos + mask_bytes > data.length() {
        return None
      }
      new_pos = new_pos + mask_bytes
      self.reset_stack()
      Some((true, new_pos))
    }
    // rmoveto
    21 => {
      let mut i = 0
      if self.stack.length() == 3 && !self.have_read_width {
        self.have_read_width = true
        i = 1
      }
      Type2Eval::close_path(self)
      self.is_open = true
      let dx = self.stack.at(i)
      let dy = self.stack.at(i + 1)
      self.x = self.x + dx
      self.y = self.y + dy
      self.start_x = self.x
      self.start_y = self.y
      self.out.push(MoveTo(self.x, self.y))
      self.reset_stack()
      Some((true, new_pos))
    }
    // hmoveto/vmoveto
    22 | 4 => {
      let mut i = 0
      if self.stack.length() == 2 && !self.have_read_width {
        self.have_read_width = true
        i = 1
      }
      Type2Eval::close_path(self)
      self.is_open = true
      let delta = self.stack.at(i)
      if op == 22 {
        self.x = self.x + delta
      } else {
        self.y = self.y + delta
      }
      self.start_x = self.x
      self.start_y = self.y
      self.out.push(MoveTo(self.x, self.y))
      self.reset_stack()
      Some((true, new_pos))
    }
    // rlineto
    5 => {
      let mut i = 0
      while i < self.stack.length() {
        let dx = self.stack.at(i)
        let dy = self.stack.at(i + 1)
        self.x = self.x + dx
        self.y = self.y + dy
        self.out.push(LineTo(self.x, self.y))
        i = i + 2
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // hlineto/vlineto
    6 | 7 => {
      let mut is_x = op == 6
      for i in 0..<self.stack.length() {
        let delta = self.stack.at(i)
        if is_x {
          self.x = self.x + delta
        } else {
          self.y = self.y + delta
        }
        is_x = !is_x
        self.out.push(LineTo(self.x, self.y))
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // hhcurveto
    27 => {
      if (self.stack.length() & 1) != 0 {
        self.y = self.y + self.stack.at(0)
        self.stack_ix = 1
      }
      while Type2Eval::coords_remaining(self) >= 4 {
        let modes = Array::from_fixed_array([DxY, DxDy, DxY])
        if !Type2Eval::emit_curves(self, modes.op_as_view()) {
          return None
        }
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // hvcurveto/vhcurveto
    31 | 30 => {
      let count1 = self.stack.length()
      let count = count1 & (2 |> Int::lnot)
      let mut is_horizontal = op == 31
      self.stack_ix = count1 - count
      while self.stack_ix < count {
        let do_last_delta = count - self.stack_ix == 5
        if is_horizontal {
          let modes = Array::from_fixed_array([
            DxY,
            DxDy,
            MaybeDxDy(do_last_delta),
          ])
          if !Type2Eval::emit_curves(self, modes.op_as_view()) {
            return None
          }
        } else {
          let modes = Array::from_fixed_array([
            XDy,
            DxDy,
            DxMaybeDy(do_last_delta),
          ])
          if !Type2Eval::emit_curves(self, modes.op_as_view()) {
            return None
          }
        }
        is_horizontal = !is_horizontal
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // rrcurveto / rcurveline
    8 | 24 => {
      while Type2Eval::coords_remaining(self) >= 6 {
        let modes = Array::from_fixed_array([DxDy, DxDy, DxDy])
        if !Type2Eval::emit_curves(self, modes.op_as_view()) {
          return None
        }
      }
      if op == 24 {
        let dx = self.stack.at(self.stack_ix)
        let dy = self.stack.at(self.stack_ix + 1)
        self.x = self.x + dx
        self.y = self.y + dy
        self.out.push(LineTo(self.x, self.y))
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // rlinecurve
    25 => {
      while Type2Eval::coords_remaining(self) > 6 {
        let dx = self.stack.at(self.stack_ix)
        let dy = self.stack.at(self.stack_ix + 1)
        self.x = self.x + dx
        self.y = self.y + dy
        self.out.push(LineTo(self.x, self.y))
        self.stack_ix = self.stack_ix + 2
      }
      let modes = Array::from_fixed_array([DxDy, DxDy, DxDy])
      if !Type2Eval::emit_curves(self, modes.op_as_view()) {
        return None
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // vvcurveto
    26 => {
      if (self.stack.length() & 1) != 0 {
        self.x = self.x + self.stack.at(0)
        self.stack_ix = 1
      }
      while Type2Eval::coords_remaining(self) > 0 {
        let modes = Array::from_fixed_array([XDy, DxDy, XDy])
        if !Type2Eval::emit_curves(self, modes.op_as_view()) {
          return None
        }
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // flex/hflex/hflex1/flex1 (12 35..37, 12 34)
    1234 | 1235 | 1236 | 1237 => {
      let modes = match op {
        1235 => Array::from_fixed_array([DxDy, DxDy, DxDy, DxDy, DxDy, DxDy])
        1234 => Array::from_fixed_array([DxY, DxDy, DxY, DxY, DxInitialY, DxY])
        1236 =>
          Array::from_fixed_array([DxDy, DxDy, DxY, DxY, DxDy, DxInitialY])
        _ =>
          Array::from_fixed_array([
            DxDy,
            DxDy,
            DxDy,
            DxDy,
            DxDy,
            DLargerCoordDist,
          ])
      }
      if !Type2Eval::emit_curves(self, modes.op_as_view()) {
        return None
      }
      self.reset_stack()
      Some((true, new_pos))
    }
    // callsubr / callgsubr
    10 | 29 => {
      if self.stack.length() <= 0 {
        return None
      }
      let subr_number = self.stack.at(self.stack.length() - 1)
      self.stack.pop() |> ignore
      let ix = if op == 10 { self.local_subrs } else { self.global_subrs }
      match ix {
        None => None
        Some(index) =>
          match type2_index_subr(index, subr_number) {
            None => None
            Some(subr) =>
              if !Type2Eval::eval(self, subr, depth + 1) {
                None
              } else {
                Some((true, new_pos))
              }
          }
      }
    }
    // vsindex/blend are not supported in this MVP.
    15 | 16 => None
    _ => Some((true, new_pos))
  }
}

///|
fn type2_path(
  charstring : BytesView,
  global_subrs : Type2Index?,
  local_subrs : Type2Index?,
) -> Array[PathElement]? {
  let eval = Type2Eval::new(global_subrs, local_subrs)
  if Type2Eval::eval(eval, charstring, 0) {
    Some(eval.out)
  } else {
    None
  }
}
