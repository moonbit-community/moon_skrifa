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
/// gvar support for glyf outlines (MVP: simple glyph deltas + IUP interpolation).
///
/// Ported from `fontations/skrifa/src/outline/glyf/deltas.rs` and related
/// gvar parsing logic (Apache-2.0 OR MIT).
const TAG_GVAR : UInt = 0x67766172 // "gvar"

///|
fn gvar_read_u8(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset >= view.length() {
    None
  } else {
    Some(view.at(offset).to_int())
  }
}

///|
fn gvar_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn gvar_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match gvar_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
fn gvar_read_u32_be_int(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    let b2 = view.at(offset + 2).to_int()
    let b3 = view.at(offset + 3).to_int()
    Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
}

///|
priv struct GvarCtx {
  gvar : BytesView
  axis_count : Int
  shared_tuple_count : Int
  shared_tuples_off : Int
  glyph_count : Int
  flags : Int
  data_array_off : Int
}

///|
fn gvar_ctx(font : @moon_skrifa.FontRef) -> GvarCtx? {
  let gvar = match font.table(TAG_GVAR) {
    None => return None
    Some(v) => v
  }
  // gvar header is 20 bytes.
  if gvar.length() < 20 {
    return None
  }
  let axis_count = gvar_read_u16_be(gvar, 4).unwrap_or(-1)
  let shared_tuple_count = gvar_read_u16_be(gvar, 6).unwrap_or(-1)
  let shared_tuples_off = gvar_read_u32_be_int(gvar, 8).unwrap_or(-1)
  let glyph_count = gvar_read_u16_be(gvar, 12).unwrap_or(-1)
  let flags = gvar_read_u16_be(gvar, 14).unwrap_or(-1)
  let data_array_off = gvar_read_u32_be_int(gvar, 16).unwrap_or(-1)
  if axis_count <= 0 || shared_tuple_count < 0 || glyph_count < 0 {
    return None
  }
  if shared_tuples_off < 0 || data_array_off < 0 {
    return None
  }
  if shared_tuples_off > gvar.length() || data_array_off > gvar.length() {
    return None
  }
  Some(GvarCtx::{
    gvar,
    axis_count,
    shared_tuple_count,
    shared_tuples_off,
    glyph_count,
    flags,
    data_array_off,
  })
}

///|
fn gvar_tuple_scalar(
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  peak : Array[Int],
  start : Array[Int]?,
  end : Array[Int]?,
) -> Double {
  let axis_count = peak.length()
  let mut scalar = 1.0
  for i in 0..<axis_count {
    let peak_v = peak.at(i)
    if peak_v == 0 {
      continue
    }
    let coord = if i < coords.length() { coords.at(i) } else { 0 }
    // Match read-fonts behavior: if the axis is active for this tuple but the
    // coordinate is zero, the scalar is zero.
    if coord == 0 {
      return 0.0
    }
    if coord == peak_v {
      continue
    }
    match (start, end) {
      (Some(s), Some(e)) => {
        let start_v = s.at(i)
        let end_v = e.at(i)
        if coord <= start_v || coord >= end_v {
          return 0.0
        }
        if coord < peak_v {
          if peak_v != start_v {
            scalar = scalar *
              (coord - start_v).to_double() /
              (peak_v - start_v).to_double()
          }
        } else if peak_v != end_v {
          scalar = scalar *
            (end_v - coord).to_double() /
            (end_v - peak_v).to_double()
        }
      }
      _ => {
        let min_v = if peak_v < 0 { peak_v } else { 0 }
        let max_v = if peak_v > 0 { peak_v } else { 0 }
        if coord < min_v || coord > max_v {
          return 0.0
        }
        scalar = scalar * coord.to_double() / peak_v.to_double()
      }
    }
  }
  scalar
}

///|
fn gvar_f2dot14_to_fixed16_16(bits : Int) -> Int {
  // F2Dot14 has 14 fractional bits; 16.16 has 16.
  bits << 2
}

///|
fn gvar_tuple_scalar_fixed16_16(
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  peak : Array[Int],
  start : Array[Int]?,
  end : Array[Int]?,
) -> Int {
  let axis_count = peak.length()
  let mut scalar = 0x10000
  for i in 0..<axis_count {
    let peak_v = peak.at(i)
    if peak_v == 0 {
      continue
    }
    let coord = if i < coords.length() { coords.at(i) } else { 0 }
    if coord == 0 {
      return 0
    }
    if coord == peak_v {
      continue
    }
    match (start, end) {
      (Some(s), Some(e)) => {
        let start_v = s.at(i)
        let end_v = e.at(i)
        if coord <= start_v || coord >= end_v {
          return 0
        }
        let coord_f = gvar_f2dot14_to_fixed16_16(coord)
        let peak_f = gvar_f2dot14_to_fixed16_16(peak_v)
        if coord_f < peak_f {
          let start_f = gvar_f2dot14_to_fixed16_16(start_v)
          scalar = tt_hint_mul_div_16_16(
            scalar,
            coord_f - start_f,
            peak_f - start_f,
          )
        } else {
          let end_f = gvar_f2dot14_to_fixed16_16(end_v)
          scalar = tt_hint_mul_div_16_16(
            scalar,
            end_f - coord_f,
            end_f - peak_f,
          )
        }
      }
      _ => {
        let min_v = if peak_v < 0 { peak_v } else { 0 }
        let max_v = if peak_v > 0 { peak_v } else { 0 }
        if coord < min_v || coord > max_v {
          return 0
        }
        scalar = tt_hint_mul_div_16_16(
          scalar,
          gvar_f2dot14_to_fixed16_16(coord),
          gvar_f2dot14_to_fixed16_16(peak_v),
        )
      }
    }
  }
  scalar
}

///|
/// Decodes a point number run list.
fn gvar_points(
  gvar : BytesView,
  offset : Int,
  total_points : Int,
) -> (Array[Int]?, Int)? {
  let b0 = gvar_read_u8(gvar, offset).unwrap_or(-1)
  if b0 < 0 {
    return None
  }
  let mut count = 0
  let mut off = offset
  if (b0 & 0x80) == 0 {
    count = b0
    off = off + 1
  } else {
    let b1 = gvar_read_u8(gvar, offset + 1).unwrap_or(-1)
    if b1 < 0 {
      return None
    }
    count = ((b0 & 0x7F) << 8) | b1
    off = off + 2
  }
  if count == 0 {
    return Some((None, off))
  }
  let points : Array[Int] = Array::new()
  let mut last = 0
  while points.length() < count {
    let ctrl = gvar_read_u8(gvar, off).unwrap_or(-1)
    if ctrl < 0 {
      return None
    }
    off = off + 1
    let run_len = (ctrl & 0x7F) + 1
    let words = (ctrl & 0x80) != 0
    for _ in 0..<run_len {
      if points.length() >= count {
        break
      }
      let delta = if words {
        gvar_read_u16_be(gvar, off).unwrap_or(-1)
      } else {
        gvar_read_u8(gvar, off).unwrap_or(-1)
      }
      if delta < 0 {
        return None
      }
      off = off + (if words { 2 } else { 1 })
      last = last + delta
      if last < 0 || last >= total_points {
        return None
      }
      points.push(last)
    }
  }
  Some((Some(points), off))
}

