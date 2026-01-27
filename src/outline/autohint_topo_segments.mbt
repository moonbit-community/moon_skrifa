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
/// Autohint topology: segment computation and linking.
///
/// Ported from `fontations/skrifa/src/outline/autohint/topo/segments.rs`
/// (Apache-2.0 OR MIT).

///|
priv enum AutoHintScriptGroup {
  Default
  Cjk
}

///|
fn autohint_derived_constant(units_per_em : Int, value : Int) -> Int {
  value * units_per_em / 2048
}

///|
fn autohint_fixed_div(a : Int, b : Int) -> Int {
  if b == 0 {
    0
  } else {
    let a64 = a.to_int64() << 16
    (a64 / b.to_int64()).to_int()
  }
}

// Bounds for score, position and coordinate values.

///|
const AUTOHINT_SEG_MAX_SCORE : Int = 32000

///|
const AUTOHINT_SEG_MIN_SCORE : Int = -32000

///|
priv struct AutoHintAxis {
  mut dim : Int
  mut major_dir : AutoHintDirection
  segments : Array[AutoHintSegment]
}

///|
fn AutoHintAxis::default() -> AutoHintAxis {
  AutoHintAxis::{
    dim: 0,
    major_dir: AutoHintDirection::None_,
    segments: Array::new(),
  }
}

///|
const AUTOHINT_DIM_HORIZONTAL : Int = 0

///|
const AUTOHINT_DIM_VERTICAL : Int = 1

///|
fn AutoHintAxis::reset(
  self : AutoHintAxis,
  dim : Int,
  orientation : AutoHintOrientation?,
) -> Unit {
  self.dim = dim
  self.major_dir = match (dim, orientation) {
    (AUTOHINT_DIM_HORIZONTAL, Some(AutoHintOrientation::Clockwise)) =>
      AutoHintDirection::Down
    (AUTOHINT_DIM_VERTICAL, Some(AutoHintOrientation::Clockwise)) =>
      AutoHintDirection::Right
    (AUTOHINT_DIM_HORIZONTAL, _) => AutoHintDirection::Up
    (AUTOHINT_DIM_VERTICAL, _) => AutoHintDirection::Left
    _ => AutoHintDirection::None_
  }
  self.segments.clear()
}

///|
priv struct AutoHintSegment {
  mut flags : Int
  mut dir : AutoHintDirection
  mut pos : Int
  mut delta : Int
  mut min_coord : Int
  mut max_coord : Int
  mut height : Int
  mut score : Int
  mut len : Int
  mut link_ix : Int?
  mut serif_ix : Int?
  mut first_ix : Int
  mut last_ix : Int
}

///|
fn AutoHintSegment::default() -> AutoHintSegment {
  AutoHintSegment::{
    flags: 0,
    dir: AutoHintDirection::None_,
    pos: 0,
    delta: 0,
    min_coord: 0,
    max_coord: 0,
    height: 0,
    score: AUTOHINT_SEG_MAX_SCORE,
    len: 0,
    link_ix: None,
    serif_ix: None,
    first_ix: 0,
    last_ix: 0,
  }
}

///|
fn AutoHintSegment::first_point(
  self : AutoHintSegment,
  points : Array[AutoHintPoint],
) -> AutoHintPoint {
  points.at(self.first_ix)
}

///|
fn AutoHintSegment::last_point(
  self : AutoHintSegment,
  points : Array[AutoHintPoint],
) -> AutoHintPoint {
  points.at(self.last_ix)
}

///|
fn autohint_segment_make(
  dir : AutoHintDirection,
  first_ix : Int,
  last_ix : Int,
) -> AutoHintSegment {
  let seg = AutoHintSegment::default()
  seg.dir = dir
  seg.first_ix = first_ix
  seg.last_ix = last_ix
  seg.score = AUTOHINT_SEG_MAX_SCORE
  seg
}

///|
priv struct AutoHintSegmentState {
  mut min_pos : Int
  mut max_pos : Int
  mut min_coord : Int
  mut max_coord : Int
  mut min_flags : AutoHintPointFlags
  mut max_flags : AutoHintPointFlags
  mut min_on_coord : Int
  mut max_on_coord : Int
}

