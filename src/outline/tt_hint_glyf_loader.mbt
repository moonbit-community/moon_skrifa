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
) -> BytesView? {
  let head = match font.table(TAG_HEAD_TT) {
    None => return None
    Some(v) => v
  }
  let loca = match font.table(TAG_LOCA_TT) {
    None => return None
    Some(v) => v
  }
  let glyf = match font.table(TAG_GLYF_TT) {
    None => return None
    Some(v) => v
  }
  let maxp = match font.table(TAG_MAXP_TT2) {
    None => return None
    Some(v) => v
  }
  let num_glyphs = tt2_read_u16_be(maxp, 4).unwrap_or(0)
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= num_glyphs {
    return None
  }
  let index_to_loc_format = tt2_read_i16_be(head, 50).unwrap_or(0)
  let (start, end) = if index_to_loc_format == 0 {
    let need = (num_glyphs + 1) * 2
    if loca.length() < need {
      return None
    }
    let o0 = tt2_read_u16_be(loca, idx * 2).unwrap_or(0) * 2
    let o1 = tt2_read_u16_be(loca, (idx + 1) * 2).unwrap_or(0) * 2
    (o0, o1)
  } else {
    let need = (num_glyphs + 1) * 4
    if loca.length() < need {
      return None
    }
    let o0 = tt2_read_u32_be(loca, idx * 4).unwrap_or(0).to_uint64().to_int()
    let o1 = tt2_read_u32_be(loca, (idx + 1) * 4)
      .unwrap_or(0)
      .to_uint64()
      .to_int()
    (o0, o1)
  }
  if start < 0 || end < start || end > glyf.length() {
    None
  } else {
    Some(glyf.sub(start~, end~))
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
  if number_of_contours <= 0 {
    return None
  }
  let x_min = tt2_read_i16_be(glyph, 2).unwrap_or(0)
  let mut off = 10
  let contours : Array[Int] = Array::new()
  for _ in 0..<number_of_contours {
    let v = tt2_read_u16_be(glyph, off).unwrap_or(0)
    contours.push(v)
    off = off + 2
  }
  let instruction_len = tt2_read_u16_be(glyph, off).unwrap_or(0)
  off = off + 2
  if instruction_len < 0 || off + instruction_len > glyph.length() {
    return None
  }
  let instr = glyph.sub(start=off, end=off + instruction_len)
  off = off + instruction_len
  let last_end = contours.at(contours.length() - 1)
  let num_points = last_end + 1
  if num_points <= 0 {
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
  for i in 0..<4 {
    let p = points.at(num_points + i)
    points.set(num_points + i, TtPoint::{
      x: tt2_round_grid_26_6(p.x),
      y: tt2_round_grid_26_6(p.y),
    })
  }
  let zone = TtZone::{ unscaled, original, points, flags, contours }
  Some((zone, instr))
}

///|
fn tt_load_simple_glyph_zone_for_hinting(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  scale_bits : Int,
) -> (TtZone, BytesView)? {
  let glyph = match tt2_glyph_slice(font, gid) {
    None => return None
    Some(v) => v
  }
  let (aw, lsb) = tt2_hmtx_metrics(font, gid).unwrap_or((0, 0))
  let (os2_ascent, os2_descent) = tt2_os2_vmetrics(font)
  tt2_decode_simple_glyph_for_hinting(
    glyph, scale_bits, aw, lsb, os2_ascent, os2_descent,
  )
}