///|
/// Decodes a delta run list.
fn gvar_deltas(
  gvar : BytesView,
  offset : Int,
  count : Int,
) -> (Array[Int], Int)? {
  let mut off = offset
  let mut idx = 0
  let out : Array[Int] = Array::new()
  while idx < count {
    let ctrl = gvar_read_u8(gvar, off).unwrap_or(-1)
    if ctrl < 0 {
      return None
    }
    off = off + 1
    let run_len = (ctrl & 0x3F) + 1
    if idx + run_len > count {
      return None
    }
    // Match read-fonts' PackedDeltas:
    // - bit 7 (0x80): deltas are zero (no payload bytes)
    // - bit 6 (0x40): deltas are i16 (payload is big-endian i16)
    // - both bits set: deltas are i32 (payload is big-endian i32, used by VARC)
    // - neither set: deltas are i8 (payload is signed byte)
    let zeros = (ctrl & 0x80) != 0
    let words = (ctrl & 0x40) != 0
    if zeros && !words {
      for _ in 0..<run_len {
        out.push(0)
        idx = idx + 1
      }
    } else if !zeros && words {
      for _ in 0..<run_len {
        let v = gvar_read_i16_be(gvar, off).unwrap_or(0)
        off = off + 2
        out.push(v)
        idx = idx + 1
      }
    } else if !zeros && !words {
      for _ in 0..<run_len {
        let b = gvar_read_u8(gvar, off).unwrap_or(0)
        off = off + 1
        let v = if b >= 128 { b - 256 } else { b }
        out.push(v)
        idx = idx + 1
      }
    } else {
      // i32 values (rare; primarily for VARC). Keep as Int.
      for _ in 0..<run_len {
        let v = gvar_read_u32_be_int(gvar, off).unwrap_or(0)
        off = off + 4
        out.push(v)
        idx = idx + 1
      }
    }
  }
  Some((out, off))
}

///|
fn gvar_shift_contour(
  orig_x : Array[Double],
  orig_y : Array[Double],
  out_x : Array[Double],
  out_y : Array[Double],
  range_start : Int,
  range_end : Int,
  ref_ix : Int,
) -> Bool {
  if ref_ix < range_start || ref_ix > range_end {
    return false
  }
  let dx = out_x.at(ref_ix) - orig_x.at(ref_ix)
  let dy = out_y.at(ref_ix) - orig_y.at(ref_ix)
  if dx == 0.0 && dy == 0.0 {
    return true
  }
  for i in range_start..<ref_ix {
    out_x.set(i, out_x.at(i) + dx)
    out_y.set(i, out_y.at(i) + dy)
  }
  for i in (ref_ix + 1)..<(range_end + 1) {
    out_x.set(i, out_x.at(i) + dx)
    out_y.set(i, out_y.at(i) + dy)
  }
  true
}

///|
fn gvar_interp_coord(
  orig : Array[Double],
  out : Array[Double],
  range_start : Int,
  range_end : Int,
  ref1_ix_in : Int,
  ref2_ix_in : Int,
) -> Bool {
  if range_start > range_end {
    return true
  }
  let mut ref1_ix = ref1_ix_in
  let mut ref2_ix = ref2_ix_in
  if orig.at(ref1_ix) > orig.at(ref2_ix) {
    let tmp = ref1_ix
    ref1_ix = ref2_ix
    ref2_ix = tmp
  }
  let in1 = orig.at(ref1_ix)
  let in2 = orig.at(ref2_ix)
  let out1 = out.at(ref1_ix)
  let out2 = out.at(ref2_ix)
  // If the reference points have the same coordinate but different delta,
  // inferred delta is zero. Otherwise interpolate.
  if in1 != in2 || out1 == out2 {
    let scale = if in1 != in2 { (out2 - out1) / (in2 - in1) } else { 0.0 }
    let d1 = out1 - in1
    let d2 = out2 - in2
    for i in range_start..<(range_end + 1) {
      let mut v = orig.at(i)
      if v <= in1 {
        v = v + d1
      } else if v >= in2 {
        v = v + d2
      } else {
        v = out1 + (v - in1) * scale
      }
      out.set(i, v)
    }
  }
  true
}

///|
fn gvar_interpolate_deltas(
  orig_x : Array[Double],
  orig_y : Array[Double],
  out_x : Array[Double],
  out_y : Array[Double],
  has_delta : Array[Bool],
  contours : Array[Int],
  point_count : Int,
) -> Bool {
  let mut point_ix = 0
  for end_point_ix in contours.iter() {
    let end_ix = end_point_ix
    let first_ix = point_ix
    // Search for first point that has a delta.
    while point_ix <= end_ix &&
          point_ix < point_count &&
          !has_delta.at(point_ix) {
      point_ix = point_ix + 1
    }
    if point_ix > end_ix {
      // No deltas for this contour.
      continue
    }
    let first_delta_ix = point_ix
    let mut cur_delta_ix = point_ix
    point_ix = point_ix + 1
    // Search for next point that has a delta...
    while point_ix <= end_ix && point_ix < point_count {
      if has_delta.at(point_ix) {
        // ... and interpolate intermediate points.
        if !gvar_interp_coord(
            orig_x,
            out_x,
            cur_delta_ix + 1,
            point_ix - 1,
            cur_delta_ix,
            point_ix,
          ) {
          return false
        }
        if !gvar_interp_coord(
            orig_y,
            out_y,
            cur_delta_ix + 1,
            point_ix - 1,
            cur_delta_ix,
            point_ix,
          ) {
          return false
        }
        cur_delta_ix = point_ix
      }
      point_ix = point_ix + 1
    }
    // If we only have a single delta, shift the contour.
    if cur_delta_ix == first_delta_ix {
      if !gvar_shift_contour(
          orig_x, orig_y, out_x, out_y, first_ix, end_ix, cur_delta_ix,
        ) {
        return false
      }
    } else {
      // Otherwise, handle remaining points at beginning and end of contour.
      if !gvar_interp_coord(
          orig_x,
          out_x,
          cur_delta_ix + 1,
          end_ix,
          cur_delta_ix,
          first_delta_ix,
        ) {
        return false
      }
      if !gvar_interp_coord(
          orig_y,
          out_y,
          cur_delta_ix + 1,
          end_ix,
          cur_delta_ix,
          first_delta_ix,
        ) {
        return false
      }
      if first_delta_ix > first_ix {
        if !gvar_interp_coord(
            orig_x,
            out_x,
            first_ix,
            first_delta_ix - 1,
            cur_delta_ix,
            first_delta_ix,
          ) {
          return false
        }
        if !gvar_interp_coord(
            orig_y,
            out_y,
            first_ix,
            first_delta_ix - 1,
            cur_delta_ix,
            first_delta_ix,
          ) {
          return false
        }
      }
    }
  }
  true
}

