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
const COMPOSITE_ARG_1_AND_2_ARE_WORDS : Int = 0x0001

///|
const COMPOSITE_ARGS_ARE_XY_VALUES : Int = 0x0002

///|
const COMPOSITE_ROUND_XY_TO_GRID : Int = 0x0004

///|
const COMPOSITE_WE_HAVE_A_SCALE : Int = 0x0008

///|
const COMPOSITE_MORE_COMPONENTS : Int = 0x0020

///|
const COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE : Int = 0x0040

///|
const COMPOSITE_WE_HAVE_A_TWO_BY_TWO : Int = 0x0080

///|
const COMPOSITE_WE_HAVE_INSTRUCTIONS : Int = 0x0100

///|
const COMPOSITE_OVERLAP_COMPOUND : Int = 0x0400

///|
const COMPOSITE_SCALED_COMPONENT_OFFSET : Int = 0x0800

///|
const COMPOSITE_UNSCALED_COMPONENT_OFFSET : Int = 0x1000

///|
const SIMPLE_OVERLAP_FLAG : Int = 0x40

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
fn glyf_read_f2dot14(view : BytesView, offset : Int) -> Double? {
  match glyf_read_i16_be(view, offset) {
    None => None
    Some(v) => Some(v.to_double() / 16384.0)
  }
}

///|
fn glyf_units_per_em(font : @moon_skrifa.FontRef) -> UInt16 {
  match font.table(TAG_HEAD) {
    None => 0
    Some(head) =>
      match glyf_read_u16_be(head, 18) {
        None => 0
        Some(v) => v.to_uint16()
      }
  }
}

///|
fn glyf_compute_scale_bits(
  size : @moon_skrifa.Size,
  upem : UInt16,
) -> (Bool, Int) {
  match size.ppem() {
    None => (false, 0x10000)
    Some(ppem) => {
      let upem_i = upem.to_int()
      if upem_i <= 0 {
        (false, 0x10000)
      } else {
        // Matches the reference compute_scale() shape without relying on Int64
        // (works around wasm-gc toolchain crashes in some environments).
        let a = (ppem * 64.0).to_int()
        let q = (a.to_double() * 65536.0 / upem_i.to_double()).round().to_int()
        (true, q)
      }
    }
  }
}

///|
fn glyf_mul_16_16(v : Int, scale_bits : Int) -> Int {
  (v.to_double() * scale_bits.to_double() / 65536.0).round().to_int()
}

///|
fn glyf_mul_16_16_f(v : Double, scale_bits : Int) -> Int {
  (v * scale_bits.to_double() / 65536.0).round().to_int()
}

///|
fn glyf_f26dot6_bits_to_double(bits : Int) -> Double {
  bits.to_double() / 64.0
}

///|
fn glyf_midpoint_i32(a : Int, b : Int) -> Int {
  // Matches read-fonts midpoint_i32: a.wrapping_add(b) / 2.
  (a + b) / 2
}

///|
priv struct GlyfTransform {
  a : Double
  b : Double
  c : Double
  d : Double
  dx : Double
  dy : Double
}

///|
priv struct GlyfCompositeComp {
  flags : Int
  gid : Int
  dx : Double
  dy : Double
  a : Double
  b : Double
  c : Double
  d : Double
  have_xform : Bool
}

///|
/// FreeType's "guess" for hypot(a, b) used when scaling composite anchor
/// offsets (see fontations-reference).
fn glyf_hypot_guess(a : Double, b : Double) -> Double {
  let aa = a.abs()
  let bb = b.abs()
  if aa > bb {
    aa + 3.0 * bb / 8.0
  } else {
    bb + 3.0 * aa / 8.0
  }
}

///|
fn glyf_transform_point(
  t : GlyfTransform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  (t.a * x + t.b * y + t.dx, t.c * x + t.d * y + t.dy)
}

///|
fn glyf_apply_transform(
  path : Array[PathElement],
  t : GlyfTransform,
) -> Array[PathElement] {
  let out : Array[PathElement] = Array::new()
  for e in path {
    match e {
      MoveTo(x, y) => {
        let (nx, ny) = glyf_transform_point(t, x, y)
        out.push(MoveTo(nx, ny))
      }
      LineTo(x, y) => {
        let (nx, ny) = glyf_transform_point(t, x, y)
        out.push(LineTo(nx, ny))
      }
      QuadTo(cx, cy, x, y) => {
        let (ncx, ncy) = glyf_transform_point(t, cx, cy)
        let (nx, ny) = glyf_transform_point(t, x, y)
        out.push(QuadTo(ncx, ncy, nx, ny))
      }
      CurveTo(cx0, cy0, cx1, cy1, x, y) => {
        let (ncx0, ncy0) = glyf_transform_point(t, cx0, cy0)
        let (ncx1, ncy1) = glyf_transform_point(t, cx1, cy1)
        let (nx, ny) = glyf_transform_point(t, x, y)
        out.push(CurveTo(ncx0, ncy0, ncx1, ncy1, nx, ny))
      }
      Close => out.push(Close)
    }
  }
  out
}

///|
priv struct GlyfPoint {
  x : Int
  y : Int
  on : Bool
}

