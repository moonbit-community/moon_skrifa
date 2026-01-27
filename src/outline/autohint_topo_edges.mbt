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
/// Edge detection for the autohint topology.
///
/// Ported from `fontations/skrifa/src/outline/autohint/topo/edges.rs`
/// (Apache-2.0 OR MIT).

///|
const AUTOHINT_FLAG_NORMAL : Int = 0

///|
const AUTOHINT_FLAG_ROUND : Int = 1

///|
const AUTOHINT_FLAG_SERIF : Int = 2

///|
const AUTOHINT_FLAG_DONE : Int = 4

///|
const AUTOHINT_FLAG_NEUTRAL : Int = 8

///|
const EDGE_DISTANCE_THRESHOLD_MAX : Int = 64 / 4

///|
priv struct AutoHintEdge {
  mut fpos : Int
  mut opos : Int
  mut pos : Int
  mut flags : Int
  mut dir : AutoHintDirection
  mut link_ix : Int?
  mut serif_ix : Int?
  mut scale : Int
  mut first_ix : Int
  mut last_ix : Int
}

///|
fn AutoHintEdge::default() -> AutoHintEdge {
  AutoHintEdge::{
    fpos: 0,
    opos: 0,
    pos: 0,
    flags: AUTOHINT_FLAG_NORMAL,
    dir: AutoHintDirection::None_,
    link_ix: None,
    serif_ix: None,
    scale: 0,
    first_ix: 0,
    last_ix: 0,
  }
}

///|
fn autohint_abs_i32(v : Int) -> Int {
  if v < 0 {
    -v
  } else {
    v
  }
}

///|
fn AutoHintSegment::link(
  self : AutoHintSegment,
  segments : Array[AutoHintSegment],
) -> AutoHintSegment? {
  match self.link_ix {
    None => None
    Some(ix) => segments.get(ix)
  }
}

///|
fn AutoHintAxis::insert_edge(
  self : AutoHintAxis,
  edge : AutoHintEdge,
  top_to_bottom_hinting : Bool,
) -> Unit {
  self.edges.push(edge)
  // If this is the first edge, we're done.
  if self.edges.length() == 1 {
    return
  }
  // Now move it into place.
  let mut ix = self.edges.length() - 1
  while ix > 0 {
    let prev_ix = ix - 1
    let prev_edge = self.edges[prev_ix]
    let prev_fpos = prev_edge.fpos
    if (top_to_bottom_hinting && prev_fpos > edge.fpos) ||
      (!top_to_bottom_hinting && prev_fpos < edge.fpos) {
      break
    }
    // Edges with the same position and minor direction should appear before
    // those with the major direction.
    if prev_fpos == edge.fpos && edge.dir == self.major_dir {
      break
    }
    self.edges[ix] = prev_edge
    ix = ix - 1
  }
  self.edges[ix] = edge
}

///|
fn AutoHintAxis::append_segment_to_edge(
  self : AutoHintAxis,
  segment_ix : Int,
  edge_ix : Int,
) -> Unit {
  let edge = self.edges.at(edge_ix)
  let first_ix = edge.first_ix
  let last_ix = edge.last_ix
  edge.last_ix = segment_ix
  let segment = self.segments.at(segment_ix)
  segment.edge_next_ix = Some(first_ix)
  self.segments.at(last_ix).edge_next_ix = Some(segment_ix)
}

///|
fn autohint_link_segments_to_edges(axis : AutoHintAxis) -> Unit {
  let segments = axis.segments
  for edge_ix in 0..<axis.edges.length() {
    let edge = axis.edges.at(edge_ix)
    let mut ix = edge.first_ix
    let last_ix = edge.last_ix
    while true {
      let segment = segments.at(ix)
      segment.edge_ix = Some(edge_ix)
      if ix == last_ix {
        break
      }
      ix = match segment.edge_next_ix {
        None => last_ix
        Some(next_ix) => next_ix
      }
    }
  }
}

