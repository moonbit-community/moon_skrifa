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
/// Edge grid-fitting for the autohinter.
///
/// Ported from `fontations/skrifa/src/outline/autohint/hint/edges.rs`
/// (Apache-2.0 OR MIT).

///|
priv struct AutoHintWidthMetrics {
  is_extra_light : Bool
}

///|
priv struct AutoHintScaledWidth {
  scaled : Int
}

///|
priv struct AutoHintScaledAxisMetrics {
  dim : Int
  widths : Array[AutoHintScaledWidth]
  width_metrics : AutoHintWidthMetrics
}

///|
fn autohint_pix_round(a : Int) -> Int {
  (a + 32) & -64
}

///|
fn autohint_fixed_mul_div(a : Int, b : Int, c : Int) -> Int {
  if c == 0 {
    0
  } else {
    let prod = a.to_int64() * b.to_int64()
    let denom = c.to_int64()
    let half = denom.abs() / 2
    if prod >= 0 {
      ((prod + half) / denom).to_int()
    } else {
      ((prod - half) / denom).to_int()
    }
  }
}

///|
fn autohint_snap_width(widths : Array[AutoHintScaledWidth], width : Int) -> Int {
  let mut best_dist = 64 + 32 + 2
  let mut ref_width = width
  for candidate in widths.iter() {
    let dist = (width - candidate.scaled).abs()
    if dist < best_dist {
      best_dist = dist
      ref_width = candidate.scaled
    }
  }
  let scaled = autohint_pix_round(ref_width)
  if width >= ref_width {
    if width < scaled + 48 {
      ref_width
    } else {
      width
    }
  } else if width > scaled - 48 {
    ref_width
  } else {
    width
  }
}

///|
fn autohint_stem_width(
  metrics : AutoHintScaledAxisMetrics,
  group : AutoHintScriptGroup,
  scale : AutoHintScale,
  width : Int,
  base_delta : Int,
  base_flags : Int,
  stem_flags : Int,
) -> Int {
  if (scale.flags & AUTOHINT_SCALE_STEM_ADJUST) == 0 ||
    (
      group is AutoHintScriptGroup::Default &&
      metrics.width_metrics.is_extra_light
    ) {
    return width
  }
  let is_vertical = metrics.dim == AUTOHINT_DIM_VERTICAL
  let sign = if width < 0 { -1 } else { 1 }
  let mut dist = width.abs()
  let do_smooth = (
      is_vertical && (scale.flags & AUTOHINT_SCALE_VERTICAL_SNAP) == 0
    ) ||
    (!is_vertical && (scale.flags & AUTOHINT_SCALE_HORIZONTAL_SNAP) == 0)
  if do_smooth {
    if group is AutoHintScriptGroup::Default {
      if (stem_flags & AUTOHINT_FLAG_SERIF) != 0 && is_vertical && dist < 3 * 64 {
        return dist * sign
      } else if (base_flags & AUTOHINT_FLAG_ROUND) != 0 {
        if dist < 80 {
          dist = 64
        }
      } else if dist < 56 {
        dist = 56
      }
    }
    if !metrics.widths.is_empty() {
      let min_width = metrics.widths.at(0).scaled
      let delta = (dist - min_width).abs()
      if delta < 40 {
        dist = min_width.max(48)
        return dist * sign
      }
      if group is AutoHintScriptGroup::Default {
        if dist < 3 * 64 {
          let delta = dist & 63
          dist = dist & -64
          if delta < 10 {
            dist = dist + delta
          } else if delta < 32 {
            dist = dist + 10
          } else if delta < 54 {
            dist = dist + 54
          } else {
            dist = dist + delta
          }
        } else {
          let mut new_base_delta = 0
          if (width > 0 && base_delta > 0) || (width < 0 && base_delta < 0) {
            if scale.size < 10.0 {
              new_base_delta = base_delta
            } else if scale.size < 30.0 {
              new_base_delta = base_delta * (30.0 - scale.size).to_int() / 20
            }
          }
          dist = (dist - new_base_delta.abs() + 32) & -64
        }
      } else if dist < 54 {
        dist = dist + (54 - dist) / 2
      } else if dist < 3 * 64 {
        let delta = dist & 63
        dist = dist & -64
        if delta < 10 {
          dist = dist + delta
        } else if delta < 22 {
          dist = dist + 10
        } else if delta < 42 {
          dist = dist + delta
        } else if delta < 54 {
          dist = dist + 54
        } else {
          dist = dist + delta
        }
      }
    }
  } else {
    let original_dist = dist
    dist = autohint_snap_width(metrics.widths, dist)
    if is_vertical {
      if dist >= 64 {
        dist = (dist + 16) & -64
      } else {
        dist = 64
      }
    } else if (scale.flags & AUTOHINT_SCALE_MONO) != 0 {
      if dist < 64 {
        dist = 64
      } else {
        dist = (dist + 32) & -64
      }
    } else if dist < 48 {
      dist = (dist + 64) >> 1
    } else if dist < 128 {
      dist = (dist + 22) & -64
      if group is AutoHintScriptGroup::Default {
        let delta = (dist - original_dist).abs()
        if delta >= 16 {
          dist = original_dist
          if dist < 48 {
            dist = (dist + 64) >> 1
          }
        }
      }
    } else {
      dist = (dist + 32) & -64
    }
  }
  dist * sign
}