///|
fn gvar_shift_contour_fixed(
  orig_x : Array[Int],
  orig_y : Array[Int],
  out_x : Array[Int],
  out_y : Array[Int],
  range_start : Int,
  range_end : Int,
  ref_ix : Int,
) -> Bool {
  if ref_ix < range_start || ref_ix > range_end {
    return false
  }
  let dx = out_x.at(ref_ix) - orig_x.at(ref_ix)
  let dy = out_y.at(ref_ix) - orig_y.at(ref_ix)
  if dx == 0 && dy == 0 {
    return true
  }
  for i in range_start..<ref_ix {
    out_x.set(i, out_x.at(i) + dx)
    out_y.set(i, out_y.at(i) + dy)
  }
  for i in (ref_ix + 1)..<(range_end + 1) {
    out_x.set(i, out_x.at(i) + dx)
    out_y.set(i, out_y.at(i) + dy)
  }
  true
}

///|
fn gvar_interp_coord_fixed(
  orig : Array[Int],
  out : Array[Int],
  range_start : Int,
  range_end : Int,
  ref1_ix_in : Int,
  ref2_ix_in : Int,
) -> Bool {
  if range_start > range_end {
    return true
  }
  let mut ref1_ix = ref1_ix_in
  let mut ref2_ix = ref2_ix_in
  if orig.at(ref1_ix) > orig.at(ref2_ix) {
    let tmp = ref1_ix
    ref1_ix = ref2_ix
    ref2_ix = tmp
  }
  let in1 = orig.at(ref1_ix)
  let in2 = orig.at(ref2_ix)
  let out1 = out.at(ref1_ix)
  let out2 = out.at(ref2_ix)
  // If the reference points have the same coordinate but different delta,
  // inferred delta is zero. Otherwise interpolate.
  if in1 != in2 || out1 == out2 {
    let scale = if in1 != in2 {
      tt_hint_div_16_16(out2 - out1, in2 - in1)
    } else {
      0
    }
    let d1 = out1 - in1
    let d2 = out2 - in2
    for i in range_start..<(range_end + 1) {
      let v0 = orig.at(i)
      let v = if v0 <= in1 {
        v0 + d1
      } else if v0 >= in2 {
        v0 + d2
      } else {
        out1 + tt_hint_mul_16_16(v0 - in1, scale)
      }
      out.set(i, v)
    }
  }
  true
}

