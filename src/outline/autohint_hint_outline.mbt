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
/// Apply edge hints to an autohint outline (point alignment passes).
///
/// Ported from `fontations/skrifa/src/outline/autohint/hint/outline.rs`
/// (Apache-2.0 OR MIT).

///|
fn autohint_store_point(point : AutoHintPoint, dim : Int, u : Int) -> Unit {
  if dim == AUTOHINT_DIM_HORIZONTAL {
    point.x = u
    point.flags.set_marker(AutoHintPointMarker::TouchedX)
  } else {
    point.y = u
    point.flags.set_marker(AutoHintPointMarker::TouchedY)
  }
}

///|
/// Align all points of an edge to the same coordinate value.
fn autohint_align_edge_points(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
  group : AutoHintScriptGroup,
  scale_flags : Int,
) -> Unit {
  // Snapping is configurable for CJK.
  let snap = group is AutoHintScriptGroup::Default ||
    (
      axis.dim == AUTOHINT_DIM_HORIZONTAL &&
      (scale_flags & AUTOHINT_SCALE_HORIZONTAL_SNAP) != 0
    ) ||
    (
      axis.dim == AUTOHINT_DIM_VERTICAL &&
      (scale_flags & AUTOHINT_SCALE_VERTICAL_SNAP) != 0
    )
  for segment in axis.segments.iter() {
    match segment.edge_ix {
      None => ()
      Some(edge_ix) => {
        let edge = axis.edges.at(edge_ix)
        let delta = edge.pos - edge.opos
        let touch_marker = if axis.dim == AUTOHINT_DIM_HORIZONTAL {
          AutoHintPointMarker::TouchedX
        } else {
          AutoHintPointMarker::TouchedY
        }
        let mut point_ix = segment.first_ix
        let last_ix = segment.last_ix
        while true {
          let point = outline.points.at(point_ix)
          if axis.dim == AUTOHINT_DIM_HORIZONTAL {
            if snap {
              point.x = edge.pos
            } else {
              point.x = point.x + delta
            }
            point.flags.set_marker(touch_marker)
          } else {
            if snap {
              point.y = edge.pos
            } else {
              point.y = point.y + delta
            }
            point.flags.set_marker(touch_marker)
          }
          if point_ix == last_ix {
            break
          }
          point_ix = point.next()
        }
      }
    }
  }
}

///|
/// Align the strong points; equivalent to the TrueType `IP` instruction.
fn autohint_align_strong_points(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
) -> Unit {
  if axis.edges.is_empty() {
    return
  }
  let dim = axis.dim
  let touch_mask = (if dim == AUTOHINT_DIM_HORIZONTAL {
    AutoHintPointMarker::TouchedX
  } else {
    AutoHintPointMarker::TouchedY
  }).bit()
  let weak_mask = AutoHintPointMarker::WeakInterpolation.bit()
  for i in 0..<outline.points.length() {
    let point = outline.points.at(i)
    // Skip points that are already touched; do weak interpolation in next pass.
    if point.flags.has_marker_mask(touch_mask | weak_mask) {
      continue
    }
    let (u, ou) = if dim == AUTOHINT_DIM_VERTICAL {
      (point.fy, point.oy)
    } else {
      (point.fx, point.ox)
    }
    // Is the point before the first edge?
    let first_edge = axis.edges.at(0)
    let delta0 = first_edge.fpos - u
    if delta0 >= 0 {
      autohint_store_point(point, dim, first_edge.pos - (first_edge.opos - ou))
      continue
    }
    // Is the point after the last edge?
    let last_edge = axis.edges.at(axis.edges.length() - 1)
    let delta1 = u - last_edge.fpos
    if delta1 >= 0 {
      autohint_store_point(point, dim, last_edge.pos + (ou - last_edge.opos))
      continue
    }
    // Find enclosing edges; for a small number of edges, use linear search.
    let mut min_ix = 0
    if axis.edges.length() <= 8 {
      let mut found = false
      for j in 0..<axis.edges.length() {
        let edge = axis.edges.at(j)
        if edge.fpos >= u {
          if edge.fpos == u {
            autohint_store_point(point, dim, edge.pos)
            found = true
          }
          min_ix = j
          break
        }
      }
      if found {
        continue
      }
    } else {
      let mut lo = 0
      let mut hi = axis.edges.length()
      while lo < hi {
        let mid = (lo + hi) >> 1
        let edge = axis.edges.at(mid)
        let fpos = edge.fpos
        if u < fpos {
          hi = mid
        } else if u > fpos {
          lo = mid + 1
        } else {
          autohint_store_point(point, dim, edge.pos)
          lo = -1
          break
        }
      }
      if lo == -1 {
        continue
      }
      min_ix = lo
    }
    // Point is not on an edge.
    if min_ix > 0 {
      let before_ix = min_ix - 1
      let edge_before = axis.edges.at(before_ix)
      let before_pos = edge_before.pos
      let before_fpos = edge_before.fpos
      let scale = if edge_before.scale == 0 {
        let edge_after = axis.edges.at(min_ix)
        let scale = autohint_fixed_div(
          edge_after.pos - edge_before.pos,
          edge_after.fpos - before_fpos,
        )
        axis.edges.at(before_ix).scale = scale
        scale
      } else {
        edge_before.scale
      }
      autohint_store_point(
        point,
        dim,
        before_pos + autohint_fixed_mul(u - before_fpos, scale),
      )
    }
  }
}