///|
fn autohint_align_linked_edge(
  axis : AutoHintAxis,
  metrics : AutoHintScaledAxisMetrics,
  group : AutoHintScriptGroup,
  scale : AutoHintScale,
  base_edge_ix : Int,
  stem_edge_ix : Int,
) -> Unit {
  let base = axis.edges.at(base_edge_ix)
  let stem = axis.edges.at(stem_edge_ix)
  let width = stem.opos - base.opos
  let base_delta = base.pos - base.opos
  let fitted = autohint_stem_width(
    metrics,
    group,
    scale,
    width,
    base_delta,
    base.flags,
    stem.flags,
  )
  axis.edges.at(stem_edge_ix).pos = base.pos + fitted
}

///|
fn autohint_align_serif_edge(
  axis : AutoHintAxis,
  base_edge_ix : Int,
  serif_edge_ix : Int,
) -> Unit {
  let base = axis.edges.at(base_edge_ix)
  let serif = axis.edges.at(serif_edge_ix)
  axis.edges.at(serif_edge_ix).pos = base.pos + (serif.opos - base.opos)
}

///|
priv enum AutoHintLinkDir {
  Prev
  Next
}

///|
fn autohint_edge_link(
  edge : AutoHintEdge,
  edges : Array[AutoHintEdge],
) -> AutoHintEdge? {
  match edge.link_ix {
    None => None
    Some(ix) => edges.get(ix)
  }
}

///|
fn autohint_find_bounding_completed_edges(
  edges : Array[AutoHintEdge],
  ix : Int,
) -> (Int?, Int?) {
  let mut before : Int? = None
  if ix > 0 {
    let mut j = ix - 1
    while j >= 0 {
      if (edges.at(j).flags & AUTOHINT_FLAG_DONE) != 0 {
        before = Some(j)
        break
      }
      if j == 0 {
        break
      }
      j = j - 1
    }
  }
  let mut after : Int? = None
  for j in (ix + 1)..<edges.length() {
    if (edges.at(j).flags & AUTOHINT_FLAG_DONE) != 0 {
      after = Some(j)
      break
    }
  }
  (before, after)
}