///|
priv struct GlyfPointF {
  x : Double
  y : Double
  on : Bool
}

///|
priv struct GlyfPointFT {
  x : Int
  y : Int
  on : Bool
}

///|
fn glyf_emit_contour_harfbuzz(
  out : Array[PathElement],
  points : ArrayView[GlyfPointF],
  start : Int,
  end : Int,
  path_style : PathStyle,
) -> Unit {
  let n = end - start + 1
  if n <= 0 {
    return
  }
  let first = points.at(start)
  let last = points.at(end)
  let (sx, sy, start_idx) = if first.on {
    (first.x, first.y, start)
  } else {
    match path_style {
      PathStyle::FreeType =>
        if last.on {
          (last.x, last.y, end)
        } else {
          let mx = (last.x + first.x) / 2.0
          let my = (last.y + first.y) / 2.0
          (mx, my, -1)
        }
      PathStyle::HarfBuzz =>
        if n >= 2 {
          let second = points.at(start + 1)
          if second.on {
            (second.x, second.y, start + 1)
          } else {
            let mx = (first.x + second.x) / 2.0
            let my = (first.y + second.y) / 2.0
            (mx, my, -1)
          }
        } else {
          (first.x, first.y, start)
        }
    }
  }
  out.push(MoveTo(sx, sy))
  let mut control : (Double, Double)? = None
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
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let mx = (cx + p.x) / 2.0
            let my = (cy + p.y) / 2.0
            out.push(QuadTo(cx, cy, mx, my))
            control = Some((p.x, p.y))
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
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let mx = (cx + p.x) / 2.0
            let my = (cy + p.y) / 2.0
            out.push(QuadTo(cx, cy, mx, my))
            control = Some((p.x, p.y))
          }
        }
      }
    }
  }
  match control {
    Some((cx, cy)) => out.push(QuadTo(cx, cy, sx, sy))
    None => ()
  }
  out.push(Close)
}

///|
fn glyf_emit_contour_freetype(
  out : Array[PathElement],
  points : ArrayView[GlyfPointFT],
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
    (glyf_midpoint_i32(last.x, first.x), glyf_midpoint_i32(last.y, first.y), -1)
  }
  out.push(
    MoveTo(glyf_f26dot6_bits_to_double(sx), glyf_f26dot6_bits_to_double(sy)),
  )
  let mut control : (Int, Int)? = None
  if start_idx == -1 {
    for i in start..<(end + 1) {
      let p = points.at(i)
      if p.on {
        match control {
          None =>
            out.push(
              LineTo(
                glyf_f26dot6_bits_to_double(p.x),
                glyf_f26dot6_bits_to_double(p.y),
              ),
            )
          Some((cx, cy)) => {
            out.push(
              QuadTo(
                glyf_f26dot6_bits_to_double(cx),
                glyf_f26dot6_bits_to_double(cy),
                glyf_f26dot6_bits_to_double(p.x),
                glyf_f26dot6_bits_to_double(p.y),
              ),
            )
            control = None
          }
        }
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let mx = glyf_midpoint_i32(cx, p.x)
            let my = glyf_midpoint_i32(cy, p.y)
            out.push(
              QuadTo(
                glyf_f26dot6_bits_to_double(cx),
                glyf_f26dot6_bits_to_double(cy),
                glyf_f26dot6_bits_to_double(mx),
                glyf_f26dot6_bits_to_double(my),
              ),
            )
            control = Some((p.x, p.y))
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
          None =>
            out.push(
              LineTo(
                glyf_f26dot6_bits_to_double(p.x),
                glyf_f26dot6_bits_to_double(p.y),
              ),
            )
          Some((cx, cy)) => {
            out.push(
              QuadTo(
                glyf_f26dot6_bits_to_double(cx),
                glyf_f26dot6_bits_to_double(cy),
                glyf_f26dot6_bits_to_double(p.x),
                glyf_f26dot6_bits_to_double(p.y),
              ),
            )
            control = None
          }
        }
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let mx = glyf_midpoint_i32(cx, p.x)
            let my = glyf_midpoint_i32(cy, p.y)
            out.push(
              QuadTo(
                glyf_f26dot6_bits_to_double(cx),
                glyf_f26dot6_bits_to_double(cy),
                glyf_f26dot6_bits_to_double(mx),
                glyf_f26dot6_bits_to_double(my),
              ),
            )
            control = Some((p.x, p.y))
          }
        }
      }
    }
  }
  match control {
    Some((cx, cy)) =>
      out.push(
        QuadTo(
          glyf_f26dot6_bits_to_double(cx),
          glyf_f26dot6_bits_to_double(cy),
          glyf_f26dot6_bits_to_double(sx),
          glyf_f26dot6_bits_to_double(sy),
        ),
      )
    None => ()
  }
  out.push(Close)
}