///|
fn AutoHintSegmentState::default() -> AutoHintSegmentState {
  AutoHintSegmentState::{
    min_pos: AUTOHINT_SEG_MAX_SCORE,
    max_pos: AUTOHINT_SEG_MIN_SCORE,
    min_coord: AUTOHINT_SEG_MAX_SCORE,
    max_coord: AUTOHINT_SEG_MIN_SCORE,
    min_flags: AutoHintPointFlags::default(),
    max_flags: AutoHintPointFlags::default(),
    min_on_coord: AUTOHINT_SEG_MAX_SCORE,
    max_on_coord: AUTOHINT_SEG_MIN_SCORE,
  }
}

///|
fn autohint_segment_state_copy(
  dst : AutoHintSegmentState,
  src : AutoHintSegmentState,
) -> Unit {
  dst.min_pos = src.min_pos
  dst.max_pos = src.max_pos
  dst.min_coord = src.min_coord
  dst.max_coord = src.max_coord
  dst.min_flags = src.min_flags
  dst.max_flags = src.max_flags
  dst.min_on_coord = src.min_on_coord
  dst.max_on_coord = src.max_on_coord
}

///|
fn AutoHintSegmentState::apply_to_segment(
  self : AutoHintSegmentState,
  segment : AutoHintSegment,
  flat_threshold : Int,
) -> Unit {
  segment.pos = (self.min_pos + self.max_pos) >> 1
  segment.delta = (self.max_pos - self.min_pos) >> 1
  if (!self.min_flags.is_on_curve() || !self.max_flags.is_on_curve()) &&
    self.max_on_coord - self.min_on_coord < flat_threshold {
    segment.flags = segment.flags | 1
  }
  segment.min_coord = self.min_coord
  segment.max_coord = self.max_coord
  segment.height = self.max_coord - self.min_coord
}

///|
fn autohint_assign_point_uvs(outline : AutoHintOutline, dim : Int) -> Unit {
  if dim == AUTOHINT_DIM_HORIZONTAL {
    for i in 0..<outline.points.length() {
      let p = outline.points.at(i)
      p.u = p.fx
      p.v = p.fy
      outline.points.set(i, p)
    }
  } else {
    for i in 0..<outline.points.length() {
      let p = outline.points.at(i)
      p.u = p.fy
      p.v = p.fx
      outline.points.set(i, p)
    }
  }
}