///|
fn autohint_adjust_link(
  edges : Array[AutoHintEdge],
  edge_ix : Int,
  link_dir : AutoHintLinkDir,
  top_to_bottom_hinting : Bool,
) -> Unit {
  let edge = edges.at(edge_ix)
  let (edge2, prev_edge) = if link_dir is AutoHintLinkDir::Next {
    if edge_ix + 1 >= edges.length() {
      return
    }
    let edge2 = edges.at(edge_ix + 1)
    if (edge2.flags & AUTOHINT_FLAG_DONE) == 0 {
      return
    }
    if edge_ix == 0 {
      return
    }
    (edge2, edges.at(edge_ix - 1))
  } else {
    if edge_ix == 0 {
      return
    }
    let e2 = edges.at(edge_ix - 1)
    (e2, e2)
  }
  let pos1 = edge.pos
  let pos2 = edge2.pos
  let order_check = match (link_dir, top_to_bottom_hinting) {
    (AutoHintLinkDir::Prev, true) => pos1 > pos2
    (AutoHintLinkDir::Next, false) => pos1 > pos2
    (AutoHintLinkDir::Prev, false) => pos1 < pos2
    (AutoHintLinkDir::Next, true) => pos1 < pos2
  }
  if !order_check {
    return
  }
  let link = match autohint_edge_link(edge, edges) {
    None => return
    Some(l) => l
  }
  if (link.pos - prev_edge.pos).abs() > 16 {
    edges.at(edge_ix).pos = edge2.pos
  }
}

///|
fn autohint_align_stem_edges(
  axis : AutoHintAxis,
  metrics : AutoHintScaledAxisMetrics,
  group : AutoHintScriptGroup,
  scale : AutoHintScale,
  top_to_bottom_hinting : Bool,
  anchor_ix : Int?,
) -> (Int, Int?) {
  let mut serif_count = 0
  let mut anchor_ix = anchor_ix
  // Default/Latin branch only for now; CJK branch remains TODO.
  group |> ignore
  for edge_ix in 0..<axis.edges.length() {
    let edge = axis.edges.at(edge_ix)
    if (edge.flags & AUTOHINT_FLAG_DONE) != 0 {
      continue
    }
    let edge2_ix = match edge.link_ix {
      None => {
        serif_count = serif_count + 1
        continue
      }
      Some(ix) => ix
    }
    if edge2_ix < 0 || edge2_ix >= axis.edges.length() {
      serif_count = serif_count + 1
      continue
    }
    if group is AutoHintScriptGroup::Default {
      match anchor_ix {
        Some(anchor_ix0) => {
          let anchor = axis.edges.at(anchor_ix0)
          let edge2 = axis.edges.at(edge2_ix)
          let original_pos = anchor.pos + (edge.opos - anchor.opos)
          let original_len = edge2.opos - edge.opos
          let original_center = original_pos + (original_len >> 1)
          let cur_len = autohint_stem_width(
            metrics,
            group,
            scale,
            original_len,
            0,
            edge.flags,
            edge2.flags,
          )
          if (edge2.flags & AUTOHINT_FLAG_DONE) != 0 {
            axis.edges.at(edge_ix).pos = edge2.pos - cur_len
          } else if cur_len < 96 {
            let cur_pos1 = autohint_pix_round(original_center)
            let (u_off, d_off) = if cur_len <= 64 { (32, 32) } else { (38, 26) }
            let delta1 = (original_center - (cur_pos1 - u_off)).abs()
            let delta2 = (original_center - (cur_pos1 + d_off)).abs()
            let cur_pos1 = if delta1 < delta2 {
              cur_pos1 - u_off
            } else {
              cur_pos1 + d_off
            }
            axis.edges.at(edge_ix).pos = cur_pos1 - cur_len / 2
            axis.edges.at(edge2_ix).pos = cur_pos1 + cur_len / 2
          } else {
            let cur_pos1 = autohint_pix_round(original_pos)
            let delta1 = (cur_pos1 + (cur_len >> 1) - original_center).abs()
            let cur_pos2 = autohint_pix_round(original_pos + original_len) -
              cur_len
            let delta2 = (cur_pos2 + (cur_len >> 1) - original_center).abs()
            let new_pos = if delta1 < delta2 { cur_pos1 } else { cur_pos2 }
            axis.edges.at(edge_ix).pos = new_pos
            axis.edges.at(edge2_ix).pos = new_pos + cur_len
          }
          axis.edges.at(edge_ix).flags = axis.edges.at(edge_ix).flags |
            AUTOHINT_FLAG_DONE
          axis.edges.at(edge2_ix).flags = axis.edges.at(edge2_ix).flags |
            AUTOHINT_FLAG_DONE
          if edge_ix > 0 {
            autohint_adjust_link(
              axis.edges,
              edge_ix,
              AutoHintLinkDir::Prev,
              top_to_bottom_hinting,
            )
          }
        }
        None => {
          let edge2 = axis.edges.at(edge2_ix)
          let original_len = edge2.opos - edge.opos
          let cur_len = autohint_stem_width(
            metrics,
            group,
            scale,
            original_len,
            0,
            edge.flags,
            edge2.flags,
          )
          let (u_off, d_off) = if cur_len <= 64 { (32, 32) } else { (38, 26) }
          if cur_len < 96 {
            let original_center = edge.opos + (original_len >> 1)
            let mut cur_pos1 = autohint_pix_round(original_center)
            let error1 = (original_center - (cur_pos1 - u_off)).abs()
            let error2 = (original_center - (cur_pos1 + d_off)).abs()
            if error1 < error2 {
              cur_pos1 = cur_pos1 - u_off
            } else {
              cur_pos1 = cur_pos1 + d_off
            }
            let edge_pos = cur_pos1 - cur_len / 2
            axis.edges.at(edge_ix).pos = edge_pos
            axis.edges.at(edge2_ix).pos = edge_pos + cur_len
          } else {
            axis.edges.at(edge_ix).pos = autohint_pix_round(edge.opos)
          }
          axis.edges.at(edge_ix).flags = axis.edges.at(edge_ix).flags |
            AUTOHINT_FLAG_DONE
          autohint_align_linked_edge(
            axis, metrics, group, scale, edge_ix, edge2_ix,
          )
          axis.edges.at(edge2_ix).flags = axis.edges.at(edge2_ix).flags |
            AUTOHINT_FLAG_DONE
          anchor_ix = Some(edge_ix)
        }
      }
    } else {
      // TODO: CJK edge fitting.
      serif_count = serif_count + 1
    }
  }
  (serif_count, anchor_ix)
}

