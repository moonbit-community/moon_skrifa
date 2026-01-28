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
/// Minimal glyf loader for TrueType hinting.
///
/// This intentionally supports only simple glyphs for now (sufficient for the
/// hint parity fixtures).
const TAG_HEAD_TT : UInt = 0x68656164 // "head"

///|
const TAG_LOCA_TT : UInt = 0x6C6F6361 // "loca"

///|
const TAG_MAXP_TT2 : UInt = 0x6D617870 // "maxp"

///|
const TAG_GLYF_TT : UInt = 0x676C7966 // "glyf"

///|
const TAG_HHEA_TT : UInt = 0x68686561 // "hhea"

///|
const TAG_HMTX_TT : UInt = 0x686D7478 // "hmtx"

///|
const TAG_OS2_TT : UInt = 0x4F532F32 // "OS/2"

///|
fn tt2_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn tt2_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match tt2_read_u16_be(view, offset) {
    None => None
    Some(u) => Some(if u >= 0x8000 { u - 0x10000 } else { u })
  }
}

///|
fn tt2_read_u32_be(view : BytesView, offset : Int) -> UInt? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_uint()
    let b1 = view.at(offset + 1).to_uint()
    let b2 = view.at(offset + 2).to_uint()
    let b3 = view.at(offset + 3).to_uint()
    Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
}

///|
fn tt2_scale_funits_to_26_6(value : Int, scale_bits : Int) -> Int {
  let v = value.to_int64() * scale_bits.to_int64()
  let adj = 0x8000 - (if v < 0 { 1 } else { 0 })
  ((v + adj.to_int64()) >> 16).to_int()
}

///|
/// Scales a font-unit coordinate plus a 16.16 gvar delta into 26.6 bits.
fn tt2_scale_funits_plus_delta_fixed_to_26_6(
  value : Int,
  delta_bits : Int,
  scale_bits : Int,
) -> Int {
  // Match fontations' scaling path for gvar deltas:
  // - convert delta 16.16 -> 26.6 (Fixed::to_f26dot6 rounding)
  // - add to value in 26.6
  // - multiply by 16.16 scale (stored in `scale_bits`)
  // - undo the extra 26.6 shift (F26Dot6::to_i32 rounding)
  let delta_26_6 = ((delta_bits.to_int64() + (0x200).to_int64()) >> 10).to_int()
  let base_26_6 = (value << 6) + delta_26_6
  let tmp = tt_hint_mul_16_16(base_26_6, scale_bits)
  ((tmp.to_int64() + (32).to_int64()) >> 6).to_int()
}

///|
fn tt2_round_grid_26_6(bits : Int) -> Int {
  if bits >= 0 {
    tt_hint_round_26(bits).max(0)
  } else {
    (-tt_hint_round_26(-bits)).min(0)
  }
}

///|
fn tt2_os2_vmetrics(font : @moon_skrifa.FontRef) -> (Int, Int) {
  // Matches fontations Outlines::new: use OS/2 sTypoAscender/Descender,
  // defaulting to 0 if the table is missing.
  match font.table(TAG_OS2_TT) {
    None => (0, 0)
    Some(os2) => {
      // Offsets: sTypoAscender @68, sTypoDescender @70.
      // Use 0 when the table is too short.
      let asc = tt2_read_i16_be(os2, 68).unwrap_or(0)
      let desc = tt2_read_i16_be(os2, 70).unwrap_or(0)
      (asc, desc)
    }
  }
}

