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
/// This is currently a minimal pixel snapping pass; full FreeType parity is
/// tracked in bd tasks `moon_skrifa-1ei.7.2.6` and `moon_skrifa-1ei.7.2.5`.

///|
fn autohint_pix_round(a : Int) -> Int {
  (a + 32) & -64
}

///|
/// Minimal edge hinting:
/// - snap each edge to the pixel grid
/// - keep linked edges at (rounded) stem width
fn autohint_hint_edges_simple(
  axis : AutoHintAxis,
  group : AutoHintScriptGroup,
  top_to_bottom_hinting : Bool,
) -> Unit {
  group |> ignore
  top_to_bottom_hinting |> ignore
  for edge_ix in 0..<axis.edges.length() {
    let edge = axis.edges.at(edge_ix)
    match edge.link_ix {
      None => edge.pos = autohint_pix_round(edge.opos)
      Some(link_ix) => {
        if link_ix < 0 || link_ix >= axis.edges.length() {
          edge.pos = autohint_pix_round(edge.opos)
          continue
        }
        // Only process each pair once.
        if link_ix < edge_ix {
          continue
        }
        let edge2 = axis.edges.at(link_ix)
        let dir = if edge.opos <= edge2.opos { 1 } else { -1 }
        let orig_len = (edge2.opos - edge.opos).abs()
        let fitted_len = autohint_pix_round(orig_len)
        let base = autohint_pix_round(edge.opos)
        edge.pos = base
        edge2.pos = base + dir * fitted_len
      }
    }
  }
}