///|
fn autohint_hint_lowercase_m(
  edges : Array[AutoHintEdge],
  group : AutoHintScriptGroup,
) -> Unit {
  let (edge1_ix, edge2_ix, edge3_ix) = if edges.length() == 6 {
    (0, 2, 4)
  } else {
    (1, 5, 9)
  }
  let edge1 = edges.at(edge1_ix)
  let edge2 = edges.at(edge2_ix)
  let edge3 = edges.at(edge3_ix)
  let dist1 = edge2.opos - edge1.opos
  let dist2 = edge3.opos - edge2.opos
  let span = (dist1 - dist2).abs()
  if !(group is AutoHintScriptGroup::Default) {
    let ok1 = match edge1.link_ix {
      Some(ix) => ix == edge1_ix + 1
      _ => false
    }
    let ok2 = match edge2.link_ix {
      Some(ix) => ix == edge2_ix + 1
      _ => false
    }
    let ok3 = match edge3.link_ix {
      Some(ix) => ix == edge3_ix + 1
      _ => false
    }
    if !(ok1 && ok2 && ok3) {
      return
    }
  }
  if span < 8 {
    let delta = edge3.pos - (2 * edge2.pos - edge1.pos)
    let link_ix = edge3.link_ix
    edges.at(edge3_ix).pos = edges.at(edge3_ix).pos - delta
    edges.at(edge3_ix).flags = edges.at(edge3_ix).flags | AUTOHINT_FLAG_DONE
    match link_ix {
      None => ()
      Some(ix) =>
        if ix >= 0 && ix < edges.length() {
          edges.at(ix).pos = edges.at(ix).pos - delta
          edges.at(ix).flags = edges.at(ix).flags | AUTOHINT_FLAG_DONE
        }
    }
    if edges.length() == 12 {
      edges.at(8).pos = edges.at(8).pos - delta
      edges.at(11).pos = edges.at(11).pos - delta
    }
  }
}