///|
fn autohint_build_segments(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
) -> Bool {
  let flat_threshold = outline.units_per_em / 14
  axis.segments.clear()
  let major_dir = axis.major_dir.normalize()
  let mut segment_dir = major_dir
  for contour in outline.contours.iter() {
    let is_single_point_contour = contour.length() == 1
    let mut point_ix = contour.first()
    let mut last_ix = contour.prev(point_ix)
    let state = AutoHintSegmentState::default()
    let prev_state = AutoHintSegmentState::default()
    let mut prev_segment_ix : Int? = None
    let mut segment_ix = 0
    // Check if we're starting on an edge and if so, find the starting point.
    if outline.points.at(point_ix).out_dir.is_same_axis(major_dir) &&
      outline.points.at(last_ix).out_dir.is_same_axis(major_dir) {
      last_ix = point_ix
      while true {
        point_ix = contour.prev(point_ix)
        if !outline.points.at(point_ix).out_dir.is_same_axis(major_dir) {
          point_ix = contour.next(point_ix)
          break
        }
        if point_ix == last_ix {
          break
        }
      }
    }
    last_ix = point_ix
    let mut on_edge = false
    let mut passed = false
    while true {
      if on_edge {
        let point = outline.points.at(point_ix)
        state.min_pos = state.min_pos.min(point.u)
        state.max_pos = state.max_pos.max(point.u)
        let v = point.v
        if v < state.min_coord {
          state.min_coord = v
          state.min_flags = point.flags
        }
        if v > state.max_coord {
          state.max_coord = v
          state.max_flags = point.flags
        }
        if point.is_on_curve() {
          state.min_on_coord = state.min_on_coord.min(point.v)
          state.max_on_coord = state.max_on_coord.max(point.v)
        }
        if point.out_dir != segment_dir || point_ix == last_ix {
          match prev_segment_ix {
            None => {
              let seg = axis.segments.at(segment_ix)
              seg.last_ix = point_ix
              AutoHintSegmentState::apply_to_segment(state, seg, flat_threshold)
              axis.segments.set(segment_ix, seg)
              prev_segment_ix = Some(segment_ix)
              autohint_segment_state_copy(prev_state, state)
            }
            Some(prev_ix) =>
              if axis.segments.at(segment_ix).first_ix !=
                axis.segments.at(prev_ix).last_ix {
                let seg = axis.segments.at(segment_ix)
                seg.last_ix = point_ix
                AutoHintSegmentState::apply_to_segment(
                  state, seg, flat_threshold,
                )
                axis.segments.set(segment_ix, seg)
                prev_segment_ix = Some(segment_ix)
                autohint_segment_state_copy(prev_state, state)
              } else {
                let prev_seg = axis.segments.at(prev_ix)
                if prev_seg.last_point(outline.points).in_dir == point.in_dir {
                  // identical directions: unify
                  state.min_pos = prev_state.min_pos.min(state.min_pos)
                  state.max_pos = prev_state.max_pos.max(state.max_pos)
                  if prev_state.min_coord < state.min_coord {
                    state.min_coord = prev_state.min_coord
                    state.min_flags = prev_state.min_flags
                  }
                  if prev_state.max_coord > state.max_coord {
                    state.max_coord = prev_state.max_coord
                    state.max_flags = prev_state.max_flags
                  }
                  state.min_on_coord = prev_state.min_on_coord.min(
                    state.min_on_coord,
                  )
                  state.max_on_coord = prev_state.max_on_coord.max(
                    state.max_on_coord,
                  )
                  prev_seg.last_ix = point_ix
                  AutoHintSegmentState::apply_to_segment(
                    state, prev_seg, flat_threshold,
                  )
                  axis.segments.set(prev_ix, prev_seg)
                  // pick longer segment properties
                } else if (prev_state.max_coord - prev_state.min_coord).abs() >
                  (state.max_coord - state.min_coord).abs() {
                  prev_state.min_pos = prev_state.min_pos.min(state.min_pos)
                  prev_state.max_pos = prev_state.max_pos.max(state.max_pos)
                  prev_seg.last_ix = point_ix
                  prev_seg.pos = (prev_state.min_pos + prev_state.max_pos) >> 1
                  prev_seg.delta = (prev_state.max_pos - prev_state.min_pos) >>
                    1
                  axis.segments.set(prev_ix, prev_seg)
                } else {
                  state.min_pos = state.min_pos.min(prev_state.min_pos)
                  state.max_pos = state.max_pos.max(prev_state.max_pos)
                  let seg = axis.segments.at(segment_ix)
                  seg.last_ix = point_ix
                  AutoHintSegmentState::apply_to_segment(
                    state, seg, flat_threshold,
                  )
                  axis.segments.set(prev_ix, seg)
                  autohint_segment_state_copy(prev_state, state)
                }
                axis.segments.pop() |> ignore
              }
          }
          on_edge = false
        }
      }
      if point_ix == last_ix {
        if passed {
          break
        }
        passed = true
      }
      let point = outline.points.at(point_ix)
      if !on_edge &&
        (point.out_dir.is_same_axis(major_dir) || is_single_point_contour) {
        if axis.segments.length() > 1000 {
          axis.segments.clear()
          return false
        }
        segment_ix = axis.segments.length()
        segment_dir = point.out_dir
        let segment = autohint_segment_make(segment_dir, point_ix, point_ix)
        state.min_pos = point.u
        state.max_pos = point.u
        state.min_coord = point.v
        state.max_coord = point.v
        state.min_flags = point.flags
        state.max_flags = point.flags
        if !point.is_on_curve() {
          state.min_on_coord = AUTOHINT_SEG_MAX_SCORE
          state.max_on_coord = AUTOHINT_SEG_MIN_SCORE
        } else {
          state.min_on_coord = point.v
          state.max_on_coord = point.v
        }
        on_edge = true
        if is_single_point_contour {
          segment.pos = state.min_pos
          if !point.is_on_curve() {
            segment.flags = segment.flags | 1
          }
          segment.min_coord = point.v
          segment.max_coord = point.v
          segment.height = 0
          on_edge = false
        }
        axis.segments.push(segment)
      }
      point_ix = contour.next(point_ix)
    }
  }
  true
}