///|
fn autohint_iup_shift(
  outline : AutoHintOutline,
  p1_ix : Int,
  p2_ix : Int,
  ref_ix : Int,
) -> Unit {
  let ref_point = outline.points.at(ref_ix)
  let delta = ref_point.u - ref_point.v
  if delta == 0 {
    return
  }
  for ix in p1_ix..<ref_ix {
    let p = outline.points.at(ix)
    p.u = p.v + delta
  }
  for ix in (ref_ix + 1)..<(p2_ix + 1) {
    let p = outline.points.at(ix)
    p.u = p.v + delta
  }
}

///|
fn autohint_iup_interpolate(
  outline : AutoHintOutline,
  p1_ix : Int,
  p2_ix : Int,
  ref1_ix : Int,
  ref2_ix : Int,
) -> Unit {
  if p1_ix > p2_ix {
    return
  }
  let mut ref1 = outline.points.at(ref1_ix)
  let mut ref2 = outline.points.at(ref2_ix)
  if ref1.v > ref2.v {
    let tmp = ref1
    ref1 = ref2
    ref2 = tmp
  }
  let (u1, v1) = (ref1.u, ref1.v)
  let (u2, v2) = (ref2.u, ref2.v)
  let d1 = u1 - v1
  let d2 = u2 - v2
  if u1 == u2 || v1 == v2 {
    for ix in p1_ix..<(p2_ix + 1) {
      let p = outline.points.at(ix)
      p.u = if p.v <= v1 { p.v + d1 } else if p.v >= v2 { p.v + d2 } else { u1 }
    }
  } else {
    let scale = autohint_fixed_div(u2 - u1, v2 - v1)
    for ix in p1_ix..<(p2_ix + 1) {
      let p = outline.points.at(ix)
      p.u = if p.v <= v1 {
        p.v + d1
      } else if p.v >= v2 {
        p.v + d2
      } else {
        u1 + autohint_fixed_mul(p.v - v1, scale)
      }
    }
  }
}

///|
/// Align the weak points; equivalent to the TrueType `IUP` instruction.
fn autohint_align_weak_points(outline : AutoHintOutline, dim : Int) -> Unit {
  let touch_mask = (if dim == AUTOHINT_DIM_HORIZONTAL {
    for i in 0..<outline.points.length() {
      let p = outline.points.at(i)
      p.u = p.x
      p.v = p.ox
    }
    AutoHintPointMarker::TouchedX
  } else {
    for i in 0..<outline.points.length() {
      let p = outline.points.at(i)
      p.u = p.y
      p.v = p.oy
    }
    AutoHintPointMarker::TouchedY
  }).bit()
  for contour in outline.contours.iter() {
    let first = contour.first_ix
    let last = contour.last_ix
    if first < 0 || last < first || last >= outline.points.length() {
      continue
    }
    let mut first_touched : Int? = None
    for ix in first..<(last + 1) {
      if outline.points.at(ix).flags.has_marker_mask(touch_mask) {
        first_touched = Some(ix)
        break
      }
    }
    match first_touched {
      None => continue
      Some(first_touched_ix) => {
        let mut point_ix = first_touched_ix
        let mut last_touched_ix = first_touched_ix
        while true {
          // Skip any touched neighbors.
          while point_ix < last &&
                outline.points.at(point_ix + 1).flags.has_marker_mask(
                  touch_mask,
                ) {
            point_ix = point_ix + 1
          }
          last_touched_ix = point_ix
          // Find next touched point.
          point_ix = point_ix + 1
          while true {
            if point_ix > last {
              break
            }
            if outline.points.at(point_ix).flags.has_marker_mask(touch_mask) {
              break
            }
            point_ix = point_ix + 1
          }
          if point_ix > last {
            break
          }
          autohint_iup_interpolate(
            outline,
            last_touched_ix + 1,
            point_ix - 1,
            last_touched_ix,
            point_ix,
          )
        }
        if last_touched_ix == first_touched_ix {
          // Only one point was touched.
          autohint_iup_shift(outline, first, last, first_touched_ix)
        } else {
          // Interpolate the remainder.
          if last_touched_ix < last {
            autohint_iup_interpolate(
              outline,
              last_touched_ix + 1,
              last,
              last_touched_ix,
              first_touched_ix,
            )
          }
          if first_touched_ix > first {
            autohint_iup_interpolate(
              outline,
              first,
              first_touched_ix - 1,
              last_touched_ix,
              first_touched_ix,
            )
          }
        }
      }
    }
  }
  // Save interpolated values.
  if dim == AUTOHINT_DIM_HORIZONTAL {
    for i in 0..<outline.points.length() {
      let p = outline.points.at(i)
      p.x = p.u
    }
  } else {
    for i in 0..<outline.points.length() {
      let p = outline.points.at(i)
      p.y = p.u
    }
  }
}