///|
fn autohint_align_remaining_edges(
  axis : AutoHintAxis,
  group : AutoHintScriptGroup,
  top_to_bottom_hinting : Bool,
  serif_count : Int,
  anchor_ix : Int?,
) -> Unit {
  serif_count |> ignore
  if group is AutoHintScriptGroup::Default {
    let mut anchor_ix = anchor_ix
    for edge_ix in 0..<axis.edges.length() {
      let edge = axis.edges.at(edge_ix)
      if (edge.flags & AUTOHINT_FLAG_DONE) != 0 {
        continue
      }
      let mut delta = 1000
      match edge.serif_ix {
        None => ()
        Some(serif_ix) =>
          if serif_ix >= 0 && serif_ix < axis.edges.length() {
            let serif = axis.edges.at(serif_ix)
            delta = (serif.opos - edge.opos).abs()
          }
      }
      if delta < 64 + 16 {
        match edge.serif_ix {
          None => ()
          Some(serif_ix) => autohint_align_serif_edge(axis, serif_ix, edge_ix)
        }
      } else {
        match anchor_ix {
          Some(anchor_ix0) => {
            let (before_ix, after_ix) = autohint_find_bounding_completed_edges(
              axis.edges,
              edge_ix,
            )
            match (before_ix, after_ix) {
              (Some(before_ix), Some(after_ix)) => {
                let before = axis.edges.at(before_ix)
                let after = axis.edges.at(after_ix)
                let new_pos = if after.opos == before.opos {
                  before.pos
                } else {
                  before.pos +
                  autohint_fixed_mul_div(
                    edge.opos - before.opos,
                    after.pos - before.pos,
                    after.opos - before.opos,
                  )
                }
                axis.edges.at(edge_ix).pos = new_pos
              }
              _ => {
                let anchor = axis.edges.at(anchor_ix0)
                let new_pos = anchor.pos +
                  ((edge.opos - anchor.opos + 16) & -32)
                axis.edges.at(edge_ix).pos = new_pos
              }
            }
          }
          None => {
            anchor_ix = Some(edge_ix)
            axis.edges.at(edge_ix).pos = autohint_pix_round(edge.opos)
          }
        }
      }
      axis.edges.at(edge_ix).flags = axis.edges.at(edge_ix).flags |
        AUTOHINT_FLAG_DONE
      autohint_adjust_link(
        axis.edges,
        edge_ix,
        AutoHintLinkDir::Prev,
        top_to_bottom_hinting,
      )
      autohint_adjust_link(
        axis.edges,
        edge_ix,
        AutoHintLinkDir::Next,
        top_to_bottom_hinting,
      )
    }
  } else {
    // TODO: CJK/Indic remaining edge alignment.
    group |> ignore
    top_to_bottom_hinting |> ignore
    anchor_ix |> ignore
  }
}

///|
fn autohint_hint_edges(
  axis : AutoHintAxis,
  metrics : AutoHintScaledAxisMetrics,
  group : AutoHintScriptGroup,
  scale : AutoHintScale,
  top_to_bottom_hinting : Bool,
) -> Unit {
  let mut top_to_bottom_hinting = top_to_bottom_hinting
  if axis.dim != AUTOHINT_DIM_VERTICAL {
    top_to_bottom_hinting = false
  }
  // Blue alignment is handled upstream before stem fitting; this port does not
  // yet compute blue zones, so we begin with stem fitting immediately.
  let (serif_count, anchor_ix) = autohint_align_stem_edges(
    axis,
    metrics,
    group,
    scale,
    top_to_bottom_hinting,
    None,
  )
  if axis.dim == AUTOHINT_DIM_HORIZONTAL &&
    (axis.edges.length() == 6 || axis.edges.length() == 12) {
    autohint_hint_lowercase_m(axis.edges, group)
  }
  if serif_count > 0 || anchor_ix is None {
    autohint_align_remaining_edges(
      axis, group, top_to_bottom_hinting, serif_count, anchor_ix,
    )
  }
}
