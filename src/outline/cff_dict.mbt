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
/// Minimal CFF/CFF2 DICT parsing helpers (only operators needed for outlines).

///|
priv struct CffDictNum {
  value : Double
  // Dynamic scaling exponent for FontMatrix parsing (range [-9..0]).
  scaling : Int
}

///|
priv struct CffDictInfo {
  mut charstrings_offset : Int?
  mut var_store_offset : Int?
  mut fd_array_offset : Int?
  mut fd_select_offset : Int?
  mut private_size : Int?
  mut private_offset : Int?
  mut subrs_offset : Int?
  mut font_matrix : CffMatrix?
  mut font_matrix_upem : Int?
}

///|
fn cff_dict_read_i32_be(view : BytesView, offset : Int) -> Int? {
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

///|
fn cff_dict_parse(data : BytesView) -> CffDictInfo {
  let info = CffDictInfo::{
    charstrings_offset: None,
    var_store_offset: None,
    fd_array_offset: None,
    fd_select_offset: None,
    private_size: None,
    private_offset: None,
    subrs_offset: None,
    font_matrix: None,
    font_matrix_upem: None,
  }
  let stack : Array[CffDictNum] = Array::new()
  let mut pos = 0
  while pos < data.length() {
    let b0 = data.at(pos).to_int()
    pos = pos + 1
    if b0 == 28 || b0 == 29 || b0 == 30 || b0 == 255 || (b0 >= 32 && b0 <= 254) {
      match cff_dict_parse_number_scaled(data, pos, b0) {
        None => break
        Some((v, scaling, p)) => {
          stack.push(CffDictNum::{ value: v, scaling })
          pos = p
        }
      }
      continue
    }
    let op = if b0 == 12 {
      if pos >= data.length() {
        break
      }
      let b1 = data.at(pos).to_int()
      pos = pos + 1
      1200 + b1
    } else {
      b0
    }
    match op {
      // CharStrings offset
      17 =>
        if stack.length() >= 1 {
          info.charstrings_offset = cff_dict_number_to_int(
            stack.at(stack.length() - 1).value,
          )
        }
      // CFF2 VarStore offset (ItemVariationStore)
      24 =>
        if stack.length() >= 1 {
          info.var_store_offset = cff_dict_number_to_int(
            stack.at(stack.length() - 1).value,
          )
        }
      // FDArray offset (Top DICT, escaped op 12 36)
      1236 =>
        if stack.length() >= 1 {
          info.fd_array_offset = cff_dict_number_to_int(
            stack.at(stack.length() - 1).value,
          )
        }
      // FDSelect offset (Top DICT, escaped op 12 37)
      1237 =>
        if stack.length() >= 1 {
          info.fd_select_offset = cff_dict_number_to_int(
            stack.at(stack.length() - 1).value,
          )
        }
      // Private DICT range: size, offset
      18 =>
        if stack.length() >= 2 {
          info.private_size = cff_dict_number_to_int(stack.at(0).value)
          info.private_offset = cff_dict_number_to_int(stack.at(1).value)
        }
      // Subrs offset (within Private DICT)
      19 =>
        if stack.length() >= 1 {
          info.subrs_offset = cff_dict_number_to_int(
            stack.at(stack.length() - 1).value,
          )
        }
      // FontMatrix (escaped op 12 7)
      1207 =>
        if stack.length() >= 6 {
          let mut max_scaling = -2147483648
          for i in 0..<6 {
            let n = stack.at(i)
            if n.value != 0.0 {
              max_scaling = max_scaling.max(n.scaling)
            }
          }
          if max_scaling >= -9 && max_scaling <= 0 {
            let upem = cff_dict_pow10((-max_scaling).max(0))
            let scale = upem.to_double()
            let xx = CffFixed::from_f64(stack.at(0).value * scale)
            let yx = CffFixed::from_f64(stack.at(1).value * scale)
            let xy = CffFixed::from_f64(stack.at(2).value * scale)
            let yy = CffFixed::from_f64(stack.at(3).value * scale)
            let dx = CffFixed::from_f64(stack.at(4).value * scale)
            let dy = CffFixed::from_f64(stack.at(5).value * scale)
            info.font_matrix = Some(CffMatrix::{ xx, yx, xy, yy, dx, dy })
            info.font_matrix_upem = Some(upem)
          }
        }
      _ => ()
    }
    stack.clear()
  }
  info
}

///|
fn cff_dict_number_to_int(v : Double) -> Int? {
  let r = v.round()
  if (v - r).abs() <= 0.000001 {
    Some(r.to_int())
  } else {
    None
  }
}

///|
fn cff_dict_pow10(exp : Int) -> Int {
  let mut v = 1
  for _ in 0..<exp {
    v = v * 10
  }
  v
}

///|
fn cff_dict_parse_real_scaled(
  data : BytesView,
  pos : Int,
) -> (Double, Int, Int)? {
  // Returns (value, scaling, new_pos). BCD real number per CFF spec.
  //
  // Note: We only need enough of FreeType's dynamic scaling behavior for
  // FontMatrix parsing; we approximate it by clamping fractional digits to 6,
  // which matches read-fonts/fontations for the fonts in our parity suite.
  let mut i = pos
  let mut sign = 1.0
  let mut int_part = 0.0
  let mut frac_part = 0.0
  let mut frac_div = 1.0
  let mut have_dot = false
  let mut frac_len = 0
  let mut in_exp = false
  let mut exp_sign = 1
  let mut exp_val = 0
  let mut done = false
  while i < data.length() && !done {
    let b = data.at(i).to_int()
    i = i + 1
    let nibs = Array::from_fixed_array([b >> 4, b & 0x0F])
    for n in nibs.iter() {
      match n {
        0..=9 =>
          if in_exp {
            exp_val = exp_val * 10 + n
          } else if have_dot {
            frac_part = frac_part * 10.0 + n.to_double()
            frac_div = frac_div * 10.0
            frac_len = frac_len + 1
          } else {
            int_part = int_part * 10.0 + n.to_double()
          }
        10 => have_dot = true
        11 => in_exp = true
        12 => {
          in_exp = true
          exp_sign = -1
        }
        14 => if !in_exp && int_part == 0.0 && frac_part == 0.0 { sign = -1.0 }
        15 => {
          done = true
          break
        }
        _ => ()
      }
    }
  }
  let mut v = sign * (int_part + frac_part / frac_div)
  if exp_val != 0 {
    let e = exp_sign * exp_val
    let mut p = 1.0
    let mut j = 0
    let abs_e = if e < 0 { -e } else { e }
    while j < abs_e {
      p = p * 10.0
      j = j + 1
    }
    if e < 0 {
      v = v / p
    } else {
      v = v * p
    }
  }
  let scaling = if frac_len <= 0 { 0 } else { -frac_len.min(6) }
  Some((v, scaling, i))
}

///|
fn cff_dict_parse_real(data : BytesView, pos : Int) -> (Double, Int)? {
  // Returns (value, new_pos). BCD real number per CFF spec.
  let mut i = pos
  let mut sign = 1.0
  let mut int_part = 0.0
  let mut frac_part = 0.0
  let mut frac_div = 1.0
  let mut have_dot = false
  let mut in_exp = false
  let mut exp_sign = 1
  let mut exp_val = 0
  let mut done = false
  while i < data.length() && !done {
    let b = data.at(i).to_int()
    i = i + 1
    let nibs = Array::from_fixed_array([b >> 4, b & 0x0F])
    for n in nibs.iter() {
      match n {
        0..=9 =>
          if in_exp {
            exp_val = exp_val * 10 + n
          } else if have_dot {
            frac_part = frac_part * 10.0 + n.to_double()
            frac_div = frac_div * 10.0
          } else {
            int_part = int_part * 10.0 + n.to_double()
          }
        10 => have_dot = true
        11 => in_exp = true
        12 => {
          in_exp = true
          exp_sign = -1
        }
        14 => if !in_exp && int_part == 0.0 && frac_part == 0.0 { sign = -1.0 }
        15 => {
          done = true
          break
        }
        _ => ()
      }
    }
  }
  let mut v = sign * (int_part + frac_part / frac_div)
  if exp_val != 0 {
    let e = exp_sign * exp_val
    let mut p = 1.0
    let mut j = 0
    let abs_e = if e < 0 { -e } else { e }
    while j < abs_e {
      p = p * 10.0
      j = j + 1
    }
    if e < 0 {
      v = v / p
    } else {
      v = v * p
    }
  }
  Some((v, i))
}

///|
fn cff_dict_parse_number(
  data : BytesView,
  pos : Int,
  b0 : Int,
) -> (Double, Int)? {
  match b0 {
    28 =>
      match type2_read_i16_be(data, pos) {
        None => None
        Some(v) => Some((v.to_double(), pos + 2))
      }
    29 =>
      match cff_dict_read_i32_be(data, pos) {
        None => None
        Some(v) => Some((v.to_double(), pos + 4))
      }
    30 => cff_dict_parse_real(data, pos)
    // 16.16 fixed point (CFF2 dict may use this form).
    255 =>
      match type2_read_i32_be(data, pos) {
        None => None
        Some(bits) => Some((bits.to_double() / 65536.0, pos + 4))
      }
    32..=246 => Some(((b0 - 139).to_double(), pos))
    247..=250 =>
      if pos >= data.length() {
        None
      } else {
        let b1 = data.at(pos).to_int()
        Some((((b0 - 247) * 256 + b1 + 108).to_double(), pos + 1))
      }
    251..=254 =>
      if pos >= data.length() {
        None
      } else {
        let b1 = data.at(pos).to_int()
        Some(((-(b0 - 251) * 256 - b1 - 108).to_double(), pos + 1))
      }
    _ => None
  }
}

///|
fn cff_dict_parse_number_scaled(
  data : BytesView,
  pos : Int,
  b0 : Int,
) -> (Double, Int, Int)? {
  match b0 {
    30 => cff_dict_parse_real_scaled(data, pos)
    _ =>
      match cff_dict_parse_number(data, pos, b0) {
        None => None
        Some((v, p)) => Some((v, 0, p))
      }
  }
}

///|
priv struct CffPrivateDictHintInfo {
  hint_params : HintParams
  mut subrs_offset : Int?
  mut store_index : Int
}

///|
fn CffPrivateDictHintInfo::default() -> CffPrivateDictHintInfo {
  CffPrivateDictHintInfo::{
    hint_params: HintParams::default(),
    subrs_offset: None,
    store_index: 0,
  }
}

///|
fn cff_dict_stack_to_fixed(values : Array[Double]) -> Array[CffFixed] {
  let out : Array[CffFixed] = Array::new()
  for v in values.iter() {
    out.push(CffFixed::from_f64(v))
  }
  out
}

///|
fn cff_dict_stack_apply_delta_prefix_sum(stack : Array[Double]) -> Unit {
  if stack.length() <= 1 {
    return
  }
  let mut sum = 0.0
  for i in 0..<stack.length() {
    sum = sum + stack.at(i)
    stack.set(i, sum)
  }
}

///|
fn cff_dict_stack_apply_blend(
  stack : Array[Double],
  blend_state : Type2BlendState,
) -> Bool {
  if stack.length() <= 0 {
    return false
  }
  let n = match type2_number_to_int(stack.at(stack.length() - 1)) {
    None => return false
    Some(v) => v
  }
  stack.pop() |> ignore
  if n < 0 {
    return false
  }
  let region_count = Type2BlendState::region_count(blend_state)
  let operand_count = n * (region_count + 1)
  if operand_count < 0 || stack.length() < operand_count {
    return false
  }
  let start = stack.length() - operand_count
  let values_start = start
  let deltas_start = start + n
  for region_ix in 0..<region_count {
    let scalar = blend_state.scalars.at(region_ix)
    if scalar == 0.0 {
      continue
    }
    for value_ix in 0..<n {
      let delta_ix = deltas_start + value_ix * region_count + region_ix
      let v_ix = values_start + value_ix
      stack.set(v_ix, stack.at(v_ix) + stack.at(delta_ix) * scalar)
    }
  }
  let new_len = start + n
  while stack.length() > new_len {
    stack.pop() |> ignore
  }
  true
}

///|
fn cff_private_dict_hint_info(
  private_dict : BytesView,
  blend_state : Type2BlendState?,
) -> CffPrivateDictHintInfo {
  let info = CffPrivateDictHintInfo::default()
  let stack : Array[Double] = Array::new()
  let mut pos = 0
  while pos < private_dict.length() {
    let b0 = private_dict.at(pos).to_int()
    pos = pos + 1
    if b0 == 28 || b0 == 29 || b0 == 30 || b0 == 255 || (b0 >= 32 && b0 <= 254) {
      match cff_dict_parse_number(private_dict, pos, b0) {
        None => break
        Some((v, p)) => {
          stack.push(v)
          pos = p
        }
      }
      continue
    }
    let op = if b0 == 12 {
      if pos >= private_dict.length() {
        break
      }
      let b1 = private_dict.at(pos).to_int()
      pos = pos + 1
      1200 + b1
    } else {
      b0
    }
    match op {
      6 => {
        cff_dict_stack_apply_delta_prefix_sum(stack)
        info.hint_params.blues = CffBlues::new(
          cff_dict_stack_to_fixed(stack).op_as_view(),
        )
      }
      7 => {
        cff_dict_stack_apply_delta_prefix_sum(stack)
        info.hint_params.other_blues = CffBlues::new(
          cff_dict_stack_to_fixed(stack).op_as_view(),
        )
      }
      8 => {
        cff_dict_stack_apply_delta_prefix_sum(stack)
        info.hint_params.family_blues = CffBlues::new(
          cff_dict_stack_to_fixed(stack).op_as_view(),
        )
      }
      9 => {
        cff_dict_stack_apply_delta_prefix_sum(stack)
        info.hint_params.family_other_blues = CffBlues::new(
          cff_dict_stack_to_fixed(stack).op_as_view(),
        )
      }
      // BlueScale/Shift/Fuzz/LanguageGroup (escaped opcodes 12 9.. etc).
      1209 =>
        if stack.length() > 0 {
          info.hint_params.blue_scale = CffFixed::from_f64(
            stack.at(stack.length() - 1),
          )
        }
      1210 =>
        if stack.length() > 0 {
          info.hint_params.blue_shift = CffFixed::from_f64(
            stack.at(stack.length() - 1),
          )
        }
      1211 =>
        if stack.length() > 0 {
          info.hint_params.blue_fuzz = CffFixed::from_f64(
            stack.at(stack.length() - 1),
          )
        }
      1217 =>
        if stack.length() > 0 {
          match cff_dict_number_to_int(stack.at(stack.length() - 1)) {
            None => ()
            Some(v) => info.hint_params.language_group = v
          }
        }
      // Subrs offset (within Private DICT)
      19 =>
        if stack.length() > 0 {
          match cff_dict_number_to_int(stack.at(stack.length() - 1)) {
            None => ()
            Some(v) => info.subrs_offset = Some(v)
          }
        }
      // VariationStoreIndex (Private DICT)
      22 =>
        if stack.length() > 0 {
          match cff_dict_number_to_int(stack.at(stack.length() - 1)) {
            None => ()
            Some(v) => {
              info.store_index = v
              match blend_state {
                None => ()
                Some(bs) => Type2BlendState::set_store_index(bs, v) |> ignore
              }
            }
          }
        }
      // Blend (Private DICT): applies blending to the current operand stack
      // and leaves the blended values for the next operator.
      23 =>
        match blend_state {
          None => ()
          Some(bs) => cff_dict_stack_apply_blend(stack, bs) |> ignore
        }
      _ => ()
    }
    // Blend is a stack transformer; other operators consume the stack.
    if op != 23 {
      stack.clear()
    }
  }
  info
}
