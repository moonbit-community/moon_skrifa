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
/// Convert autohint outlines back into `PathElement` streams.
///
/// This reuses the same "FreeType-style" quadratic contour rules as the glyf
/// path conversion.

///|
fn autohint_f26dot6_to_double(bits : Int) -> Double {
  bits.to_double() / 64.0
}

///|
fn autohint_midpoint_i32(a : Int, b : Int) -> Int {
  (a + b) / 2
}

///|
fn autohint_emit_contour(
  out : Array[PathElement],
  outline : AutoHintOutline,
  start : Int,
  end : Int,
  path_style : PathStyle,
) -> Unit {
  let n = end - start + 1
  if n <= 0 {
    return
  }
  let first = outline.points.at(start)
  let last = outline.points.at(end)
  let (sx, sy, start_idx) = if first.is_on_curve() {
    (first.x, first.y, start)
  } else {
    match path_style {
      PathStyle::FreeType =>
        if last.is_on_curve() {
          (last.x, last.y, end)
        } else {
          (
            autohint_midpoint_i32(last.x, first.x),
            autohint_midpoint_i32(last.y, first.y),
            -1,
          )
        }
      PathStyle::HarfBuzz =>
        if n >= 2 {
          let second = outline.points.at(start + 1)
          if second.is_on_curve() {
            (second.x, second.y, start + 1)
          } else {
            (
              autohint_midpoint_i32(first.x, second.x),
              autohint_midpoint_i32(first.y, second.y),
              -1,
            )
          }
        } else {
          (first.x, first.y, start)
        }
    }
  }
  out.push(
    MoveTo(autohint_f26dot6_to_double(sx), autohint_f26dot6_to_double(sy)),
  )
  let mut control : (Int, Int)? = None
  if start_idx == -1 {
    for i in start..<(end + 1) {
      let p = outline.points.at(i)
      if p.is_on_curve() {
        match control {
          None =>
            out.push(
              LineTo(
                autohint_f26dot6_to_double(p.x),
                autohint_f26dot6_to_double(p.y),
              ),
            )
          Some((cx, cy)) => {
            out.push(
              QuadTo(
                autohint_f26dot6_to_double(cx),
                autohint_f26dot6_to_double(cy),
                autohint_f26dot6_to_double(p.x),
                autohint_f26dot6_to_double(p.y),
              ),
            )
            control = None
          }
        }
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let mx = autohint_midpoint_i32(cx, p.x)
            let my = autohint_midpoint_i32(cy, p.y)
            out.push(
              QuadTo(
                autohint_f26dot6_to_double(cx),
                autohint_f26dot6_to_double(cy),
                autohint_f26dot6_to_double(mx),
                autohint_f26dot6_to_double(my),
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
      let p = outline.points.at(idx)
      if p.is_on_curve() {
        match control {
          None =>
            out.push(
              LineTo(
                autohint_f26dot6_to_double(p.x),
                autohint_f26dot6_to_double(p.y),
              ),
            )
          Some((cx, cy)) => {
            out.push(
              QuadTo(
                autohint_f26dot6_to_double(cx),
                autohint_f26dot6_to_double(cy),
                autohint_f26dot6_to_double(p.x),
                autohint_f26dot6_to_double(p.y),
              ),
            )
            control = None
          }
        }
      } else {
        match control {
          None => control = Some((p.x, p.y))
          Some((cx, cy)) => {
            let mx = autohint_midpoint_i32(cx, p.x)
            let my = autohint_midpoint_i32(cy, p.y)
            out.push(
              QuadTo(
                autohint_f26dot6_to_double(cx),
                autohint_f26dot6_to_double(cy),
                autohint_f26dot6_to_double(mx),
                autohint_f26dot6_to_double(my),
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
          autohint_f26dot6_to_double(cx),
          autohint_f26dot6_to_double(cy),
          autohint_f26dot6_to_double(sx),
          autohint_f26dot6_to_double(sy),
        ),
      )
    None => ()
  }
  out.push(Close)
}

///|
fn autohint_outline_to_path(
  outline : AutoHintOutline,
  path_style : PathStyle,
) -> Array[PathElement] {
  let out : Array[PathElement] = Array::new()
  for contour in outline.contours.iter() {
    let start = contour.first_ix
    let end = contour.last_ix
    if start < 0 || end < start || end >= outline.points.length() {
      continue
    }
    autohint_emit_contour(out, outline, start, end, path_style)
  }
  out
}