///|
fn autohint_adjust_segment_heights(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
) -> Unit {
  for i in 0..<axis.segments.length() {
    let segment = axis.segments.at(i)
    let first = segment.first_point(outline.points)
    let last = segment.last_point(outline.points)
    let prev = outline.points.at(first.prev())
    let next = outline.points.at(last.next())
    if first.v < last.v {
      if prev.v < first.v {
        segment.height = segment.height + ((first.v - prev.v) >> 1)
      }
      if next.v > last.v {
        segment.height = segment.height + ((next.v - last.v) >> 1)
      }
    } else {
      if prev.v > first.v {
        segment.height = segment.height + ((prev.v - first.v) >> 1)
      }
      if next.v < last.v {
        segment.height = segment.height + ((last.v - next.v) >> 1)
      }
    }
    axis.segments.set(i, segment)
  }
}

///|
fn autohint_compute_segments(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
  group : AutoHintScriptGroup,
) -> Bool {
  group |> ignore
  autohint_assign_point_uvs(outline, axis.dim)
  if !autohint_build_segments(outline, axis) {
    return false
  }
  autohint_adjust_segment_heights(outline, axis)
  true
}

///|
fn autohint_link_segments_default(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
  max_width : Int,
) -> Unit {
  // Heuristic value to set up a minimum for overlapping.
  let len_threshold = autohint_derived_constant(outline.units_per_em, 8).max(1)
  // Heuristic value to weight lengths.
  let len_score = autohint_derived_constant(outline.units_per_em, 6000)
  let dist_score = 3000
  for ix1 in 0..<axis.segments.length() {
    let seg1 = axis.segments.at(ix1)
    if seg1.dir != axis.major_dir {
      continue
    }
    let pos1 = seg1.pos
    for ix2 in 0..<axis.segments.length() {
      let seg1v = axis.segments.at(ix1)
      let seg2 = axis.segments.at(ix2)
      let pos2 = seg2.pos
      if seg1v.dir.is_opposite(seg2.dir) && pos2 > pos1 {
        let min0 = seg1v.min_coord.max(seg2.min_coord)
        let max0 = seg1v.max_coord.min(seg2.max_coord)
        let len = max0 - min0
        if len >= len_threshold {
          let dist = pos2 - pos1
          let dist_demerit = if max_width != 0 {
            let delta = (dist << 10) / max_width - (1 << 10)
            if delta > 10000 {
              AUTOHINT_SEG_MAX_SCORE
            } else if delta > 0 {
              delta * delta / dist_score
            } else {
              0
            }
          } else {
            dist
          }
          let score = dist_demerit + len_score / len
          if score < seg1v.score {
            let s1 = axis.segments.at(ix1)
            s1.score = score
            s1.link_ix = Some(ix2)
            axis.segments.set(ix1, s1)
          }
          if score < seg2.score {
            let s2 = axis.segments.at(ix2)
            s2.score = score
            s2.link_ix = Some(ix1)
            axis.segments.set(ix2, s2)
          }
        }
      }
    }
  }
  // Serif pass.
  for ix1 in 0..<axis.segments.length() {
    let seg1 = axis.segments.at(ix1)
    match seg1.link_ix {
      None => ()
      Some(ix2) => {
        let seg2_link = axis.segments.at(ix2).link_ix
        if seg2_link != Some(ix1) {
          let s1 = axis.segments.at(ix1)
          s1.link_ix = None
          s1.serif_ix = seg2_link
          axis.segments.set(ix1, s1)
        }
      }
    }
  }
}