///|
fn tt2_glyph_slice(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> Result[BytesView, DrawError] {
  let head = match font.table(TAG_HEAD_TT) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let loca = match font.table(TAG_LOCA_TT) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let glyf = match font.table(TAG_GLYF_TT) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let maxp = match font.table(TAG_MAXP_TT2) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let num_glyphs = match tt2_read_u16_be(maxp, 4) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= num_glyphs {
    return Err(DrawError::GlyphNotFound(gid))
  }
  let index_to_loc_format = match tt2_read_i16_be(head, 50) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let (start, end) = if index_to_loc_format == 0 {
    let need = (num_glyphs + 1) * 2
    if loca.length() < need {
      return Err(DrawError::Read)
    }
    let o0 = match tt2_read_u16_be(loca, idx * 2) {
      None => return Err(DrawError::Read)
      Some(v) => v
    }
    let o0 = o0 * 2
    let o1 = match tt2_read_u16_be(loca, (idx + 1) * 2) {
      None => return Err(DrawError::Read)
      Some(v) => v
    }
    let o1 = o1 * 2
    (o0, o1)
  } else {
    let need = (num_glyphs + 1) * 4
    if loca.length() < need {
      return Err(DrawError::Read)
    }
    let o0_u = match tt2_read_u32_be(loca, idx * 4) {
      None => return Err(DrawError::Read)
      Some(v) => v
    }
    let o1_u = match tt2_read_u32_be(loca, (idx + 1) * 4) {
      None => return Err(DrawError::Read)
      Some(v) => v
    }
    let o0 = o0_u.to_uint64().to_int()
    let o1 = o1_u.to_uint64().to_int()
    (o0, o1)
  }
  if start < 0 || end < start || end > glyf.length() {
    Err(DrawError::Read)
  } else {
    Ok(glyf.sub(start~, end~))
  }
}

///|
fn tt2_hmtx_metrics(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> (Int, Int)? {
  let hhea = match font.table(TAG_HHEA_TT) {
    None => return None
    Some(v) => v
  }
  let hmtx = match font.table(TAG_HMTX_TT) {
    None => return None
    Some(v) => v
  }
  let num_hmetrics = tt2_read_u16_be(hhea, 34).unwrap_or(0)
  let idx = gid.to_uint64().to_int()
  if idx < 0 {
    return None
  }
  if num_hmetrics <= 0 {
    return None
  }
  let mut aw = 0
  let mut lsb = 0
  if idx < num_hmetrics {
    let off = idx * 4
    if off + 4 > hmtx.length() {
      return None
    }
    aw = tt2_read_u16_be(hmtx, off).unwrap_or(0)
    lsb = tt2_read_i16_be(hmtx, off + 2).unwrap_or(0)
  } else {
    let last_off = (num_hmetrics - 1) * 4
    if last_off + 4 > hmtx.length() {
      return None
    }
    aw = tt2_read_u16_be(hmtx, last_off).unwrap_or(0)
    let lsb_off = num_hmetrics * 4 + (idx - num_hmetrics) * 2
    if lsb_off + 2 > hmtx.length() {
      return None
    }
    lsb = tt2_read_i16_be(hmtx, lsb_off).unwrap_or(0)
  }
  Some((aw, lsb))
}

///|
fn tt2_decode_simple_glyph_for_hinting(
  glyph : BytesView,
  scale_bits : Int,
  advance : Int,
  lsb : Int,
  os2_ascent : Int,
  os2_descent : Int,
) -> (TtZone, BytesView)? {
  if glyph.length() < 10 {
    return None
  }
  let number_of_contours = tt2_read_i16_be(glyph, 0).unwrap_or(0)
  if number_of_contours < 0 {
    return None
  }
  let x_min = tt2_read_i16_be(glyph, 2).unwrap_or(0)
  let mut off = 10
  let contours : Array[Int] = Array::new()
  if number_of_contours > 0 {
    for _ in 0..<number_of_contours {
      let v = tt2_read_u16_be(glyph, off).unwrap_or(0)
      contours.push(v)
      off = off + 2
    }
  }
  let instruction_len = tt2_read_u16_be(glyph, off).unwrap_or(0)
  off = off + 2
  if instruction_len < 0 || off + instruction_len > glyph.length() {
    return None
  }
  let instr = glyph.sub(start=off, end=off + instruction_len)
  off = off + instruction_len
  let num_points = if contours.is_empty() {
    0
  } else {
    let last_end = contours.at(contours.length() - 1)
    last_end + 1
  }
  if num_points < 0 {
    return None
  }
  // Decode flags.
  let point_flags : Array[Int] = Array::new()
  while point_flags.length() < num_points {
    if off >= glyph.length() {
      return None
    }
    let flag = glyph.at(off).to_int()
    off = off + 1
    point_flags.push(flag)
    if (flag & 0x08) != 0 {
      if off >= glyph.length() {
        return None
      }
      let repeat = glyph.at(off).to_int()
      off = off + 1
      for _ in 0..<repeat {
        point_flags.push(flag)
      }
    }
  }
  // Decode x deltas.
  let dxs : Array[Int] = Array::new()
  for i in 0..<num_points {
    let f = point_flags.at(i)
    let short = (f & 0x02) != 0
    let same = (f & 0x10) != 0
    if short {
      if off >= glyph.length() {
        return None
      }
      let b = glyph.at(off).to_int()
      off = off + 1
      dxs.push(if same { b } else { -b })
    } else if same {
      dxs.push(0)
    } else {
      let d = tt2_read_i16_be(glyph, off).unwrap_or(0)
      off = off + 2
      dxs.push(d)
    }
  }
  // Decode y deltas.
  let dys : Array[Int] = Array::new()
  for i in 0..<num_points {
    let f = point_flags.at(i)
    let short = (f & 0x04) != 0
    let same = (f & 0x20) != 0
    if short {
      if off >= glyph.length() {
        return None
      }
      let b = glyph.at(off).to_int()
      off = off + 1
      dys.push(if same { b } else { -b })
    } else if same {
      dys.push(0)
    } else {
      let d = tt2_read_i16_be(glyph, off).unwrap_or(0)
      off = off + 2
      dys.push(d)
    }
  }
  // Build point arrays (+ phantom points).
  let total_points = num_points + 4
  let unscaled : Array[TtPoint] = Array::make(total_points, TtPoint::{
    x: 0,
    y: 0,
  })
  let original : Array[TtPoint] = Array::make(total_points, TtPoint::{
    x: 0,
    y: 0,
  })
  let points : Array[TtPoint] = Array::make(total_points, TtPoint::{
    x: 0,
    y: 0,
  })
  let flags : Array[Int] = Array::make(total_points, 0)
  let mut x = 0
  let mut y = 0
  for i in 0..<num_points {
    x = x + dxs.at(i)
    y = y + dys.at(i)
    let on = (point_flags.at(i) & 0x01) != 0
    unscaled.set(i, TtPoint::{ x, y })
    let sx = tt2_scale_funits_to_26_6(x, scale_bits)
    let sy = tt2_scale_funits_to_26_6(y, scale_bits)
    let sp = TtPoint::{ x: sx, y: sy }
    original.set(i, sp)
    points.set(i, sp)
    flags.set(i, if on { 1 } else { 0 })
  }
  // Phantom points in font units (see FreeType).
  let phantom0_x = x_min - lsb
  let phantom1_x = phantom0_x + advance
  unscaled.set(num_points, TtPoint::{ x: phantom0_x, y: 0 })
  unscaled.set(num_points + 1, TtPoint::{ x: phantom1_x, y: 0 })
  // Vertical phantom points: based on OS/2 sTypoAscender/Descender.
  // See fontations `Scaler::load` and `setup_phantom_points`.
  // phantom[2].y = yMax + tsb = ascent
  // phantom[3].y = phantom[2].y - vadvance = descent
  unscaled.set(num_points + 2, TtPoint::{ x: 0, y: os2_ascent })
  unscaled.set(num_points + 3, TtPoint::{ x: 0, y: os2_descent })
  for i in 0..<4 {
    let p = unscaled.at(num_points + i)
    let sx = tt2_scale_funits_to_26_6(p.x, scale_bits)
    let sy = tt2_scale_funits_to_26_6(p.y, scale_bits)
    let sp = TtPoint::{ x: sx, y: sy }
    original.set(num_points + i, sp)
    points.set(num_points + i, sp)
    flags.set(num_points + i, 0)
  }
  // Match fontations: when hinting, round phantom points in the "current"
  // point array before executing glyph instructions.
  if instr.length() > 0 {
    for i in 0..<4 {
      let p = points.at(num_points + i)
      points.set(num_points + i, TtPoint::{
        x: tt2_round_grid_26_6(p.x),
        y: tt2_round_grid_26_6(p.y),
      })
    }
  }
  let zone = TtZone::{ unscaled, original, points, flags, contours }
  Some((zone, instr))
}

///|

///|
const TT2_COMPOSITE_USE_MY_METRICS : Int = 0x0200

///|
priv enum Tt2Anchor {
  Offset(Int, Int)
  Point(Int, Int)
}

///|
priv struct Tt2Component {
  flags : Int
  gid : @moon_skrifa.GlyphId
  anchor : Tt2Anchor
  xx16 : Int
  yx16 : Int
  xy16 : Int
  yy16 : Int
  have_xform : Bool
  // 2.14 as float for hypot-guess scaling.
  xx : Double
  yx : Double
  xy : Double
  yy : Double
}

///|
fn tt2_read_f2dot14_bits(view : BytesView, offset : Int) -> Int? {
  tt2_read_i16_be(view, offset)
}

///|
fn tt2_f2dot14_to_double(bits : Int) -> Double {
  bits.to_double() / 16384.0
}

///|
fn tt2_f2dot14_to_16_16(bits : Int) -> Int {
  bits * 4
}

///|
fn tt2_apply_xform_point(p : TtPoint, comp : Tt2Component) -> TtPoint {
  if !comp.have_xform {
    return p
  }
  let x = p.x
  let y = p.y
  let nx = tt_hint_mul_16_16(x, comp.xx16) + tt_hint_mul_16_16(y, comp.xy16)
  let ny = tt_hint_mul_16_16(x, comp.yx16) + tt_hint_mul_16_16(y, comp.yy16)
  TtPoint::{ x: nx, y: ny }
}

///|
fn tt2_component_offset_bits(
  comp : Tt2Component,
  scale_bits : Int,
  is_hinted : Bool,
  delta_x : Int,
  delta_y : Int,
) -> (Int, Int) {
  // Default: no deltas.
  let mut dx = 0.0
  let mut dy = 0.0
  match comp.anchor {
    Tt2Anchor::Offset(x, y) => {
      dx = x.to_double()
      dy = y.to_double()
    }
    _ => ()
  }
  if comp.have_xform &&
    (
      comp.flags &
      (COMPOSITE_SCALED_COMPONENT_OFFSET | COMPOSITE_UNSCALED_COMPONENT_OFFSET)
    ) ==
    COMPOSITE_SCALED_COMPONENT_OFFSET {
    // FreeType's guess-based scaling for composite offsets.
    dx = dx * glyf_hypot_guess(comp.xx, comp.xy)
    dy = dy * glyf_hypot_guess(comp.yy, comp.yx)
  }
  // For composite gvar deltas, FreeType/fontations round off fractional parts
  // and apply them in font units.
  dx = dx + delta_x.to_double()
  dy = dy + delta_y.to_double()
  let dx_bits = tt2_scale_funits_to_26_6(dx.to_int(), scale_bits)
  let mut dy_bits = tt2_scale_funits_to_26_6(dy.to_int(), scale_bits)
  if is_hinted && (comp.flags & COMPOSITE_ROUND_XY_TO_GRID) != 0 {
    // Only round the y-coordinate, per FreeType.
    dy_bits = tt2_round_grid_26_6(dy_bits)
  }
  (dx_bits, dy_bits)
}

///|
fn tt2_zone_outline_count(zone : TtZone) -> Int? {
  if zone.contours.is_empty() {
    Some(0)
  } else {
    let last_end = zone.contours.at(zone.contours.length() - 1)
    if last_end < 0 {
      None
    } else {
      Some(last_end + 1)
    }
  }
}

///|
fn tt2_zone_phantoms(
  zone : TtZone,
  outline_points : Int,
) -> (TtPoint, TtPoint, TtPoint, TtPoint)? {
  if outline_points < 0 || zone.points.length() < outline_points + 4 {
    return None
  }
  Some(
    (
      zone.points.at(outline_points),
      zone.points.at(outline_points + 1),
      zone.points.at(outline_points + 2),
      zone.points.at(outline_points + 3),
    ),
  )
}

///|
fn tt2_load_glyph_zone_for_hinting_impl(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  scale_bits : Int,
  tt : TtHintInstance,
  fpgm : BytesView,
  prep : BytesView,
  is_pedantic : Bool,
  depth : Int,
) -> Result[TtZone, DrawError] {
  if depth > 16 {
    return Err(DrawError::RecursionLimitExceeded(gid))
  }
  let glyph = match tt2_glyph_slice(font, gid) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if glyph.length() < 10 {
    return Err(DrawError::Read)
  }
  let number_of_contours = match tt2_read_i16_be(glyph, 0) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let x_min = match tt2_read_i16_be(glyph, 2) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let (aw, lsb) = tt2_hmtx_metrics(font, gid).unwrap_or((0, 0))
  let (os2_ascent, os2_descent) = tt2_os2_vmetrics(font)
  if number_of_contours >= 0 {
    let (zone0, code) = match
      tt2_decode_simple_glyph_for_hinting(
        glyph, scale_bits, aw, lsb, os2_ascent, os2_descent,
      ) {
      None => return Err(DrawError::Read)
      Some(v) => v
    }
    // Apply gvar deltas (including phantom points) for hinted glyph loading.
    if !coords.is_empty() {
      let point_count = match tt2_zone_outline_count(zone0) {
        None => return Err(DrawError::Read)
        Some(v) => v
      }
      let xs : Array[Double] = Array::new()
      let ys : Array[Double] = Array::new()
      for i in 0..<point_count {
        let p = zone0.unscaled.at(i)
        xs.push(p.x.to_double())
        ys.push(p.y.to_double())
      }
      match
        glyf_gvar_simple_hint_deltas(font, gid, coords, zone0.contours, xs, ys) {
        None => ()
        Some((dx_bits, dy_bits)) => {
          let total_points = point_count + 4
          // Recompute scaled points from unscaled + delta (preserving fractional parts),
          // then round phantom points if we will execute instructions.
          for i in 0..<total_points {
            let u = zone0.unscaled.at(i)
            let sx = tt2_scale_funits_plus_delta_fixed_to_26_6(
              u.x,
              dx_bits.at(i),
              scale_bits,
            )
            let sy = tt2_scale_funits_plus_delta_fixed_to_26_6(
              u.y,
              dy_bits.at(i),
              scale_bits,
            )
            zone0.original.set(i, TtPoint::{ x: sx, y: sy })
            zone0.points.set(i, TtPoint::{ x: sx, y: sy })
            if code.length() > 0 {
              // For hinting, adjust unscaled points by rounding off the deltas.
              zone0.unscaled.set(i, TtPoint::{
                x: u.x + gvar_fixed16_16_to_i32(dx_bits.at(i)),
                y: u.y + gvar_fixed16_16_to_i32(dy_bits.at(i)),
              })
            }
          }
          if code.length() > 0 {
            for i in 0..<4 {
              let p = zone0.points.at(point_count + i)
              zone0.points.set(point_count + i, TtPoint::{
                x: tt2_round_grid_26_6(p.x),
                y: tt2_round_grid_26_6(p.y),
              })
            }
          }
        }
      }
    }
    if code.length() == 0 {
      return Ok(zone0)
    }
    match
      tt.hint_glyph(
        fpgm,
        prep,
        code,
        zone0,
        false,
        is_pedantic,
        tt_fvar_axis_count(font),
        coords,
      ) {
      Err(e) => Err(DrawError::HintingFailed(e))
      Ok(z) => Ok(z)
    }
  } else {
    // Composite glyph: load components, apply transforms/offsets, then run
    // composite instructions (if present) with is_composite=true.
    let mut off = 10
    let comps : Array[Tt2Component] = Array::new()
    let mut flags_last = 0
    while true {
      flags_last = match tt2_read_u16_be(glyph, off) {
        None => return Err(DrawError::Read)
        Some(v) => v
      }
      let comp_gid_i = match tt2_read_u16_be(glyph, off + 2) {
        None => return Err(DrawError::Read)
        Some(v) => v
      }
      off = off + 4
      let arg_words = (flags_last & COMPOSITE_ARG_1_AND_2_ARE_WORDS) != 0
      let args_xy = (flags_last & COMPOSITE_ARGS_ARE_XY_VALUES) != 0
      let anchor = if arg_words {
        if args_xy {
          let v1 = match tt2_read_i16_be(glyph, off) {
            None => return Err(DrawError::Read)
            Some(v) => v
          }
          let v2 = match tt2_read_i16_be(glyph, off + 2) {
            None => return Err(DrawError::Read)
            Some(v) => v
          }
          off = off + 4
          Tt2Anchor::Offset(v1, v2)
        } else {
          let v1 = match tt2_read_u16_be(glyph, off) {
            None => return Err(DrawError::Read)
            Some(v) => v
          }
          let v2 = match tt2_read_u16_be(glyph, off + 2) {
            None => return Err(DrawError::Read)
            Some(v) => v
          }
          off = off + 4
          Tt2Anchor::Point(v1, v2)
        }
      } else {
        if off + 2 > glyph.length() {
          return Err(DrawError::Read)
        }
        let b1 = glyph.at(off).to_int()
        let b2 = glyph.at(off + 1).to_int()
        off = off + 2
        if args_xy {
          let v1 = if b1 >= 128 { b1 - 256 } else { b1 }
          let v2 = if b2 >= 128 { b2 - 256 } else { b2 }
          Tt2Anchor::Offset(v1, v2)
        } else {
          Tt2Anchor::Point(b1, b2)
        }
      }
      let mut xx14 = 0x4000
      let mut yy14 = 0x4000
      let mut xy14 = 0
      let mut yx14 = 0
      let mut have_xform = false
      if (flags_last & COMPOSITE_WE_HAVE_A_SCALE) != 0 {
        let s = match tt2_read_f2dot14_bits(glyph, off) {
          None => return Err(DrawError::Read)
          Some(v) => v
        }
        off = off + 2
        xx14 = s
        yy14 = s
        have_xform = true
      } else if (flags_last & COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
        let sx = match tt2_read_f2dot14_bits(glyph, off) {
          None => return Err(DrawError::Read)
          Some(v) => v
        }
        let sy = match tt2_read_f2dot14_bits(glyph, off + 2) {
          None => return Err(DrawError::Read)
          Some(v) => v
        }
        off = off + 4
        xx14 = sx
        yy14 = sy
        have_xform = true
      } else if (flags_last & COMPOSITE_WE_HAVE_A_TWO_BY_TWO) != 0 {
        let a = match tt2_read_f2dot14_bits(glyph, off) {
          None => return Err(DrawError::Read)
          Some(v) => v
        }
        let b = match tt2_read_f2dot14_bits(glyph, off + 2) {
          None => return Err(DrawError::Read)
          Some(v) => v
        }
        let c = match tt2_read_f2dot14_bits(glyph, off + 4) {
          None => return Err(DrawError::Read)
          Some(v) => v
        }
        let d = match tt2_read_f2dot14_bits(glyph, off + 6) {
          None => return Err(DrawError::Read)
          Some(v) => v
        }
        off = off + 8
        xx14 = a
        yx14 = b
        xy14 = c
        yy14 = d
        have_xform = true
      }
      comps.push(Tt2Component::{
        flags: flags_last,
        gid: @moon_skrifa.GlyphId::new(comp_gid_i.to_uint16()),
        anchor,
        xx16: tt2_f2dot14_to_16_16(xx14),
        yx16: tt2_f2dot14_to_16_16(yx14),
        xy16: tt2_f2dot14_to_16_16(xy14),
        yy16: tt2_f2dot14_to_16_16(yy14),
        have_xform,
        xx: tt2_f2dot14_to_double(xx14),
        yx: tt2_f2dot14_to_double(yx14),
        xy: tt2_f2dot14_to_double(xy14),
        yy: tt2_f2dot14_to_double(yy14),
      })
      if (flags_last & COMPOSITE_MORE_COMPONENTS) == 0 {
        break
      }
    }
    let ins_len = if (flags_last & COMPOSITE_WE_HAVE_INSTRUCTIONS) != 0 {
      if off + 2 > glyph.length() {
        return Err(DrawError::Read)
      }
      let n = match tt2_read_u16_be(glyph, off) {
        None => return Err(DrawError::Read)
        Some(v) => v
      }
      off = off + 2
      if n < 0 || off + n > glyph.length() {
        return Err(DrawError::Read)
      }
      n
    } else {
      0
    }
    let ins = if ins_len > 0 {
      glyph.sub(start=off, end=off + ins_len)
    } else {
      glyph.sub(start=off, end=off)
    }
    // Precompute composite gvar deltas (component offsets + phantoms).
    let comp_deltas = match
      glyf_gvar_composite_hint_deltas(font, gid, coords, comps.length()) {
      None => None
      Some((dx, dy)) => Some((dx, dy))
    }
    let phantom0_x = x_min - lsb
    let phantom1_x = phantom0_x + aw
    // Match fontations/FreeType vmetrics shape (see glyf scaler).
    let phantom2_y = os2_ascent
    let phantom3_y = os2_descent
    // Apply gvar phantom deltas in font units before scaling (rounded).
    let mut ph0_x_f = phantom0_x
    let mut ph0_y_f = 0
    let mut ph1_x_f = phantom1_x
    let mut ph1_y_f = 0
    let mut ph2_x_f = 0
    let mut ph2_y_f = phantom2_y
    let mut ph3_x_f = 0
    let mut ph3_y_f = phantom3_y
    match comp_deltas {
      None => ()
      Some((dx_bits, dy_bits)) => {
        let base = comps.length()
        if base + 3 < dx_bits.length() && base + 3 < dy_bits.length() {
          ph0_x_f = ph0_x_f + gvar_fixed16_16_to_i32(dx_bits.at(base))
          ph0_y_f = ph0_y_f + gvar_fixed16_16_to_i32(dy_bits.at(base))
          ph1_x_f = ph1_x_f + gvar_fixed16_16_to_i32(dx_bits.at(base + 1))
          ph1_y_f = ph1_y_f + gvar_fixed16_16_to_i32(dy_bits.at(base + 1))
          ph2_x_f = ph2_x_f + gvar_fixed16_16_to_i32(dx_bits.at(base + 2))
          ph2_y_f = ph2_y_f + gvar_fixed16_16_to_i32(dy_bits.at(base + 2))
          ph3_x_f = ph3_x_f + gvar_fixed16_16_to_i32(dx_bits.at(base + 3))
          ph3_y_f = ph3_y_f + gvar_fixed16_16_to_i32(dy_bits.at(base + 3))
        }
      }
    }
    // Scale to 26.6.
    let mut ph0 = TtPoint::{
      x: tt2_scale_funits_to_26_6(ph0_x_f, scale_bits),
      y: tt2_scale_funits_to_26_6(ph0_y_f, scale_bits),
    }
    let mut ph1 = TtPoint::{
      x: tt2_scale_funits_to_26_6(ph1_x_f, scale_bits),
      y: tt2_scale_funits_to_26_6(ph1_y_f, scale_bits),
    }
    let mut ph2 = TtPoint::{
      x: tt2_scale_funits_to_26_6(ph2_x_f, scale_bits),
      y: tt2_scale_funits_to_26_6(ph2_y_f, scale_bits),
    }
    let mut ph3 = TtPoint::{
      x: tt2_scale_funits_to_26_6(ph3_x_f, scale_bits),
      y: tt2_scale_funits_to_26_6(ph3_y_f, scale_bits),
    }
    let points_out : Array[TtPoint] = Array::new()
    let flags_out : Array[Int] = Array::new()
    let contours_out : Array[Int] = Array::new()
    let mut base_point = 0
    for i in 0..<comps.length() {
      let comp = comps.at(i)
      // Load component zone (may be simple or composite).
      let zone_c = match
        tt2_load_glyph_zone_for_hinting_impl(
          font,
          comp.gid,
          coords,
          scale_bits,
          tt,
          fpgm,
          prep,
          is_pedantic,
          depth + 1,
        ) {
        Err(e) => return Err(e)
        Ok(z) => z
      }
      let outline_n = match tt2_zone_outline_count(zone_c) {
        None => return Err(DrawError::Read)
        Some(v) => v
      }
      let (cph0, cph1, cph2, cph3) = match
        tt2_zone_phantoms(zone_c, outline_n) {
        None => return Err(DrawError::Read)
        Some(v) => v
      }
      if (comp.flags & TT2_COMPOSITE_USE_MY_METRICS) != 0 {
        ph0 = cph0
        ph1 = cph1
        ph2 = cph2
        ph3 = cph3
      }
      // Extract component outline points and flags.
      let comp_points : Array[TtPoint] = Array::new()
      let comp_flags : Array[Int] = Array::new()
      for j in 0..<outline_n {
        comp_points.push(zone_c.points.at(j))
        // Clear touched bits before composite processing.
        comp_flags.push(zone_c.flags.at(j) & TT_POINT_ON_CURVE)
      }
      // Apply transform.
      if comp.have_xform {
        for j in 0..<comp_points.length() {
          comp_points.set(j, tt2_apply_xform_point(comp_points.at(j), comp))
        }
      }
      // Compute anchor offset.
      let (ox, oy) = match comp.anchor {
        Tt2Anchor::Offset(_, _) => {
          let mut dx = 0
          let mut dy = 0
          match comp_deltas {
            None => ()
            Some((dx_bits, dy_bits)) =>
              if i < dx_bits.length() && i < dy_bits.length() {
                dx = gvar_fixed16_16_to_i32(dx_bits.at(i))
                dy = gvar_fixed16_16_to_i32(dy_bits.at(i))
              }
          }
          tt2_component_offset_bits(comp, scale_bits, true, dx, dy)
        }
        Tt2Anchor::Point(base, component) => {
          if base < 0 || base >= points_out.length() {
            return Err(DrawError::InvalidAnchorPoint(gid, base.to_uint16()))
          }
          if component < 0 || component >= comp_points.length() {
            return Err(
              DrawError::InvalidAnchorPoint(gid, component.to_uint16()),
            )
          }
          let bp = points_out.at(base)
          let cp = comp_points.at(component)
          (bp.x - cp.x, bp.y - cp.y)
        }
      }
      if ox != 0 || oy != 0 {
        for j in 0..<comp_points.length() {
          let p = comp_points.at(j)
          comp_points.set(j, TtPoint::{ x: p.x + ox, y: p.y + oy })
        }
      }
      // Append points and contours.
      for p in comp_points.iter() {
        points_out.push(p)
      }
      for f in comp_flags.iter() {
        flags_out.push(f)
      }
      for end_ix in zone_c.contours.iter() {
        if end_ix >= 0 {
          contours_out.push(end_ix + base_point)
        }
      }
      base_point = points_out.length()
    }
    let total_points = points_out.length() + 4
    let unscaled : Array[TtPoint] = Array::make(total_points, TtPoint::{
      x: 0,
      y: 0,
    })
    let original : Array[TtPoint] = Array::make(total_points, TtPoint::{
      x: 0,
      y: 0,
    })
    let points : Array[TtPoint] = Array::make(total_points, TtPoint::{
      x: 0,
      y: 0,
    })
    let flags : Array[Int] = Array::make(total_points, 0)
    for i in 0..<points_out.length() {
      let p = points_out.at(i)
      unscaled.set(i, p)
      original.set(i, p)
      points.set(i, p)
      flags.set(i, flags_out.at(i))
    }
    // Append phantom points (already scaled).
    unscaled.set(points_out.length(), ph0)
    unscaled.set(points_out.length() + 1, ph1)
    unscaled.set(points_out.length() + 2, ph2)
    unscaled.set(points_out.length() + 3, ph3)
    original.set(points_out.length(), ph0)
    original.set(points_out.length() + 1, ph1)
    original.set(points_out.length() + 2, ph2)
    original.set(points_out.length() + 3, ph3)
    points.set(points_out.length(), ph0)
    points.set(points_out.length() + 1, ph1)
    points.set(points_out.length() + 2, ph2)
    points.set(points_out.length() + 3, ph3)
    flags.set(points_out.length(), 0)
    flags.set(points_out.length() + 1, 0)
    flags.set(points_out.length() + 2, 0)
    flags.set(points_out.length() + 3, 0)
    // Round phantom points before running composite instructions.
    if ins.length() > 0 {
      for i in 0..<4 {
        let p = points.at(points_out.length() + i)
        points.set(points_out.length() + i, TtPoint::{
          x: tt2_round_grid_26_6(p.x),
          y: tt2_round_grid_26_6(p.y),
        })
      }
    }
    let zone0 = TtZone::{
      unscaled,
      original,
      points,
      flags,
      contours: contours_out,
    }
    if ins.length() == 0 {
      return Ok(zone0)
    }
    match
      tt.hint_glyph(
        fpgm,
        prep,
        ins,
        zone0,
        true,
        is_pedantic,
        tt_fvar_axis_count(font),
        coords,
      ) {
      Err(e) => Err(DrawError::HintingFailed(e))
      Ok(z) => Ok(z)
    }
  }
}

///|
fn tt_load_glyph_zone_for_hinting(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  scale_bits : Int,
  tt : TtHintInstance,
  fpgm : BytesView,
  prep : BytesView,
  is_pedantic : Bool,
) -> Result[TtZone, DrawError] {
  let maxp = match font.table(TAG_MAXP_TT2) {
    None => return Err(DrawError::Read)
    Some(v) => v
  }
  let num_glyphs = tt2_read_u16_be(maxp, 4).unwrap_or(0)
  if num_glyphs <= 0 {
    return Err(DrawError::Read)
  }
  tt2_load_glyph_zone_for_hinting_impl(
    font, gid, coords, scale_bits, tt, fpgm, prep, is_pedantic, 0,
  )
}