///|
fn gvar_interpolate_deltas_fixed(
  orig_x : Array[Int],
  orig_y : Array[Int],
  out_x : Array[Int],
  out_y : Array[Int],
  has_delta : Array[Bool],
  contours : Array[Int],
  point_count : Int,
) -> Bool {
  let mut point_ix = 0
  for end_point_ix in contours.iter() {
    let end_ix = end_point_ix
    let first_ix = point_ix
    // Search for first point that has a delta.
    while point_ix <= end_ix &&
          point_ix < point_count &&
          !has_delta.at(point_ix) {
      point_ix = point_ix + 1
    }
    if point_ix > end_ix {
      // No deltas for this contour.
      continue
    }
    let first_delta_ix = point_ix
    let mut cur_delta_ix = point_ix
    point_ix = point_ix + 1
    // Search for next point that has a delta...
    while point_ix <= end_ix && point_ix < point_count {
      if has_delta.at(point_ix) {
        // ... and interpolate intermediate points.
        if !gvar_interp_coord_fixed(
            orig_x,
            out_x,
            cur_delta_ix + 1,
            point_ix - 1,
            cur_delta_ix,
            point_ix,
          ) {
          return false
        }
        if !gvar_interp_coord_fixed(
            orig_y,
            out_y,
            cur_delta_ix + 1,
            point_ix - 1,
            cur_delta_ix,
            point_ix,
          ) {
          return false
        }
        cur_delta_ix = point_ix
      }
      point_ix = point_ix + 1
    }
    // If we only have a single delta, shift the contour.
    if cur_delta_ix == first_delta_ix {
      if !gvar_shift_contour_fixed(
          orig_x, orig_y, out_x, out_y, first_ix, end_ix, cur_delta_ix,
        ) {
        return false
      }
    } else {
      // Otherwise, handle remaining points at beginning and end of contour.
      if !gvar_interp_coord_fixed(
          orig_x,
          out_x,
          cur_delta_ix + 1,
          end_ix,
          cur_delta_ix,
          first_delta_ix,
        ) {
        return false
      }
      if !gvar_interp_coord_fixed(
          orig_y,
          out_y,
          cur_delta_ix + 1,
          end_ix,
          cur_delta_ix,
          first_delta_ix,
        ) {
        return false
      }
      if first_delta_ix > first_ix {
        if !gvar_interp_coord_fixed(
            orig_x,
            out_x,
            first_ix,
            first_delta_ix - 1,
            cur_delta_ix,
            first_delta_ix,
          ) {
          return false
        }
        if !gvar_interp_coord_fixed(
            orig_y,
            out_y,
            first_ix,
            first_delta_ix - 1,
            cur_delta_ix,
            first_delta_ix,
          ) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Applies gvar deltas (if present) to the given simple glyf point list in
/// font units.
fn glyf_apply_gvar_simple(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  end_pts : Array[Int],
  xs : Array[Double],
  ys : Array[Double],
) -> Unit {
  if coords.is_empty() {
    return
  }
  let ctx = match gvar_ctx(font) {
    None => return
    Some(c) => c
  }
  let gid_i = gid.to_uint64().to_int()
  if gid_i < 0 || gid_i >= ctx.glyph_count {
    return
  }
  let point_count = xs.length()
  if ys.length() != point_count {
    return
  }
  let total_points = point_count + 4
  if total_points <= 0 {
    return
  }
  // Offsets array starts at 20.
  let offsets_off = 20
  let long_offsets = (ctx.flags & 1) != 0
  let entry_size = if long_offsets { 4 } else { 2 }
  let need = offsets_off + (ctx.glyph_count + 1) * entry_size
  if need < 0 || need > ctx.gvar.length() {
    return
  }
  let off0 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + gid_i * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + gid_i * 2).unwrap_or(-1) * 2
  }
  let off1 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + (gid_i + 1) * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + (gid_i + 1) * 2).unwrap_or(-1) * 2
  }
  if off0 < 0 || off1 < off0 {
    return
  }
  let start = ctx.data_array_off + off0
  let end = ctx.data_array_off + off1
  if start < 0 || end < start || end > ctx.gvar.length() {
    return
  }
  if start == end {
    return
  }
  let tuple_count_flags = gvar_read_u16_be(ctx.gvar, start).unwrap_or(0)
  let tuple_count = tuple_count_flags & 0x0FFF
  let shared_points = (tuple_count_flags & 0x8000) != 0
  let data_rel = gvar_read_u16_be(ctx.gvar, start + 2).unwrap_or(-1)
  if tuple_count <= 0 || data_rel < 0 {
    return
  }
  let sizes : Array[Int] = Array::new()
  let tuple_indexes : Array[Int] = Array::new()
  let axis_count = ctx.axis_count
  let scalars : Array[Double] = Array::new()

  // TupleVariationHeader is variable-length: the fixed fields are followed
  // by optional embedded peak and intermediate tuples.
  let mut header_off = start + 4
  for _ in 0..<tuple_count {
    let s = gvar_read_u16_be(ctx.gvar, header_off).unwrap_or(-1)
    let ti = gvar_read_u16_be(ctx.gvar, header_off + 2).unwrap_or(-1)
    if s < 0 || ti < 0 {
      return
    }
    header_off = header_off + 4
    sizes.push(s)
    tuple_indexes.push(ti)
    let embedded = (ti & 0x8000) != 0
    let intermediate = (ti & 0x4000) != 0
    let shared_ix = ti & 0x0FFF
    let peak : Array[Int] = Array::make(axis_count, 0)
    if embedded {
      let need = header_off + axis_count * 2
      if need < header_off || need > end {
        return
      }
      for ax in 0..<axis_count {
        peak.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0),
        )
      }
      header_off = header_off + axis_count * 2
    } else {
      if shared_ix < 0 || shared_ix >= ctx.shared_tuple_count {
        return
      }
      let base = ctx.shared_tuples_off + shared_ix * axis_count * 2
      let need = base + axis_count * 2
      if base < 0 || need < base || need > ctx.gvar.length() {
        return
      }
      for ax in 0..<axis_count {
        peak.set(ax, gvar_read_i16_be(ctx.gvar, base + ax * 2).unwrap_or(0))
      }
    }
    let mut start_t : Array[Int]? = None
    let mut end_t : Array[Int]? = None
    if intermediate {
      let st : Array[Int] = Array::make(axis_count, 0)
      let et : Array[Int] = Array::make(axis_count, 0)
      let need = header_off + axis_count * 4
      if need < header_off || need > end {
        return
      }
      for ax in 0..<axis_count {
        st.set(ax, gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0))
        et.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + axis_count * 2 + ax * 2).unwrap_or(
            0,
          ),
        )
      }
      header_off = header_off + axis_count * 4
      start_t = Some(st)
      end_t = Some(et)
    }
    scalars.push(gvar_tuple_scalar(coords, peak, start_t, end_t))
  }
  let data_off = start + data_rel
  // The header region must fit before the tuple data region.
  if data_off < header_off || data_off > end {
    return
  }
  // Accumulate deltas across tuples.
  let accum_x : Array[Double] = Array::make(point_count, 0.0)
  let accum_y : Array[Double] = Array::make(point_count, 0.0)
  let mut cursor = data_off
  let mut shared_points_list : Array[Int]? = None
  if shared_points {
    let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
      None => return
      Some(v) => v
    }
    shared_points_list = pts
    cursor = off2
  }
  for i in 0..<tuple_count {
    let size = sizes.at(i)
    let ti = tuple_indexes.at(i)
    let tuple_end = cursor + size
    if size < 0 || tuple_end < cursor || tuple_end > end {
      return
    }
    let scalar = scalars.at(i)
    if scalar == 0.0 {
      cursor = tuple_end
      continue
    }
    // PRIVATE_POINT_NUMBERS = 0x2000.
    let private_points = (ti & 0x2000) != 0
    let mut points_list : Array[Int]? = None
    let mut after_points = cursor
    if private_points || !shared_points {
      let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
        None => return
        Some(v) => v
      }
      points_list = pts
      after_points = off2
    } else {
      points_list = shared_points_list
      after_points = cursor
    }
    let count = match points_list {
      None => total_points
      Some(arr) => arr.length()
    }
    let (dxs, after_x) = match gvar_deltas(ctx.gvar, after_points, count) {
      None => return
      Some(v) => v
    }
    let (dys, after_y) = match gvar_deltas(ctx.gvar, after_x, count) {
      None => return
      Some(v) => v
    }
    if after_y > tuple_end {
      return
    }
    // Prepare IUP working buffers for this tuple (only for real points).
    let orig_x : Array[Double] = Array::make(point_count, 0.0)
    let orig_y : Array[Double] = Array::make(point_count, 0.0)
    let out_x : Array[Double] = Array::make(point_count, 0.0)
    let out_y : Array[Double] = Array::make(point_count, 0.0)
    for p_ix in 0..<point_count {
      let x = xs.at(p_ix)
      let y = ys.at(p_ix)
      orig_x.set(p_ix, x)
      orig_y.set(p_ix, y)
      out_x.set(p_ix, x)
      out_y.set(p_ix, y)
    }
    let has_delta : Array[Bool] = Array::make(point_count, false)
    match points_list {
      None =>
        // Dense: deltas are for all points (including phantoms). Apply first point_count.
        for p_ix in 0..<point_count {
          out_x.set(p_ix, out_x.at(p_ix) + dxs.at(p_ix).to_double() * scalar)
          out_y.set(p_ix, out_y.at(p_ix) + dys.at(p_ix).to_double() * scalar)
          has_delta.set(p_ix, true)
        }
      Some(list) =>
        for j in 0..<list.length() {
          let pt = list.at(j)
          if pt >= 0 && pt < point_count {
            out_x.set(pt, out_x.at(pt) + dxs.at(j).to_double() * scalar)
            out_y.set(pt, out_y.at(pt) + dys.at(j).to_double() * scalar)
            has_delta.set(pt, true)
          }
        }
    }
    if !gvar_interpolate_deltas(
        orig_x, orig_y, out_x, out_y, has_delta, end_pts, point_count,
      ) {
      return
    }
    for p_ix in 0..<point_count {
      accum_x.set(p_ix, accum_x.at(p_ix) + (out_x.at(p_ix) - orig_x.at(p_ix)))
      accum_y.set(p_ix, accum_y.at(p_ix) + (out_y.at(p_ix) - orig_y.at(p_ix)))
    }
    cursor = tuple_end
  }
  // Apply accumulated deltas in font units without prematurely rounding. The
  // final scaler path (26.6 or 16.16) is responsible for its own rounding.
  for i in 0..<point_count {
    xs.set(i, xs.at(i) + accum_x.at(i))
    ys.set(i, ys.at(i) + accum_y.at(i))
  }
}