///|
fn autohint_link_segments_cjk(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
  scale : Int,
) -> Unit {
  // Heuristic value to set up a minimum for overlapping.
  let len_threshold = autohint_derived_constant(outline.units_per_em, 8)
  let dist_threshold = autohint_fixed_div(64 * 3, scale)
  for ix1 in 0..<axis.segments.length() {
    let seg1 = axis.segments.at(ix1)
    if seg1.dir != axis.major_dir {
      continue
    }
    let pos1 = seg1.pos
    for ix2 in 0..<axis.segments.length() {
      let seg1v = axis.segments.at(ix1)
      let seg2 = axis.segments.at(ix2)
      if ix1 == ix2 || !seg1v.dir.is_opposite(seg2.dir) {
        continue
      }
      let pos2 = seg2.pos
      let dist = pos2 - pos1
      if dist < 0 {
        continue
      }
      let min0 = seg1v.min_coord.max(seg2.min_coord)
      let max0 = seg1v.max_coord.min(seg2.max_coord)
      let len = max0 - min0
      if len >= len_threshold {
        if autohint_check_seg_cjk(dist, len, seg1v) {
          let s = axis.segments.at(ix1)
          s.score = dist
          s.len = len
          s.link_ix = Some(ix2)
          axis.segments.set(ix1, s)
        }
        if autohint_check_seg_cjk(dist, len, seg2) {
          let s = axis.segments.at(ix2)
          s.score = dist
          s.len = len
          s.link_ix = Some(ix1)
          axis.segments.set(ix2, s)
        }
      }
    }
  }
  // Serif / cleanup pass (ported structure, simplified).
  for ix1 in 0..<axis.segments.length() {
    let seg1 = axis.segments.at(ix1)
    if seg1.score >= dist_threshold {
      continue
    }
    let link1_ix = match seg1.link_ix {
      None => continue
      Some(v) => v
    }
    let link1 = axis.segments.at(link1_ix)
    if link1.link_ix != Some(ix1) || link1.pos <= seg1.pos {
      continue
    }
    for ix2 in 0..<axis.segments.length() {
      let seg2 = axis.segments.at(ix2)
      if seg2.pos > seg1.pos || ix1 == ix2 {
        continue
      }
      let link2_ix = match seg2.link_ix {
        None => continue
        Some(v) => v
      }
      let link2 = axis.segments.at(link2_ix)
      if link2.link_ix != Some(ix2) || link2.pos < link1.pos {
        continue
      }
      if seg1.pos == seg2.pos && link1.pos == link2.pos {
        continue
      }
      if seg2.score <= seg1.score || seg1.score * 4 <= seg2.score {
        continue
      }
      if seg1.len >= seg2.len * 3 {
        for i in 0..<axis.segments.length() {
          let seg = axis.segments.at(i)
          match seg.link_ix {
            Some(v) =>
              if v == ix2 {
                seg.link_ix = None
                seg.serif_ix = Some(link1_ix)
              } else if v == link2_ix {
                seg.link_ix = None
                seg.serif_ix = Some(ix1)
              }
            None => ()
          }
          axis.segments.set(i, seg)
        }
      } else {
        let s1 = axis.segments.at(ix1)
        let l1 = axis.segments.at(link1_ix)
        s1.link_ix = None
        l1.link_ix = None
        axis.segments.set(ix1, s1)
        axis.segments.set(link1_ix, l1)
        break
      }
    }
  }
  for ix1 in 0..<axis.segments.length() {
    let seg1 = axis.segments.at(ix1)
    let seg2 = match seg1.link_ix {
      None => continue
      Some(ix2) => axis.segments.at(ix2)
    }
    if seg2.link_ix != Some(ix1) {
      let s1 = axis.segments.at(ix1)
      s1.link_ix = None
      if seg2.score < dist_threshold || seg1.score < seg2.score * 4 {
        s1.serif_ix = seg2.link_ix
      }
      axis.segments.set(ix1, s1)
    }
  }
}

///|
fn autohint_link_segments(
  outline : AutoHintOutline,
  axis : AutoHintAxis,
  scale : Int,
  group : AutoHintScriptGroup,
  max_width : Int?,
) -> Unit {
  // Silence unused_constructor warnings until the full autohinter integration
  // is in place.
  AutoHintScriptGroup::Cjk |> ignore
  match group {
    AutoHintScriptGroup::Default =>
      autohint_link_segments_default(outline, axis, max_width.unwrap_or(0))
    AutoHintScriptGroup::Cjk => autohint_link_segments_cjk(outline, axis, scale)
  }
}

///|
fn autohint_check_seg_cjk(dist : Int, len : Int, seg : AutoHintSegment) -> Bool {
  dist * 8 < seg.score * 9 && (dist * 8 < seg.score * 7 || seg.len < len)
}
