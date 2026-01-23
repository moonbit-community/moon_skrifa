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
/// TrueType outlines from the `glyf` table (MVP).
///
/// This only supports simple glyphs (contour streams) for now.
const TAG_HEAD : UInt = 0x68656164 // "head"

///|
const TAG_LOCA : UInt = 0x6C6F6361 // "loca"

///|
const TAG_MAXP : UInt = 0x6D617870 // "maxp"

///|
fn glyf_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn glyf_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match glyf_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
fn glyf_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn glyf_midpoint(a : (Int, Int), b : (Int, Int)) -> (Int, Int) {
  let (ax, ay) = a
  let (bx, by) = b
  ((ax + bx) / 2, (ay + by) / 2)
}

///|
priv struct GlyfPoint {
  x : Int
  y : Int
  on : Bool
}

///|
fn glyf_emit_contour(
  out : Array[PathElement],
  points : ArrayView[GlyfPoint],
  start : Int,
  end : Int,
) -> Unit {
  let n = end - start + 1
  if n <= 0 {
    return
  }
  let first = points.at(start)
  let last = points.at(end)
  let (sx, sy, start_idx) = if first.on {
    (first.x, first.y, start)
  } else if last.on {
    (last.x, last.y, end)
  } else {
    let (mx, my) = glyf_midpoint((last.x, last.y), (first.x, first.y))
    (mx, my, -1)
  }
  out.push(MoveTo(sx, sy))
  let mut control : (Int, Int)? = None
  let mut px = sx
  let mut py = sy
  if start_idx == -1 {
    for i in start..<(end + 1) {
      let p = points.at(i)
      if p.on {
        match control {
          None => out.push(LineTo(p.x, p.y))
          Some((cx, cy)) => {
            out.push(QuadTo(cx, cy, p.x, p.y))
            control = None
          }
        }
        px = p.x
        py = p.y
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let (mx, my) = glyf_midpoint((cx, cy), (p.x, p.y))
            out.push(QuadTo(cx, cy, mx, my))
            control = Some((p.x, p.y))
            px = mx
            py = my
          }
        }
      }
    }
  } else {
    let base = start_idx - start
    for step in 1..<n {
      let idx = start + (base + step) % n
      let p = points.at(idx)
      if p.on {
        match control {
          None => out.push(LineTo(p.x, p.y))
          Some((cx, cy)) => {
            out.push(QuadTo(cx, cy, p.x, p.y))
            control = None
          }
        }
        px = p.x
        py = p.y
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let (mx, my) = glyf_midpoint((cx, cy), (p.x, p.y))
            out.push(QuadTo(cx, cy, mx, my))
            control = Some((p.x, p.y))
            px = mx
            py = my
          }
        }
      }
    }
  }
  match control {
    Some((cx, cy)) => out.push(QuadTo(cx, cy, sx, sy))
    None => if px != sx || py != sy { out.push(LineTo(sx, sy)) }
  }
  out.push(Close)
}