///|
/// Returns gvar component deltas for a composite glyph.
///
/// For composite glyphs, interpolation is meaningless for component offsets,
/// so this only accumulates explicit deltas for active tuples (matching
/// fontations-reference / FreeType behavior).
fn glyf_gvar_composite_deltas(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  component_count : Int,
) -> (Array[Double], Array[Double])? {
  if coords.is_empty() {
    return None
  }
  if component_count <= 0 {
    return None
  }
  let ctx = match gvar_ctx(font) {
    None => return None
    Some(c) => c
  }
  let gid_i = gid.to_uint64().to_int()
  if gid_i < 0 || gid_i >= ctx.glyph_count {
    return None
  }
  let total_points = component_count + 4
  if total_points <= 0 {
    return None
  }
  // Offsets array starts at 20.
  let offsets_off = 20
  let long_offsets = (ctx.flags & 1) != 0
  let entry_size = if long_offsets { 4 } else { 2 }
  let need = offsets_off + (ctx.glyph_count + 1) * entry_size
  if need < 0 || need > ctx.gvar.length() {
    return None
  }
  let off0 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + gid_i * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + gid_i * 2).unwrap_or(-1) * 2
  }
  let off1 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + (gid_i + 1) * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + (gid_i + 1) * 2).unwrap_or(-1) * 2
  }
  if off0 < 0 || off1 < off0 {
    return None
  }
  let start = ctx.data_array_off + off0
  let end = ctx.data_array_off + off1
  if start < 0 || end < start || end > ctx.gvar.length() {
    return None
  }
  if start == end {
    return None
  }
  let tuple_count_flags = gvar_read_u16_be(ctx.gvar, start).unwrap_or(0)
  let tuple_count = tuple_count_flags & 0x0FFF
  let shared_points = (tuple_count_flags & 0x8000) != 0
  let data_rel = gvar_read_u16_be(ctx.gvar, start + 2).unwrap_or(-1)
  if tuple_count <= 0 || data_rel < 0 {
    return None
  }
  let sizes : Array[Int] = Array::new()
  let tuple_indexes : Array[Int] = Array::new()
  let axis_count = ctx.axis_count
  let scalars : Array[Double] = Array::new()
  let mut header_off = start + 4
  for _ in 0..<tuple_count {
    let s = gvar_read_u16_be(ctx.gvar, header_off).unwrap_or(-1)
    let ti = gvar_read_u16_be(ctx.gvar, header_off + 2).unwrap_or(-1)
    if s < 0 || ti < 0 {
      return None
    }
    header_off = header_off + 4
    sizes.push(s)
    tuple_indexes.push(ti)
    let embedded = (ti & 0x8000) != 0
    let intermediate = (ti & 0x4000) != 0
    let shared_ix = ti & 0x0FFF
    let peak : Array[Int] = Array::make(axis_count, 0)
    if embedded {
      let need = header_off + axis_count * 2
      if need < header_off || need > end {
        return None
      }
      for ax in 0..<axis_count {
        peak.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0),
        )
      }
      header_off = header_off + axis_count * 2
    } else {
      if shared_ix < 0 || shared_ix >= ctx.shared_tuple_count {
        return None
      }
      let base = ctx.shared_tuples_off + shared_ix * axis_count * 2
      let need = base + axis_count * 2
      if base < 0 || need < base || need > ctx.gvar.length() {
        return None
      }
      for ax in 0..<axis_count {
        peak.set(ax, gvar_read_i16_be(ctx.gvar, base + ax * 2).unwrap_or(0))
      }
    }
    let mut start_t : Array[Int]? = None
    let mut end_t : Array[Int]? = None
    if intermediate {
      let st : Array[Int] = Array::make(axis_count, 0)
      let et : Array[Int] = Array::make(axis_count, 0)
      let need = header_off + axis_count * 4
      if need < header_off || need > end {
        return None
      }
      for ax in 0..<axis_count {
        st.set(ax, gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0))
        et.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + axis_count * 2 + ax * 2).unwrap_or(
            0,
          ),
        )
      }
      header_off = header_off + axis_count * 4
      start_t = Some(st)
      end_t = Some(et)
    }
    scalars.push(gvar_tuple_scalar(coords, peak, start_t, end_t))
  }
  let data_off = start + data_rel
  if data_off < header_off || data_off > end {
    return None
  }
  let accum_x : Array[Double] = Array::make(component_count, 0.0)
  let accum_y : Array[Double] = Array::make(component_count, 0.0)
  let mut cursor = data_off
  let mut shared_points_list : Array[Int]? = None
  if shared_points {
    let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
      None => return None
      Some(v) => v
    }
    shared_points_list = pts
    cursor = off2
  }
  for i in 0..<tuple_count {
    let size = sizes.at(i)
    let ti = tuple_indexes.at(i)
    let tuple_end = cursor + size
    if size < 0 || tuple_end < cursor || tuple_end > end {
      return None
    }
    let scalar = scalars.at(i)
    if scalar == 0.0 {
      cursor = tuple_end
      continue
    }
    // PRIVATE_POINT_NUMBERS = 0x2000.
    let private_points = (ti & 0x2000) != 0
    let mut points_list : Array[Int]? = None
    let mut after_points = cursor
    if private_points || !shared_points {
      let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
        None => return None
        Some(v) => v
      }
      points_list = pts
      after_points = off2
    } else {
      points_list = shared_points_list
      after_points = cursor
    }
    let count = match points_list {
      None => total_points
      Some(arr) => arr.length()
    }
    let (dxs, after_x) = match gvar_deltas(ctx.gvar, after_points, count) {
      None => return None
      Some(v) => v
    }
    let (dys, after_y) = match gvar_deltas(ctx.gvar, after_x, count) {
      None => return None
      Some(v) => v
    }
    if after_y > tuple_end {
      return None
    }
    match points_list {
      None =>
        for pt in 0..<component_count {
          accum_x.set(pt, accum_x.at(pt) + dxs.at(pt).to_double() * scalar)
          accum_y.set(pt, accum_y.at(pt) + dys.at(pt).to_double() * scalar)
        }
      Some(list) =>
        for j in 0..<list.length() {
          let pt = list.at(j)
          if pt >= 0 && pt < component_count {
            accum_x.set(pt, accum_x.at(pt) + dxs.at(j).to_double() * scalar)
            accum_y.set(pt, accum_y.at(pt) + dys.at(j).to_double() * scalar)
          }
        }
    }
    cursor = tuple_end
  }
  Some((accum_x, accum_y))
}