///|
fn autohint_compute_edge_properties(axis : AutoHintAxis) -> Unit {
  let segments = axis.segments
  for edge_ix in 0..<axis.edges.length() {
    let mut roundness = 0
    let mut straightness = 0
    let mut segment_ix = axis.edges.at(edge_ix).first_ix
    let last_segment_ix = axis.edges.at(edge_ix).last_ix
    while true {
      // This loop can modify the current edge, so reload it here.
      let edge = axis.edges.at(edge_ix)
      let segment = segments.at(segment_ix)
      let next_segment_ix = segment.edge_next_ix
      // Check roundness.
      if (segment.flags & AUTOHINT_FLAG_ROUND) != 0 {
        roundness = roundness + 1
      } else {
        straightness = straightness + 1
      }
      // Check for serifs.
      let is_serif = match segment.serif_ix {
        None => false
        Some(serif_ix) => {
          let serif = segments.at(serif_ix)
          match serif.edge_ix {
            None => false
            Some(serif_edge_ix) => serif_edge_ix != edge_ix
          }
        }
      }
      // Check for links.
      let has_link = match segment.link_ix {
        None => false
        Some(link_ix) => segments.at(link_ix).edge_ix is Some(_)
      }
      if is_serif || has_link {
        let (edge2_ix0, segment2_ix0) = if is_serif {
          (edge.serif_ix, segment.serif_ix)
        } else {
          (edge.link_ix, segment.link_ix)
        }
        let edge2_ix = match (edge2_ix0, segment2_ix0) {
          (Some(edge2_ix), Some(segment2_ix)) => {
            let edge2 = axis.edges.at(edge2_ix)
            let edge_delta = autohint_abs_i32(edge.fpos - edge2.fpos)
            let segment2 = segments.at(segment2_ix)
            let segment_delta = autohint_abs_i32(segment.pos - segment2.pos)
            if segment_delta < edge_delta {
              segment2.edge_ix
            } else {
              Some(edge2_ix)
            }
          }
          (_, Some(segment2_ix)) => segments.at(segment2_ix).edge_ix
          (edge2_ix, _) => edge2_ix
        }
        if is_serif {
          axis.edges.at(edge_ix).serif_ix = edge2_ix
          if edge2_ix is Some(edge2_ix) {
            let edge2 = axis.edges.at(edge2_ix)
            edge2.flags = edge2.flags | AUTOHINT_FLAG_SERIF
          }
        } else {
          axis.edges.at(edge_ix).link_ix = edge2_ix
        }
      }
      if segment_ix == last_segment_ix {
        break
      }
      segment_ix = match next_segment_ix {
        None => last_segment_ix
        Some(ix) => ix
      }
    }
    let edge = axis.edges.at(edge_ix)
    edge.flags = AUTOHINT_FLAG_NORMAL
    if roundness > 0 && roundness >= straightness {
      edge.flags = edge.flags | AUTOHINT_FLAG_ROUND
    }
    // Drop serifs for linked edges.
    if edge.serif_ix is Some(_) && edge.link_ix is Some(_) {
      edge.serif_ix = None
    }
  }
}

///|
fn autohint_compute_edges(
  axis : AutoHintAxis,
  initial_edge_distance_threshold : Int,
  top_to_bottom_hinting : Bool,
  y_scale : Int,
  scale : Int,
  group : AutoHintScriptGroup,
) -> Unit {
  axis.edges.clear()
  // This is always passed as 0 in functions that take hinting direction in CJK.
  let top_to_bottom_hinting = if axis.dim == AUTOHINT_DIM_HORIZONTAL ||
    !(group is AutoHintScriptGroup::Default) {
    false
  } else {
    top_to_bottom_hinting
  }
  // Ignore horizontal segments less than 1 pixel in length.
  let segment_length_threshold = if axis.dim == AUTOHINT_DIM_HORIZONTAL {
    autohint_fixed_div(64, y_scale)
  } else {
    0
  }
  // Also ignore segments with a width delta larger than 0.5 pixels.
  let segment_width_threshold = autohint_fixed_div(32, scale)
  // Ensure that edge distance threshold is less than or equal to 0.25 pixels.
  let initial_threshold = initial_edge_distance_threshold
  let edge_distance_threshold = if group is AutoHintScriptGroup::Default {
    autohint_fixed_div(
      autohint_fixed_mul(initial_threshold, scale).min(
        EDGE_DISTANCE_THRESHOLD_MAX,
      ),
      scale,
    )
  } else {
    // CJK uses a slightly different computation here.
    let threshold = autohint_fixed_mul(initial_threshold, scale)
    if threshold > EDGE_DISTANCE_THRESHOLD_MAX {
      autohint_fixed_div(EDGE_DISTANCE_THRESHOLD_MAX, scale)
    } else {
      initial_threshold
    }
  }
  // Now build the sorted table of edges by looping over all segments
  // to find a matching edge, adding a new one if not found.
  for segment_ix in 0..<axis.segments.length() {
    let segment = axis.segments.at(segment_ix)
    if group is AutoHintScriptGroup::Default {
      // Ignore segments that are too short, too wide or direction-less.
      if segment.height < segment_length_threshold ||
        segment.delta > segment_width_threshold ||
        segment.dir == AutoHintDirection::None_ {
        continue
      }
      // Ignore serif edges that are smaller than 1.5 pixels.
      if segment.serif_ix is Some(_) &&
        2 * segment.height < 3 * segment_length_threshold {
        continue
      }
    }
    // Look for a corresponding edge for this segment.
    let mut best_dist = AUTOHINT_SEG_MAX_SCORE
    let mut best_edge_ix : Int? = None
    for edge_ix in 0..<axis.edges.length() {
      let edge = axis.edges.at(edge_ix)
      let dist = autohint_abs_i32(segment.pos - edge.fpos)
      if dist < edge_distance_threshold &&
        edge.dir == segment.dir &&
        dist < best_dist {
        if group is AutoHintScriptGroup::Default {
          best_edge_ix = Some(edge_ix)
          break
        }
        // For CJK, we add some additional checks.
        match segment.link(axis.segments) {
          None => ()
          Some(link) => {
            // Check whether all linked segments of the candidate edge can make a single edge.
            let first_ix = edge.first_ix
            let mut seg1_ix = first_ix
            let mut dist2 = 0
            while true {
              let seg1 = axis.segments.at(seg1_ix)
              match seg1.link(axis.segments) {
                None => ()
                Some(link1) => {
                  dist2 = autohint_abs_i32(link.pos - link1.pos)
                  if dist2 >= edge_distance_threshold {
                    break
                  }
                }
              }
              if seg1.edge_next_ix == Some(first_ix) {
                break
              }
              match seg1.edge_next_ix {
                None => break
                Some(next_ix) => seg1_ix = next_ix
              }
            }
            if dist2 >= edge_distance_threshold {
              continue
            }
          }
        }
        best_dist = dist
        best_edge_ix = Some(edge_ix)
      }
    }
    match best_edge_ix {
      Some(edge_ix) => axis.append_segment_to_edge(segment_ix, edge_ix)
      None => {
        // We couldn't find an edge, so add a new one for this segment.
        let opos = autohint_fixed_mul(segment.pos, scale)
        let edge = AutoHintEdge::default()
        edge.fpos = segment.pos
        edge.opos = opos
        edge.pos = opos
        edge.dir = segment.dir
        edge.first_ix = segment_ix
        edge.last_ix = segment_ix
        axis.insert_edge(edge, top_to_bottom_hinting)
        axis.segments.at(segment_ix).edge_next_ix = Some(segment_ix)
      }
    }
  }
  if group is AutoHintScriptGroup::Default {
    // Loop again to find single point segments without a direction and
    // associate them with an existing edge if possible.
    for segment_ix in 0..<axis.segments.length() {
      let segment = axis.segments.at(segment_ix)
      if segment.dir != AutoHintDirection::None_ {
        continue
      }
      // Try to find an edge that coincides with this segment within the threshold.
      let mut found_edge_ix : Int? = None
      for edge_ix in 0..<axis.edges.length() {
        let edge = axis.edges.at(edge_ix)
        if autohint_abs_i32(segment.pos - edge.fpos) < edge_distance_threshold {
          found_edge_ix = Some(edge_ix)
          break
        }
      }
      match found_edge_ix {
        None => ()
        Some(edge_ix) => axis.append_segment_to_edge(segment_ix, edge_ix)
      }
    }
  }
  autohint_link_segments_to_edges(axis)
  autohint_compute_edge_properties(axis)
}