///|
fn glyf_simple_path(glyf : BytesView) -> Array[PathElement]? {
  let number_of_contours = match glyf_read_i16_be(glyf, 0) {
    None => return None
    Some(v) => v
  }
  if number_of_contours == 0 {
    return Some(Array::new())
  }
  if number_of_contours < 0 {
    // Composite glyphs are not supported by this MVP.
    return None
  }
  // Skip bbox (xMin..yMax).
  let mut off = 10
  let end_pts : Array[Int] = Array::new()
  for _ in 0..<number_of_contours {
    let v = match glyf_read_u16_be(glyf, off) {
      None => return None
      Some(u) => u
    }
    end_pts.push(v)
    off = off + 2
  }
  let instruction_len = match glyf_read_u16_be(glyf, off) {
    None => return None
    Some(v) => v
  }
  off = off + 2
  if instruction_len < 0 || off + instruction_len > glyf.length() {
    return None
  }
  off = off + instruction_len
  let last_end = end_pts.at(end_pts.length() - 1)
  let num_points = last_end + 1
  if num_points <= 0 {
    return Some(Array::new())
  }

  // Flags stream.
  let flags : Array[Int] = Array::new()
  while flags.length() < num_points {
    if off >= glyf.length() {
      return None
    }
    let flag = glyf.at(off).to_int()
    off = off + 1
    flags.push(flag)
    if (flag & 0x08) != 0 {
      if off >= glyf.length() {
        return None
      }
      let repeat = glyf.at(off).to_int()
      off = off + 1
      for _ in 0..<repeat {
        flags.push(flag)
      }
    }
  }

  // Decode coordinates.
  let points : Array[GlyfPoint] = Array::new()
  let mut x = 0
  let mut y = 0
  // x deltas
  let dxs : Array[Int] = Array::new()
  for i in 0..<num_points {
    let f = flags.at(i)
    let short = (f & 0x02) != 0
    let same = (f & 0x10) != 0
    if short {
      if off >= glyf.length() {
        return None
      }
      let b = glyf.at(off).to_int()
      off = off + 1
      dxs.push(if same { b } else { -b })
    } else if same {
      dxs.push(0)
    } else {
      let d = match glyf_read_i16_be(glyf, off) {
        None => return None
        Some(v) => v
      }
      off = off + 2
      dxs.push(d)
    }
  }
  // y deltas
  let dys : Array[Int] = Array::new()
  for i in 0..<num_points {
    let f = flags.at(i)
    let short = (f & 0x04) != 0
    let same = (f & 0x20) != 0
    if short {
      if off >= glyf.length() {
        return None
      }
      let b = glyf.at(off).to_int()
      off = off + 1
      dys.push(if same { b } else { -b })
    } else if same {
      dys.push(0)
    } else {
      let d = match glyf_read_i16_be(glyf, off) {
        None => return None
        Some(v) => v
      }
      off = off + 2
      dys.push(d)
    }
  }
  for i in 0..<num_points {
    x = x + dxs.at(i)
    y = y + dys.at(i)
    let on = (flags.at(i) & 0x01) != 0
    points.push(GlyfPoint::{ x, y, on })
  }

  // Convert contours into path elements.
  let out : Array[PathElement] = Array::new()
  let mut contour_start = 0
  for c in 0..<number_of_contours {
    let contour_end = end_pts.at(c)
    if contour_end < contour_start || contour_end >= points.length() {
      return None
    }
    glyf_emit_contour(out, points.op_as_view(), contour_start, contour_end)
    contour_start = contour_end + 1
  }
  Some(out)
}

///|
fn glyf_outline_path(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> Array[PathElement]? {
  let glyf = match font.table(TAG_GLYF) {
    None => return None
    Some(v) => v
  }
  let maxp = match font.table(TAG_MAXP) {
    None => return None
    Some(v) => v
  }
  let head = match font.table(TAG_HEAD) {
    None => return None
    Some(v) => v
  }
  let loca = match font.table(TAG_LOCA) {
    None => return None
    Some(v) => v
  }
  let num_glyphs = match glyf_read_u16_be(maxp, 4) {
    None => return None
    Some(v) => v
  }
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= num_glyphs {
    return None
  }
  let index_to_loc_format = match glyf_read_i16_be(head, 50) {
    None => return None
    Some(v) => v
  }
  let (start, end) = if index_to_loc_format == 0 {
    // short offsets: u16 values multiplied by 2
    let need = (num_glyphs + 1) * 2
    if loca.length() < need {
      return None
    }
    let o0 = match glyf_read_u16_be(loca, idx * 2) {
      None => return None
      Some(v) => v
    }
    let o1 = match glyf_read_u16_be(loca, (idx + 1) * 2) {
      None => return None
      Some(v) => v
    }
    (o0 * 2, o1 * 2)
  } else if index_to_loc_format == 1 {
    let need = (num_glyphs + 1) * 4
    if loca.length() < need {
      return None
    }
    let o0 = match glyf_read_u32_be(loca, idx * 4) {
      None => return None
      Some(v) => v.to_uint64().to_int()
    }
    let o1 = match glyf_read_u32_be(loca, (idx + 1) * 4) {
      None => return None
      Some(v) => v.to_uint64().to_int()
    }
    (o0, o1)
  } else {
    return None
  }
  if start < 0 || end < start || end > glyf.length() {
    return None
  }
  if start == end {
    return Some(Array::new())
  }
  glyf_simple_path(glyf.sub(start~, end~))
}