///|
/// Rounds a 16.16 fixed value to i32, matching FreeType-style rounding.
fn gvar_fixed16_16_to_i32(bits : Int) -> Int {
  // Matches `font_types::Fixed::to_i32()` rounding.
  ((bits.to_int64() + (0x8000).to_int64()) >> 16).to_int()
}

///|
fn gvar_scale_funit_delta_to_fixed16_16(delta : Int, scalar_bits : Int) -> Int {
  let bits = delta << 16
  if scalar_bits == 0x10000 {
    bits
  } else {
    tt_hint_mul_16_16(bits, scalar_bits)
  }
}

///|
fn gvar_zero_deltas(total_points : Int) -> (Array[Int], Array[Int]) {
  (Array::make(total_points, 0), Array::make(total_points, 0))
}

///|
/// Computes gvar point deltas for a simple glyph suitable for embedded hinting.
///
/// Returns 16.16 fixed deltas for all points, including the four phantom
/// points, with IUP interpolation applied to missing real-point deltas.
fn glyf_gvar_simple_hint_deltas(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  end_pts : Array[Int],
  xs : Array[Double],
  ys : Array[Double],
) -> (Array[Int], Array[Int])? {
  if coords.is_empty() {
    return None
  }
  let ctx = match gvar_ctx(font) {
    None => return None
    Some(c) => c
  }
  let gid_i = gid.to_uint64().to_int()
  if gid_i < 0 || gid_i >= ctx.glyph_count {
    return None
  }
  let point_count = xs.length()
  if ys.length() != point_count {
    return None
  }
  let total_points = point_count + 4
  if total_points <= 0 {
    return None
  }
  // Offsets array starts at 20.
  let offsets_off = 20
  let long_offsets = (ctx.flags & 1) != 0
  let entry_size = if long_offsets { 4 } else { 2 }
  let need = offsets_off + (ctx.glyph_count + 1) * entry_size
  if need < 0 || need > ctx.gvar.length() {
    return Some(gvar_zero_deltas(total_points))
  }
  let off0 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + gid_i * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + gid_i * 2).unwrap_or(-1) * 2
  }
  let off1 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + (gid_i + 1) * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + (gid_i + 1) * 2).unwrap_or(-1) * 2
  }
  if off0 < 0 || off1 < off0 {
    return Some(gvar_zero_deltas(total_points))
  }
  let start = ctx.data_array_off + off0
  let end = ctx.data_array_off + off1
  if start < 0 || end < start || end > ctx.gvar.length() {
    return Some(gvar_zero_deltas(total_points))
  }
  if start == end {
    return Some(gvar_zero_deltas(total_points))
  }
  let tuple_count_flags = gvar_read_u16_be(ctx.gvar, start).unwrap_or(0)
  let tuple_count = tuple_count_flags & 0x0FFF
  let shared_points = (tuple_count_flags & 0x8000) != 0
  let data_rel = gvar_read_u16_be(ctx.gvar, start + 2).unwrap_or(-1)
  if tuple_count <= 0 || data_rel < 0 {
    return Some(gvar_zero_deltas(total_points))
  }
  let sizes : Array[Int] = Array::new()
  let tuple_indexes : Array[Int] = Array::new()
  let axis_count = ctx.axis_count
  let scalars : Array[Int] = Array::new()
  let mut header_off = start + 4
  for _ in 0..<tuple_count {
    let s = gvar_read_u16_be(ctx.gvar, header_off).unwrap_or(-1)
    let ti = gvar_read_u16_be(ctx.gvar, header_off + 2).unwrap_or(-1)
    if s < 0 || ti < 0 {
      return Some(gvar_zero_deltas(total_points))
    }
    header_off = header_off + 4
    sizes.push(s)
    tuple_indexes.push(ti)
    let embedded = (ti & 0x8000) != 0
    let intermediate = (ti & 0x4000) != 0
    let shared_ix = ti & 0x0FFF
    let peak : Array[Int] = Array::make(axis_count, 0)
    if embedded {
      let need = header_off + axis_count * 2
      if need < header_off || need > end {
        return Some(gvar_zero_deltas(total_points))
      }
      for ax in 0..<axis_count {
        peak.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0),
        )
      }
      header_off = header_off + axis_count * 2
    } else {
      if shared_ix < 0 || shared_ix >= ctx.shared_tuple_count {
        return Some(gvar_zero_deltas(total_points))
      }
      let base = ctx.shared_tuples_off + shared_ix * axis_count * 2
      let need = base + axis_count * 2
      if base < 0 || need < base || need > ctx.gvar.length() {
        return Some(gvar_zero_deltas(total_points))
      }
      for ax in 0..<axis_count {
        peak.set(ax, gvar_read_i16_be(ctx.gvar, base + ax * 2).unwrap_or(0))
      }
    }
    let mut start_t : Array[Int]? = None
    let mut end_t : Array[Int]? = None
    if intermediate {
      let st : Array[Int] = Array::make(axis_count, 0)
      let et : Array[Int] = Array::make(axis_count, 0)
      let need = header_off + axis_count * 4
      if need < header_off || need > end {
        return Some(gvar_zero_deltas(total_points))
      }
      for ax in 0..<axis_count {
        st.set(ax, gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0))
        et.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + axis_count * 2 + ax * 2).unwrap_or(
            0,
          ),
        )
      }
      header_off = header_off + axis_count * 4
      start_t = Some(st)
      end_t = Some(et)
    }
    scalars.push(gvar_tuple_scalar_fixed16_16(coords, peak, start_t, end_t))
  }
  let data_off = start + data_rel
  if data_off < header_off || data_off > end {
    return Some(gvar_zero_deltas(total_points))
  }
  let accum_x : Array[Int] = Array::make(total_points, 0)
  let accum_y : Array[Int] = Array::make(total_points, 0)
  let mut cursor = data_off
  let mut shared_points_list : Array[Int]? = None
  if shared_points {
    let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
      None => return Some(gvar_zero_deltas(total_points))
      Some(v) => v
    }
    shared_points_list = pts
    cursor = off2
  }
  for i in 0..<tuple_count {
    let size = sizes.at(i)
    let ti = tuple_indexes.at(i)
    let tuple_end = cursor + size
    if size < 0 || tuple_end < cursor || tuple_end > end {
      return Some(gvar_zero_deltas(total_points))
    }
    let scalar = scalars.at(i)
    if scalar == 0 {
      cursor = tuple_end
      continue
    }
    // PRIVATE_POINT_NUMBERS = 0x2000.
    let private_points = (ti & 0x2000) != 0
    let mut points_list : Array[Int]? = None
    let mut after_points = cursor
    if private_points || !shared_points {
      let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
        None => return Some(gvar_zero_deltas(total_points))
        Some(v) => v
      }
      points_list = pts
      after_points = off2
    } else {
      points_list = shared_points_list
      after_points = cursor
    }
    let count = match points_list {
      None => total_points
      Some(arr) => arr.length()
    }
    let (dxs, after_x) = match gvar_deltas(ctx.gvar, after_points, count) {
      None => return Some(gvar_zero_deltas(total_points))
      Some(v) => v
    }
    let (dys, after_y) = match gvar_deltas(ctx.gvar, after_x, count) {
      None => return Some(gvar_zero_deltas(total_points))
      Some(v) => v
    }
    if after_y > tuple_end {
      return Some(gvar_zero_deltas(total_points))
    }
    // Prepare IUP buffers for real points for this tuple (16.16 coords).
    let orig_x : Array[Int] = Array::make(point_count, 0)
    let orig_y : Array[Int] = Array::make(point_count, 0)
    let out_x : Array[Int] = Array::make(point_count, 0)
    let out_y : Array[Int] = Array::make(point_count, 0)
    for p_ix in 0..<point_count {
      let x = xs.at(p_ix).round().to_int()
      let y = ys.at(p_ix).round().to_int()
      let xb = x << 16
      let yb = y << 16
      orig_x.set(p_ix, xb)
      orig_y.set(p_ix, yb)
      out_x.set(p_ix, xb)
      out_y.set(p_ix, yb)
    }
    let has_delta : Array[Bool] = Array::make(point_count, false)
    match points_list {
      None => {
        // Dense: apply real points and phantom points.
        for p_ix in 0..<point_count {
          out_x.set(
            p_ix,
            out_x.at(p_ix) +
            gvar_scale_funit_delta_to_fixed16_16(dxs.at(p_ix), scalar),
          )
          out_y.set(
            p_ix,
            out_y.at(p_ix) +
            gvar_scale_funit_delta_to_fixed16_16(dys.at(p_ix), scalar),
          )
          has_delta.set(p_ix, true)
        }
        for p_ix in point_count..<total_points {
          accum_x.set(
            p_ix,
            accum_x.at(p_ix) +
            gvar_scale_funit_delta_to_fixed16_16(dxs.at(p_ix), scalar),
          )
          accum_y.set(
            p_ix,
            accum_y.at(p_ix) +
            gvar_scale_funit_delta_to_fixed16_16(dys.at(p_ix), scalar),
          )
        }
      }
      Some(list) =>
        for j in 0..<list.length() {
          let pt = list.at(j)
          if pt >= 0 && pt < point_count {
            out_x.set(
              pt,
              out_x.at(pt) +
              gvar_scale_funit_delta_to_fixed16_16(dxs.at(j), scalar),
            )
            out_y.set(
              pt,
              out_y.at(pt) +
              gvar_scale_funit_delta_to_fixed16_16(dys.at(j), scalar),
            )
            has_delta.set(pt, true)
          } else if pt >= point_count && pt < total_points {
            accum_x.set(
              pt,
              accum_x.at(pt) +
              gvar_scale_funit_delta_to_fixed16_16(dxs.at(j), scalar),
            )
            accum_y.set(
              pt,
              accum_y.at(pt) +
              gvar_scale_funit_delta_to_fixed16_16(dys.at(j), scalar),
            )
          }
        }
    }
    if !gvar_interpolate_deltas_fixed(
        orig_x, orig_y, out_x, out_y, has_delta, end_pts, point_count,
      ) {
      return Some(gvar_zero_deltas(total_points))
    }
    for p_ix in 0..<point_count {
      accum_x.set(p_ix, accum_x.at(p_ix) + (out_x.at(p_ix) - orig_x.at(p_ix)))
      accum_y.set(p_ix, accum_y.at(p_ix) + (out_y.at(p_ix) - orig_y.at(p_ix)))
    }
    cursor = tuple_end
  }
  Some((accum_x, accum_y))
}