///|
test "autohint topo: edges simple" {
  AUTOHINT_FLAG_DONE |> ignore
  AUTOHINT_FLAG_NEUTRAL |> ignore
  let axis = AutoHintAxis::default()
  axis.reset(AUTOHINT_DIM_HORIZONTAL, None)
  let s0 = AutoHintSegment::default()
  s0.flags = AUTOHINT_FLAG_ROUND
  s0.dir = AutoHintDirection::Up
  s0.pos = 100
  s0.delta = 0
  s0.height = 100
  s0.link_ix = Some(2)
  axis.segments.push(s0)
  let s1 = AutoHintSegment::default()
  s1.flags = AUTOHINT_FLAG_ROUND
  s1.dir = AutoHintDirection::Up
  s1.pos = 105
  s1.delta = 0
  s1.height = 100
  axis.segments.push(s1)
  let s2 = AutoHintSegment::default()
  s2.dir = AutoHintDirection::Down
  s2.pos = 200
  s2.delta = 0
  s2.height = 100
  s2.link_ix = Some(0)
  axis.segments.push(s2)
  let s3 = AutoHintSegment::default()
  s3.dir = AutoHintDirection::None_
  s3.pos = 103
  s3.delta = 0
  s3.height = 100
  axis.segments.push(s3)
  autohint_compute_edges(
    axis,
    10,
    false,
    1 << 16,
    1 << 16,
    AutoHintScriptGroup::Default,
  )
  inspect(axis.edges.length().to_string(), content="2")
  inspect(axis.edges.at(0).fpos.to_string(), content="100")
  inspect(axis.edges.at(0).opos.to_string(), content="100")
  inspect(axis.edges.at(0).pos.to_string(), content="100")
  inspect(axis.edges.at(0).scale.to_string(), content="0")
  inspect(axis.edges.at(1).fpos.to_string(), content="200")
  // Edge 0 is round (1 round + 1 straight + 1 dirless segment ignored for roundness).
  inspect(
    ((axis.edges.at(0).flags & AUTOHINT_FLAG_ROUND) != 0).to_string(),
    content="true",
  )
  // Links are promoted from segment links.
  match axis.edges.at(0).link_ix {
    None => inspect("None", content="Some")
    Some(ix) => inspect(ix.to_string(), content="1")
  }
  match axis.edges.at(1).link_ix {
    None => inspect("None", content="Some")
    Some(ix) => inspect(ix.to_string(), content="0")
  }
}