///|
fn glyf_simple_path(
  ctx : GlyfCtx,
  glyph : BytesView,
  gid : @moon_skrifa.GlyphId,
  path_style : PathStyle,
) -> Array[PathElement]? {
  let number_of_contours = match glyf_read_i16_be(glyph, 0) {
    None => return None
    Some(v) => v
  }
  if number_of_contours == 0 {
    return Some(Array::new())
  }
  if number_of_contours < 0 {
    // Handled by composite parsing.
    return None
  }
  // Skip bbox (xMin..yMax).
  let mut off = 10
  let end_pts : Array[Int] = Array::new()
  for _ in 0..<number_of_contours {
    let v = match glyf_read_u16_be(glyph, off) {
      None => return None
      Some(u) => u
    }
    end_pts.push(v)
    off = off + 2
  }
  let instruction_len = match glyf_read_u16_be(glyph, off) {
    None => return None
    Some(v) => v
  }
  off = off + 2
  if instruction_len < 0 || off + instruction_len > glyph.length() {
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
    if off >= glyph.length() {
      return None
    }
    let flag = glyph.at(off).to_int()
    off = off + 1
    flags.push(flag)
    if (flag & 0x08) != 0 {
      if off >= glyph.length() {
        return None
      }
      let repeat = glyph.at(off).to_int()
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
      if off >= glyph.length() {
        return None
      }
      let b = glyph.at(off).to_int()
      off = off + 1
      dxs.push(if same { b } else { -b })
    } else if same {
      dxs.push(0)
    } else {
      let d = match glyf_read_i16_be(glyph, off) {
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
      if off >= glyph.length() {
        return None
      }
      let b = glyph.at(off).to_int()
      off = off + 1
      dys.push(if same { b } else { -b })
    } else if same {
      dys.push(0)
    } else {
      let d = match glyf_read_i16_be(glyph, off) {
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

  // Apply gvar deltas (simple glyphs only) before converting to path.
  let xs : Array[Double] = Array::new()
  let ys : Array[Double] = Array::new()
  for p in points.iter() {
    xs.push(p.x.to_double())
    ys.push(p.y.to_double())
  }
  glyf_apply_gvar_simple(ctx.font, gid, ctx.coords, end_pts, xs, ys)

  // Convert contours into path elements.
  let out : Array[PathElement] = Array::new()
  match path_style {
    PathStyle::FreeType => {
      // In FreeType mode, points are stored in 26.6 fixed (as Int bits).
      let scaled : Array[GlyfPointFT] = Array::new()
      for i in 0..<points.length() {
        let p = points.at(i)
        let x_du = xs.at(i)
        let y_du = ys.at(i)
        let x_bits = if ctx.is_scaled {
          glyf_mul_16_16_f(x_du, ctx.scale_bits)
        } else {
          (x_du * 64.0).round().to_int()
        }
        let y_bits = if ctx.is_scaled {
          glyf_mul_16_16_f(y_du, ctx.scale_bits)
        } else {
          (y_du * 64.0).round().to_int()
        }
        scaled.push(GlyfPointFT::{ x: x_bits, y: y_bits, on: p.on })
      }
      let mut contour_start = 0
      for c in 0..<number_of_contours {
        let contour_end = end_pts.at(c)
        if contour_end < contour_start || contour_end >= scaled.length() {
          return None
        }
        glyf_emit_contour_freetype(
          out,
          scaled.op_as_view(),
          contour_start,
          contour_end,
        )
        contour_start = contour_end + 1
      }
      Some(out)
    }
    PathStyle::HarfBuzz => {
      // In HarfBuzz mode, points are stored as f32 in 16.16 fixed units (as Double here).
      let scale = if ctx.is_scaled { ctx.hb_scale } else { 1.0 }
      let scaled : Array[GlyfPointF] = Array::new()
      for i in 0..<points.length() {
        let p = points.at(i)
        scaled.push(GlyfPointF::{
          x: xs.at(i) * scale,
          y: ys.at(i) * scale,
          on: p.on,
        })
      }
      let mut contour_start = 0
      for c in 0..<number_of_contours {
        let contour_end = end_pts.at(c)
        if contour_end < contour_start || contour_end >= scaled.length() {
          return None
        }
        glyf_emit_contour_harfbuzz(
          out,
          scaled.op_as_view(),
          contour_start,
          contour_end,
          path_style,
        )
        contour_start = contour_end + 1
      }
      Some(out)
    }
  }
}

///|
priv struct GlyfCtx {
  font : @moon_skrifa.FontRef
  glyf : BytesView
  loca : BytesView
  num_glyphs : Int
  index_to_loc_format : Int
  coords : ArrayView[@moon_skrifa.NormalizedCoord]
  is_scaled : Bool
  is_hinted : Bool
  scale_bits : Int
  hb_scale : Double
}

///|
fn glyf_glyph_slice(ctx : GlyfCtx, idx : Int) -> BytesView? {
  if idx < 0 || idx >= ctx.num_glyphs {
    return None
  }
  let (start, end) = if ctx.index_to_loc_format == 0 {
    let need = (ctx.num_glyphs + 1) * 2
    if ctx.loca.length() < need {
      return None
    }
    let o0 = match glyf_read_u16_be(ctx.loca, idx * 2) {
      None => return None
      Some(v) => v
    }
    let o1 = match glyf_read_u16_be(ctx.loca, (idx + 1) * 2) {
      None => return None
      Some(v) => v
    }
    (o0 * 2, o1 * 2)
  } else if ctx.index_to_loc_format == 1 {
    let need = (ctx.num_glyphs + 1) * 4
    if ctx.loca.length() < need {
      return None
    }
    let o0 = match glyf_read_u32_be(ctx.loca, idx * 4) {
      None => return None
      Some(v) => v.to_uint64().to_int()
    }
    let o1 = match glyf_read_u32_be(ctx.loca, (idx + 1) * 4) {
      None => return None
      Some(v) => v.to_uint64().to_int()
    }
    (o0, o1)
  } else {
    return None
  }
  if start < 0 || end < start || end > ctx.glyf.length() {
    return None
  }
  Some(ctx.glyf.sub(start~, end~))
}

///|
fn glyf_composite_path(
  ctx : GlyfCtx,
  glyph : BytesView,
  gid : @moon_skrifa.GlyphId,
  visited : Array[Bool],
  path_style : PathStyle,
) -> Array[PathElement]? {
  if glyph.length() < 10 {
    return None
  }
  // Skip bbox (xMin..yMax).
  let mut off = 10
  let comps : Array[GlyfCompositeComp] = Array::new()
  let mut flags = 0
  while true {
    flags = match glyf_read_u16_be(glyph, off) {
      None => return None
      Some(v) => v
    }
    let comp_gid = match glyf_read_u16_be(glyph, off + 2) {
      None => return None
      Some(v) => v
    }
    off = off + 4
    let arg_words = (flags & COMPOSITE_ARG_1_AND_2_ARE_WORDS) != 0
    let args_xy = (flags & COMPOSITE_ARGS_ARE_XY_VALUES) != 0
    if !args_xy {
      // Point matching not supported by MVP.
      return None
    }
    let (dx, dy) = if arg_words {
      let a1 = match glyf_read_i16_be(glyph, off) {
        None => return None
        Some(v) => v
      }
      let a2 = match glyf_read_i16_be(glyph, off + 2) {
        None => return None
        Some(v) => v
      }
      off = off + 4
      (a1.to_double(), a2.to_double())
    } else {
      if off + 2 > glyph.length() {
        return None
      }
      let b1 = glyph.at(off).to_int()
      let b2 = glyph.at(off + 1).to_int()
      off = off + 2
      let a1 = if b1 >= 128 { b1 - 256 } else { b1 }
      let a2 = if b2 >= 128 { b2 - 256 } else { b2 }
      (a1.to_double(), a2.to_double())
    }
    let mut a = 1.0
    let mut b = 0.0
    let mut c = 0.0
    let mut d = 1.0
    let mut have_xform = false
    if (flags & COMPOSITE_WE_HAVE_A_SCALE) != 0 {
      let s = match glyf_read_f2dot14(glyph, off) {
        None => return None
        Some(v) => v
      }
      off = off + 2
      a = s
      d = s
      have_xform = true
    } else if (flags & COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
      let sx = match glyf_read_f2dot14(glyph, off) {
        None => return None
        Some(v) => v
      }
      let sy = match glyf_read_f2dot14(glyph, off + 2) {
        None => return None
        Some(v) => v
      }
      off = off + 4
      a = sx
      d = sy
      have_xform = true
    } else if (flags & COMPOSITE_WE_HAVE_A_TWO_BY_TWO) != 0 {
      let ca = match glyf_read_f2dot14(glyph, off) {
        None => return None
        Some(v) => v
      }
      let cb = match glyf_read_f2dot14(glyph, off + 2) {
        None => return None
        Some(v) => v
      }
      let cc = match glyf_read_f2dot14(glyph, off + 4) {
        None => return None
        Some(v) => v
      }
      let cd = match glyf_read_f2dot14(glyph, off + 6) {
        None => return None
        Some(v) => v
      }
      off = off + 8
      a = ca
      b = cb
      c = cc
      d = cd
      have_xform = true
    }
    comps.push(GlyfCompositeComp::{
      flags,
      gid: comp_gid,
      dx,
      dy,
      a,
      b,
      c,
      d,
      have_xform,
    })
    if (flags & COMPOSITE_MORE_COMPONENTS) == 0 {
      break
    }
  }
  if (flags & COMPOSITE_WE_HAVE_INSTRUCTIONS) != 0 {
    if off + 2 > glyph.length() {
      return None
    }
    let ins_len = match glyf_read_u16_be(glyph, off) {
      None => return None
      Some(v) => v
    }
    off = off + 2
    if ins_len < 0 || off + ins_len > glyph.length() {
      return None
    }
  }
  let mut delta_x : Array[Double]? = None
  let mut delta_y : Array[Double]? = None
  match glyf_gvar_composite_deltas(ctx.font, gid, ctx.coords, comps.length()) {
    None => ()
    Some((xs, ys)) => {
      delta_x = Some(xs)
      delta_y = Some(ys)
    }
  }
  let out : Array[PathElement] = Array::new()
  for i in 0..<comps.length() {
    let comp = comps.at(i)
    let mut dx = comp.dx
    let mut dy = comp.dy
    if comp.have_xform &&
      (
        comp.flags &
        (
          COMPOSITE_SCALED_COMPONENT_OFFSET |
          COMPOSITE_UNSCALED_COMPONENT_OFFSET
        )
      ) ==
      COMPOSITE_SCALED_COMPONENT_OFFSET {
      // Matches FreeType's guess-based scaling.
      dx = dx * glyf_hypot_guess(comp.a, comp.b)
      dy = dy * glyf_hypot_guess(comp.d, comp.c)
    }
    match (delta_x, delta_y) {
      (Some(dx_arr), Some(dy_arr)) =>
        if i < dx_arr.length() && i < dy_arr.length() {
          match path_style {
            PathStyle::FreeType => {
              // FreeType rounds off the fractional part of component deltas.
              dx = dx + dx_arr.at(i).to_int().to_double()
              dy = dy + dy_arr.at(i).to_int().to_double()
            }
            PathStyle::HarfBuzz => {
              dx = dx + dx_arr.at(i)
              dy = dy + dy_arr.at(i)
            }
          }
        }
      _ => ()
    }
    let (sdx, sdy) = match path_style {
      PathStyle::FreeType => {
        let dx_i = dx.to_int()
        let dy_i = dy.to_int()
        let dx_bits = if ctx.is_scaled {
          glyf_mul_16_16(dx_i, ctx.scale_bits)
        } else {
          dx_i * 64
        }
        let mut dy_bits = if ctx.is_scaled {
          glyf_mul_16_16(dy_i, ctx.scale_bits)
        } else {
          dy_i * 64
        }
        if ctx.is_scaled &&
          ctx.is_hinted &&
          (comp.flags & COMPOSITE_ROUND_XY_TO_GRID) != 0 {
          // Match fontations-reference (FreeType behavior): only round the y
          // component, and only when hinting is enabled.
          dy_bits = (dy_bits + 32) & -64
        }
        (
          glyf_f26dot6_bits_to_double(dx_bits),
          glyf_f26dot6_bits_to_double(dy_bits),
        )
      }
      PathStyle::HarfBuzz =>
        // Matches fontations-reference HarfBuzzScaler: component offsets are
        // applied without scaling, even when points are scaled to 16.16.
        (dx, dy)
    }
    let t = GlyfTransform::{
      a: comp.a,
      b: comp.b,
      c: comp.c,
      d: comp.d,
      dx: sdx,
      dy: sdy,
    }
    let comp_path = match
      glyf_outline_path_idx(ctx, comp.gid, visited, path_style) {
      None => return None
      Some(p) => p
    }
    let transformed = glyf_apply_transform(comp_path, t)
    for e in transformed {
      out.push(e)
    }
  }
  Some(out)
}

///|
fn glyf_outline_path_idx(
  ctx : GlyfCtx,
  idx : Int,
  visited : Array[Bool],
  path_style : PathStyle,
) -> Array[PathElement]? {
  if idx < 0 || idx >= ctx.num_glyphs {
    return None
  }
  if visited.at(idx) {
    return None
  }
  visited.set(idx, true)
  let res = match glyf_glyph_slice(ctx, idx) {
    None => None
    Some(glyph) =>
      if glyph.length() == 0 {
        Some(Array::new())
      } else {
        match glyf_read_i16_be(glyph, 0) {
          None => None
          Some(nc) =>
            if nc < 0 {
              glyf_composite_path(
                ctx,
                glyph,
                @moon_skrifa.GlyphId::new(idx.to_uint16()),
                visited,
                path_style,
              )
            } else {
              glyf_simple_path(
                ctx,
                glyph,
                @moon_skrifa.GlyphId::new(idx.to_uint16()),
                path_style,
              )
            }
        }
      }
  }
  visited.set(idx, false)
  res
}

///|
fn glyf_outline_path(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  path_style : PathStyle,
  size : @moon_skrifa.Size,
  is_hinted : Bool,
) -> Array[PathElement]? {
  let upem = glyf_units_per_em(font)
  let (is_scaled, scale_bits) = glyf_compute_scale_bits(size, upem)
  // HarfBuzz uses an exact 16.16 scale factor. Do not inherit FreeType's
  // fixed-point rounding of the scale factor used for 26.6.
  let hb_scale = match size.ppem() {
    None => 1.0
    Some(ppem) => {
      let upem_i = upem.to_int()
      if upem_i <= 0 {
        1.0
      } else {
        ppem * 65536.0 / upem_i.to_double()
      }
    }
  }
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
  let ctx = GlyfCtx::{
    font,
    glyf,
    loca,
    num_glyphs,
    index_to_loc_format,
    coords,
    is_scaled,
    is_hinted,
    scale_bits,
    hb_scale,
  }
  let visited = Array::make(num_glyphs, false)
  glyf_outline_path_idx(ctx, idx, visited, path_style)
}

///|
fn glyf_glyph_count(font : @moon_skrifa.FontRef) -> Int? {
  let maxp = match font.table(TAG_MAXP) {
    None => return None
    Some(v) => v
  }
  // maxp.numGlyphs at offset 4.
  match glyf_read_u16_be(maxp, 4) {
    None => None
    Some(v) => Some(v)
  }
}

///|
fn glyf_outline_info_from_glyph(glyph : BytesView) -> (Bool, Bool)? {
  if glyph.length() < 10 {
    return None
  }
  let number_of_contours = match glyf_read_i16_be(glyph, 0) {
    None => return None
    Some(v) => v
  }
  if number_of_contours == 0 {
    return Some((false, false))
  }
  if number_of_contours < 0 {
    // Composite.
    let mut off = 10
    let mut has_overlaps = false
    let mut flags = 0
    while true {
      flags = match glyf_read_u16_be(glyph, off) {
        None => return None
        Some(v) => v
      }
      has_overlaps = has_overlaps || (flags & COMPOSITE_OVERLAP_COMPOUND) != 0
      // component glyph id
      match glyf_read_u16_be(glyph, off + 2) {
        None => return None
        Some(_) => ()
      }
      off = off + 4
      let arg_words = (flags & COMPOSITE_ARG_1_AND_2_ARE_WORDS) != 0
      let args_len = if arg_words { 4 } else { 2 }
      if off + args_len > glyph.length() {
        return None
      }
      off = off + args_len
      // Transform parameters.
      if (flags & COMPOSITE_WE_HAVE_A_SCALE) != 0 {
        off = off + 2
      } else if (flags & COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
        off = off + 4
      } else if (flags & COMPOSITE_WE_HAVE_A_TWO_BY_TWO) != 0 {
        off = off + 8
      }
      if off < 0 || off > glyph.length() {
        return None
      }
      if (flags & COMPOSITE_MORE_COMPONENTS) == 0 {
        break
      }
    }
    let has_hinting = (flags & COMPOSITE_WE_HAVE_INSTRUCTIONS) != 0
    return Some((has_overlaps, has_hinting))
  }
  // Simple: scan flags for overlap bit; hinting if instruction length > 0.
  let mut off = 10
  let end_pts : Array[Int] = Array::new()
  for _ in 0..<number_of_contours {
    let v = match glyf_read_u16_be(glyph, off) {
      None => return None
      Some(u) => u
    }
    end_pts.push(v)
    off = off + 2
  }
  let instruction_len = match glyf_read_u16_be(glyph, off) {
    None => return None
    Some(v) => v
  }
  off = off + 2
  if instruction_len < 0 || off + instruction_len > glyph.length() {
    return None
  }
  let has_hinting = instruction_len > 0
  off = off + instruction_len
  let last_end = end_pts.at(end_pts.length() - 1)
  let num_points = last_end + 1
  if num_points <= 0 {
    return Some((false, has_hinting))
  }
  let mut has_overlaps = false
  let flags : Array[Int] = Array::new()
  while flags.length() < num_points {
    if off >= glyph.length() {
      return None
    }
    let flag = glyph.at(off).to_int()
    off = off + 1
    has_overlaps = has_overlaps || (flag & SIMPLE_OVERLAP_FLAG) != 0
    flags.push(flag)
    if (flag & 0x08) != 0 {
      if off >= glyph.length() {
        return None
      }
      let repeat = glyph.at(off).to_int()
      off = off + 1
      for _ in 0..<repeat {
        has_overlaps = has_overlaps || (flag & SIMPLE_OVERLAP_FLAG) != 0
        flags.push(flag)
      }
    }
  }
  Some((has_overlaps, has_hinting))
}

///|
fn glyf_outline_info(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> (Bool, Bool)? {
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
  let empty : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let ctx = GlyfCtx::{
    font,
    glyf,
    loca,
    num_glyphs,
    index_to_loc_format,
    coords: empty.op_as_view(),
    is_scaled: false,
    is_hinted: false,
    scale_bits: 0x10000,
    hb_scale: 1.0,
  }
  match glyf_glyph_slice(ctx, idx) {
    None => None
    Some(g) => glyf_outline_info_from_glyph(g)
  }
}

///|
fn glyf_has_overlaps(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> Bool? {
  match glyf_outline_info(font, gid) {
    None => None
    Some((has_overlaps, _)) => Some(has_overlaps)
  }
}

///|
fn glyf_has_hinting(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
) -> Bool? {
  match glyf_outline_info(font, gid) {
    None => None
    Some((_, has_hinting)) => Some(has_hinting)
  }
}

///|
const GLYF_MEM_PHANTOM_POINT_COUNT : Int = 4

///|
const GLYF_MEM_TAG_GVAR : UInt = 0x67766172 // "gvar"

///|
const GLYF_MEM_TAG_CVT : UInt = 0x63767420 // "cvt "

///|
const GLYF_MEM_COMPOSITE_RECURSION_LIMIT : Int = 32

///|
// These sizes match upstream read-fonts layouts:
// Point<T> => 2x i32 = 8 bytes, PointFlags => u8 = 1 byte.
const GLYF_MEM_SIZE_POINT : Int = 8

///|
const GLYF_MEM_SIZE_POINT_FLAGS : Int = 1

///|
const GLYF_MEM_SIZE_U16 : Int = 2

///|
const GLYF_MEM_SIZE_I32 : Int = 4

///|
const GLYF_MEM_SIZE_ALIGN_I32 : Int = 4

///|
priv struct GlyfDrawMemorySummary {
  mut points : Int
  mut contours : Int
  mut max_simple_points : Int
  mut max_other_points : Int
  mut max_component_delta_stack : Int
  mut has_hinting : Bool
  mut has_overlaps : Bool
  has_variations : Bool
  max_stack : Int
  cvt_count : Int
  storage_count : Int
  max_twilight_points : Int
}

///|
fn glyf_draw_memory_summary_default(
  font : @moon_skrifa.FontRef,
) -> GlyfDrawMemorySummary {
  let has_variations = font.table(GLYF_MEM_TAG_GVAR) is Some(_)
  GlyfDrawMemorySummary::{
    points: 0,
    contours: 0,
    max_simple_points: 0,
    max_other_points: 0,
    max_component_delta_stack: 0,
    has_hinting: false,
    has_overlaps: false,
    has_variations,
    max_stack: 0,
    cvt_count: 0,
    storage_count: 0,
    max_twilight_points: 0,
  }
}

///|
fn glyf_draw_memory_summary_with_limits(
  font : @moon_skrifa.FontRef,
  max_stack : Int,
  cvt_count : Int,
  storage_count : Int,
  max_twilight_points : Int,
) -> GlyfDrawMemorySummary {
  let base = glyf_draw_memory_summary_default(font)
  GlyfDrawMemorySummary::{
    points: base.points,
    contours: base.contours,
    max_simple_points: base.max_simple_points,
    max_other_points: base.max_other_points,
    max_component_delta_stack: base.max_component_delta_stack,
    has_hinting: base.has_hinting,
    has_overlaps: base.has_overlaps,
    has_variations: base.has_variations,
    max_stack,
    cvt_count,
    storage_count,
    max_twilight_points,
  }
}

///|
fn glyf_draw_memory_required_size(
  sum : GlyfDrawMemorySummary,
  hinting : Hinting,
) -> Int {
  let hinted = sum.has_hinting && hinting is Hinting::Embedded
  let mut size = 0
  // Scaled points.
  size = size + sum.points * GLYF_MEM_SIZE_POINT
  // Unscaled and (if hinted) original scaled points.
  size = size +
    sum.max_other_points * GLYF_MEM_SIZE_POINT * (if hinted { 2 } else { 1 })
  // Contour end points.
  size = size + sum.contours * GLYF_MEM_SIZE_U16
  // Point flags.
  size = size + sum.points * GLYF_MEM_SIZE_POINT_FLAGS
  if sum.has_variations {
    // IUP buffer + delta buffers.
    size = size + sum.max_simple_points * GLYF_MEM_SIZE_POINT
    size = size + sum.max_simple_points * GLYF_MEM_SIZE_POINT
    size = size + sum.max_component_delta_stack * GLYF_MEM_SIZE_POINT
  }
  if hinted {
    size = size + sum.max_stack * GLYF_MEM_SIZE_I32
    size = size + (sum.cvt_count + sum.storage_count) * GLYF_MEM_SIZE_I32
    size = size +
      sum.max_twilight_points *
      (GLYF_MEM_SIZE_POINT * 2 + GLYF_MEM_SIZE_POINT_FLAGS)
  }
  if size != 0 {
    size = size + GLYF_MEM_SIZE_ALIGN_I32
  }
  size
}

///|
fn glyf_draw_memory_summary_rec(
  ctx : GlyfCtx,
  idx : Int,
  visited : Array[Bool],
  sum : GlyfDrawMemorySummary,
  component_depth : Int,
  recurse_depth : Int,
) -> Bool {
  if recurse_depth > GLYF_MEM_COMPOSITE_RECURSION_LIMIT {
    return false
  }
  if idx < 0 || idx >= ctx.num_glyphs {
    return false
  }
  if visited.at(idx) {
    return false
  }
  visited.set(idx, true)
  let glyph = match glyf_glyph_slice(ctx, idx) {
    None => {
      visited.set(idx, false)
      return false
    }
    Some(g) => g
  }
  // Empty glyph is valid (loca start==end).
  if glyph.length() == 0 {
    visited.set(idx, false)
    return true
  }
  if glyph.length() < 10 {
    visited.set(idx, false)
    return false
  }
  let number_of_contours = match glyf_read_i16_be(glyph, 0) {
    None => {
      visited.set(idx, false)
      return false
    }
    Some(v) => v
  }
  if number_of_contours == 0 {
    visited.set(idx, false)
    return true
  }
  if number_of_contours > 0 {
    // Simple glyph.
    let mut off = 10
    let mut last_end = -1
    for _ in 0..<number_of_contours {
      let v = match glyf_read_u16_be(glyph, off) {
        None => {
          visited.set(idx, false)
          return false
        }
        Some(u) => u
      }
      last_end = v
      off = off + 2
    }
    let instruction_len = match glyf_read_u16_be(glyph, off) {
      None => {
        visited.set(idx, false)
        return false
      }
      Some(v) => v
    }
    off = off + 2
    if instruction_len < 0 || off + instruction_len > glyph.length() {
      visited.set(idx, false)
      return false
    }
    let has_hinting = instruction_len > 0
    off = off + instruction_len
    let num_points = last_end + 1
    if num_points > 0 {
      let num_points_with_phantom = num_points + GLYF_MEM_PHANTOM_POINT_COUNT
      sum.max_simple_points = sum.max_simple_points.max(num_points_with_phantom)
      sum.max_other_points = sum.max_other_points.max(num_points_with_phantom)
      sum.points = sum.points + num_points
      sum.contours = sum.contours + number_of_contours
      sum.has_hinting = sum.has_hinting || has_hinting
      // Scan flags for overlap bit.
      let mut seen = 0
      while seen < num_points {
        if off >= glyph.length() {
          visited.set(idx, false)
          return false
        }
        let flag = glyph.at(off).to_int()
        off = off + 1
        sum.has_overlaps = sum.has_overlaps || (flag & SIMPLE_OVERLAP_FLAG) != 0
        seen = seen + 1
        if (flag & 0x08) != 0 {
          if off >= glyph.length() {
            visited.set(idx, false)
            return false
          }
          let repeat = glyph.at(off).to_int()
          off = off + 1
          for _ in 0..<repeat {
            sum.has_overlaps = sum.has_overlaps ||
              (flag & SIMPLE_OVERLAP_FLAG) != 0
            seen = seen + 1
          }
        }
      }
    } else {
      sum.contours = sum.contours + number_of_contours
      sum.has_hinting = sum.has_hinting || has_hinting
    }
    visited.set(idx, false)
    return true
  }
  // Composite glyph.
  let mut off = 10
  let point_base = sum.points
  let comp_ids : Array[Int] = Array::new()
  let mut flags = 0
  let mut component_count = 0
  while true {
    flags = match glyf_read_u16_be(glyph, off) {
      None => {
        visited.set(idx, false)
        return false
      }
      Some(v) => v
    }
    sum.has_overlaps = sum.has_overlaps ||
      (flags & COMPOSITE_OVERLAP_COMPOUND) != 0
    let comp_gid = match glyf_read_u16_be(glyph, off + 2) {
      None => {
        visited.set(idx, false)
        return false
      }
      Some(v) => v
    }
    comp_ids.push(comp_gid)
    component_count = component_count + 1
    off = off + 4
    let arg_words = (flags & COMPOSITE_ARG_1_AND_2_ARE_WORDS) != 0
    let args_len = if arg_words { 4 } else { 2 }
    if off + args_len > glyph.length() {
      visited.set(idx, false)
      return false
    }
    off = off + args_len
    if (flags & COMPOSITE_WE_HAVE_A_SCALE) != 0 {
      off = off + 2
    } else if (flags & COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
      off = off + 4
    } else if (flags & COMPOSITE_WE_HAVE_A_TWO_BY_TWO) != 0 {
      off = off + 8
    }
    if off < 0 || off > glyph.length() {
      visited.set(idx, false)
      return false
    }
    if (flags & COMPOSITE_MORE_COMPONENTS) == 0 {
      break
    }
  }
  let has_hinting = (flags & COMPOSITE_WE_HAVE_INSTRUCTIONS) != 0
  let count = component_count + GLYF_MEM_PHANTOM_POINT_COUNT
  sum.max_component_delta_stack = sum.max_component_delta_stack.max(
    component_depth + count,
  )
  for cg in comp_ids.iter() {
    // Missing component glyphs are treated as empty.
    if cg >= 0 && cg < ctx.num_glyphs {
      if !glyf_draw_memory_summary_rec(
          ctx,
          cg,
          visited,
          sum,
          component_depth + count,
          recurse_depth + 1,
        ) {
        visited.set(idx, false)
        return false
      }
    }
  }
  if has_hinting {
    let num_points_in_composite = sum.points -
      point_base +
      GLYF_MEM_PHANTOM_POINT_COUNT
    sum.max_other_points = sum.max_other_points.max(num_points_in_composite)
  }
  sum.has_hinting = sum.has_hinting || has_hinting
  visited.set(idx, false)
  true
}

///|
/// Returns the required temporary memory size (in bytes) for drawing a glyf
/// outline, matching upstream `skrifa::outline::glyf::Outline::required_buffer_size`.
fn glyf_draw_memory_size(
  font : @moon_skrifa.FontRef,
  gid : @moon_skrifa.GlyphId,
  hinting : Hinting,
) -> Int? {
  // Build a context for slice access.
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
  let empty : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let ctx = GlyfCtx::{
    font,
    glyf,
    loca,
    num_glyphs,
    index_to_loc_format,
    coords: empty.op_as_view(),
    is_scaled: false,
    is_hinted: false,
    scale_bits: 0x10000,
    hb_scale: 1.0,
  }

  // Parse maxp-derived hinting limits and CVT size.
  let max_twilight_points = glyf_read_u16_be(maxp, 16).unwrap_or(0) + 4
  let max_stack = glyf_read_u16_be(maxp, 24).unwrap_or(0) + 32
  let max_storage = glyf_read_u16_be(maxp, 18).unwrap_or(0)
  let cvt_count = match font.table(GLYF_MEM_TAG_CVT) {
    None => 0
    Some(cvt) => cvt.length() / 2
  }
  let sum = glyf_draw_memory_summary_with_limits(
    font, max_stack, cvt_count, max_storage, max_twilight_points,
  )
  let visited = Array::make(num_glyphs, false)
  if !glyf_draw_memory_summary_rec(ctx, idx, visited, sum, 0, 0) {
    return None
  }
  // Add phantom points at top-level.
  sum.points = sum.points + GLYF_MEM_PHANTOM_POINT_COUNT
  Some(glyf_draw_memory_required_size(sum, hinting))
}