///|
/// Computes gvar component + phantom deltas for a composite glyph suitable for
/// embedded hinting.
///
/// Returns 16.16 fixed deltas for all "component points" plus the four phantom
/// points. No interpolation is performed (matching FreeType/fontations).
fn glyf_gvar_composite_hint_deltas(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  component_count : Int,
) -> (Array[Int], Array[Int])? {
  if coords.is_empty() {
    return None
  }
  if component_count <= 0 {
    return None
  }
  let ctx = match gvar_ctx(font) {
    None => return None
    Some(c) => c
  }
  let gid_i = gid.to_uint64().to_int()
  if gid_i < 0 || gid_i >= ctx.glyph_count {
    return None
  }
  let total_points = component_count + 4
  if total_points <= 0 {
    return None
  }
  // Offsets array starts at 20.
  let offsets_off = 20
  let long_offsets = (ctx.flags & 1) != 0
  let entry_size = if long_offsets { 4 } else { 2 }
  let need = offsets_off + (ctx.glyph_count + 1) * entry_size
  if need < 0 || need > ctx.gvar.length() {
    return Some(gvar_zero_deltas(total_points))
  }
  let off0 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + gid_i * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + gid_i * 2).unwrap_or(-1) * 2
  }
  let off1 = if long_offsets {
    gvar_read_u32_be_int(ctx.gvar, offsets_off + (gid_i + 1) * 4).unwrap_or(-1)
  } else {
    gvar_read_u16_be(ctx.gvar, offsets_off + (gid_i + 1) * 2).unwrap_or(-1) * 2
  }
  if off0 < 0 || off1 < off0 {
    return Some(gvar_zero_deltas(total_points))
  }
  let start = ctx.data_array_off + off0
  let end = ctx.data_array_off + off1
  if start < 0 || end < start || end > ctx.gvar.length() {
    return Some(gvar_zero_deltas(total_points))
  }
  if start == end {
    return Some(gvar_zero_deltas(total_points))
  }
  let tuple_count_flags = gvar_read_u16_be(ctx.gvar, start).unwrap_or(0)
  let tuple_count = tuple_count_flags & 0x0FFF
  let shared_points = (tuple_count_flags & 0x8000) != 0
  let data_rel = gvar_read_u16_be(ctx.gvar, start + 2).unwrap_or(-1)
  if tuple_count <= 0 || data_rel < 0 {
    return Some(gvar_zero_deltas(total_points))
  }
  let sizes : Array[Int] = Array::new()
  let tuple_indexes : Array[Int] = Array::new()
  let axis_count = ctx.axis_count
  let scalars : Array[Int] = Array::new()
  let mut header_off = start + 4
  for _ in 0..<tuple_count {
    let s = gvar_read_u16_be(ctx.gvar, header_off).unwrap_or(-1)
    let ti = gvar_read_u16_be(ctx.gvar, header_off + 2).unwrap_or(-1)
    if s < 0 || ti < 0 {
      return Some(gvar_zero_deltas(total_points))
    }
    header_off = header_off + 4
    sizes.push(s)
    tuple_indexes.push(ti)
    let embedded = (ti & 0x8000) != 0
    let intermediate = (ti & 0x4000) != 0
    let shared_ix = ti & 0x0FFF
    let peak : Array[Int] = Array::make(axis_count, 0)
    if embedded {
      let need = header_off + axis_count * 2
      if need < header_off || need > end {
        return Some(gvar_zero_deltas(total_points))
      }
      for ax in 0..<axis_count {
        peak.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0),
        )
      }
      header_off = header_off + axis_count * 2
    } else {
      if shared_ix < 0 || shared_ix >= ctx.shared_tuple_count {
        return Some(gvar_zero_deltas(total_points))
      }
      let base = ctx.shared_tuples_off + shared_ix * axis_count * 2
      let need = base + axis_count * 2
      if base < 0 || need < base || need > ctx.gvar.length() {
        return Some(gvar_zero_deltas(total_points))
      }
      for ax in 0..<axis_count {
        peak.set(ax, gvar_read_i16_be(ctx.gvar, base + ax * 2).unwrap_or(0))
      }
    }
    let mut start_t : Array[Int]? = None
    let mut end_t : Array[Int]? = None
    if intermediate {
      let st : Array[Int] = Array::make(axis_count, 0)
      let et : Array[Int] = Array::make(axis_count, 0)
      let need = header_off + axis_count * 4
      if need < header_off || need > end {
        return Some(gvar_zero_deltas(total_points))
      }
      for ax in 0..<axis_count {
        st.set(ax, gvar_read_i16_be(ctx.gvar, header_off + ax * 2).unwrap_or(0))
        et.set(
          ax,
          gvar_read_i16_be(ctx.gvar, header_off + axis_count * 2 + ax * 2).unwrap_or(
            0,
          ),
        )
      }
      header_off = header_off + axis_count * 4
      start_t = Some(st)
      end_t = Some(et)
    }
    scalars.push(gvar_tuple_scalar_fixed16_16(coords, peak, start_t, end_t))
  }
  let data_off = start + data_rel
  if data_off < header_off || data_off > end {
    return Some(gvar_zero_deltas(total_points))
  }
  let accum_x : Array[Int] = Array::make(total_points, 0)
  let accum_y : Array[Int] = Array::make(total_points, 0)
  let mut cursor = data_off
  let mut shared_points_list : Array[Int]? = None
  if shared_points {
    let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
      None => return Some(gvar_zero_deltas(total_points))
      Some(v) => v
    }
    shared_points_list = pts
    cursor = off2
  }
  for i in 0..<tuple_count {
    let size = sizes.at(i)
    let ti = tuple_indexes.at(i)
    let tuple_end = cursor + size
    if size < 0 || tuple_end < cursor || tuple_end > end {
      return Some(gvar_zero_deltas(total_points))
    }
    let scalar = scalars.at(i)
    if scalar == 0 {
      cursor = tuple_end
      continue
    }
    // PRIVATE_POINT_NUMBERS = 0x2000.
    let private_points = (ti & 0x2000) != 0
    let mut points_list : Array[Int]? = None
    let mut after_points = cursor
    if private_points || !shared_points {
      let (pts, off2) = match gvar_points(ctx.gvar, cursor, total_points) {
        None => return Some(gvar_zero_deltas(total_points))
        Some(v) => v
      }
      points_list = pts
      after_points = off2
    } else {
      points_list = shared_points_list
      after_points = cursor
    }
    let count = match points_list {
      None => total_points
      Some(arr) => arr.length()
    }
    let (dxs, after_x) = match gvar_deltas(ctx.gvar, after_points, count) {
      None => return Some(gvar_zero_deltas(total_points))
      Some(v) => v
    }
    let (dys, after_y) = match gvar_deltas(ctx.gvar, after_x, count) {
      None => return Some(gvar_zero_deltas(total_points))
      Some(v) => v
    }
    if after_y > tuple_end {
      return Some(gvar_zero_deltas(total_points))
    }
    match points_list {
      None =>
        for pt in 0..<total_points {
          accum_x.set(
            pt,
            accum_x.at(pt) +
            gvar_scale_funit_delta_to_fixed16_16(dxs.at(pt), scalar),
          )
          accum_y.set(
            pt,
            accum_y.at(pt) +
            gvar_scale_funit_delta_to_fixed16_16(dys.at(pt), scalar),
          )
        }
      Some(list) =>
        for j in 0..<list.length() {
          let pt = list.at(j)
          if pt >= 0 && pt < total_points {
            accum_x.set(
              pt,
              accum_x.at(pt) +
              gvar_scale_funit_delta_to_fixed16_16(dxs.at(j), scalar),
            )
            accum_y.set(
              pt,
              accum_y.at(pt) +
              gvar_scale_funit_delta_to_fixed16_16(dys.at(j), scalar),
            )
          }
        }
    }
    cursor = tuple_end
  }
  Some((accum_x, accum_y))
}
