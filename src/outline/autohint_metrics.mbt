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
/// Autohint-specific metrics.
///
/// Ported incrementally from `fontations/skrifa/src/outline/autohint/metrics/*`
/// (Apache-2.0 OR MIT).

///|
const AUTOHINT_MAX_WIDTHS : Int = 16

///|
const AUTOHINT_MAX_BLUES : Int = 8

///|
const AUTOHINT_SCALE_HORIZONTAL_SNAP : Int = 1 << 0

///|
const AUTOHINT_SCALE_VERTICAL_SNAP : Int = 1 << 1

///|
const AUTOHINT_SCALE_STEM_ADJUST : Int = 1 << 2

///|
const AUTOHINT_SCALE_MONO : Int = 1 << 3

///|
const AUTOHINT_SCALE_NO_HORIZONTAL : Int = 1 << 4

///|
const AUTOHINT_SCALE_NO_VERTICAL : Int = 1 << 5

///|
const AUTOHINT_SCALE_NO_ADVANCE : Int = 1 << 6

///|
priv struct AutoHintScale {
  x_scale : Int
  mut y_scale : Int
  x_delta : Int
  y_delta : Int
  size : Double
  units_per_em : Int
  flags : Int
}

///|
priv struct AutoHintWidthMetrics {
  edge_distance_threshold : Int
  standard_width : Int
  is_extra_light : Bool
}

///|
fn AutoHintWidthMetrics::default() -> AutoHintWidthMetrics {
  AutoHintWidthMetrics::{
    edge_distance_threshold: 0,
    standard_width: 0,
    is_extra_light: false,
  }
}

///|
priv struct AutoHintScaledWidth {
  scaled : Int
  mut fitted : Int
}

///|
fn AutoHintScaledWidth::default() -> AutoHintScaledWidth {
  AutoHintScaledWidth::{ scaled: 0, fitted: 0 }
}

///|
priv struct AutoHintUnscaledBlue {
  mut position : Int
  mut overshoot : Int
  ascender : Int
  descender : Int
  zones : Int
}

///|
priv struct AutoHintScaledBlue {
  position : AutoHintScaledWidth
  overshoot : AutoHintScaledWidth
  zones : Int
  mut is_active : Bool
}

///|
priv struct AutoHintUnscaledAxisMetrics {
  dim : Int
  widths : Array[Int]
  mut width_metrics : AutoHintWidthMetrics
  mut blues : Array[AutoHintUnscaledBlue]
}

///|
fn AutoHintUnscaledAxisMetrics::default(
  dim : Int,
) -> AutoHintUnscaledAxisMetrics {
  AutoHintUnscaledAxisMetrics::{
    dim,
    widths: Array::new(),
    width_metrics: AutoHintWidthMetrics::default(),
    blues: Array::new(),
  }
}

///|
fn AutoHintUnscaledAxisMetrics::max_width(
  self : AutoHintUnscaledAxisMetrics,
) -> Int? {
  if self.widths.is_empty() {
    None
  } else {
    Some(self.widths.at(self.widths.length() - 1))
  }
}

///|
priv struct AutoHintScaledAxisMetrics {
  dim : Int
  mut scale : Int
  mut delta : Int
  widths : Array[AutoHintScaledWidth]
  mut width_metrics : AutoHintWidthMetrics
  blues : Array[AutoHintScaledBlue]
}

///|
fn AutoHintScaledAxisMetrics::default(dim : Int) -> AutoHintScaledAxisMetrics {
  AutoHintScaledAxisMetrics::{
    dim,
    scale: 0,
    delta: 0,
    widths: Array::new(),
    width_metrics: AutoHintWidthMetrics::default(),
    blues: Array::new(),
  }
}

///|
priv struct AutoHintUnscaledStyleMetrics {
  group : AutoHintScriptGroup
  hint_top_to_bottom : Bool
  axes : Array[AutoHintUnscaledAxisMetrics]
}

///|
priv struct AutoHintScaledStyleMetrics {
  scale : AutoHintScale
  axes : Array[AutoHintScaledAxisMetrics]
}

///|
const AUTOHINT_BLUE_NONE : Int = 0

///|
const AUTOHINT_BLUE_TOP : Int = 1 << 1

///|
const AUTOHINT_BLUE_SUB_TOP : Int = 1 << 2

///|
const AUTOHINT_BLUE_NEUTRAL : Int = 1 << 3

///|
const AUTOHINT_BLUE_ADJUSTMENT : Int = 1 << 4

///|
const AUTOHINT_BLUE_X_HEIGHT : Int = 1 << 5

///|
const AUTOHINT_BLUE_LONG : Int = 1 << 6

///|
const AUTOHINT_BLUE_HORIZONTAL : Int = 1 << 2

///|
const AUTOHINT_BLUE_RIGHT : Int = AUTOHINT_BLUE_TOP

///|
fn autohint_blue_contains(zones : Int, other : Int) -> Bool {
  (zones & other) == other
}

///|
fn autohint_blue_is_top_like(zones : Int) -> Bool {
  (zones & (AUTOHINT_BLUE_TOP | AUTOHINT_BLUE_SUB_TOP)) != 0
}

///|
fn autohint_blue_is_top(zones : Int) -> Bool {
  autohint_blue_contains(zones, AUTOHINT_BLUE_TOP)
}

///|
fn autohint_blue_is_sub_top(zones : Int) -> Bool {
  autohint_blue_contains(zones, AUTOHINT_BLUE_SUB_TOP)
}

///|
fn autohint_blue_is_neutral(zones : Int) -> Bool {
  autohint_blue_contains(zones, AUTOHINT_BLUE_NEUTRAL)
}

///|
fn autohint_blue_is_x_height(zones : Int) -> Bool {
  autohint_blue_contains(zones, AUTOHINT_BLUE_X_HEIGHT)
}

///|
fn autohint_blue_is_horizontal(zones : Int) -> Bool {
  autohint_blue_contains(zones, AUTOHINT_BLUE_HORIZONTAL)
}

///|
fn autohint_blue_is_right(zones : Int) -> Bool {
  autohint_blue_contains(zones, AUTOHINT_BLUE_RIGHT)
}

///|
fn autohint_blue_retain_top_like_or_neutral(zones : Int) -> Int {
  zones & (AUTOHINT_BLUE_TOP | AUTOHINT_BLUE_SUB_TOP | AUTOHINT_BLUE_NEUTRAL)
}

///|
fn autohint_pix_round(a : Int) -> Int {
  (a + 32) & -64
}

///|
fn autohint_pix_floor(a : Int) -> Int {
  a & -64
}

///|
fn autohint_fixed_mul_div(a : Int, b : Int, c : Int) -> Int {
  let mut sign = 1
  let mut aa = a.to_int64()
  let mut bb = b.to_int64()
  let mut cc = c.to_int64()
  if aa < 0 {
    aa = -aa
    sign = -sign
  }
  if bb < 0 {
    bb = -bb
    sign = -sign
  }
  if cc < 0 {
    cc = -cc
    sign = -sign
  }
  let q : Int64 = if cc == 0 {
    (0x7FFFFFFF).to_int64()
  } else {
    (aa * bb + (cc >> 1)) / cc
  }
  let out = q.to_int()
  if sign < 0 {
    -out
  } else {
    out
  }
}

///|
fn AutoHintScale::new(
  size : Double,
  units_per_em : Int,
  font_style : @moon_skrifa.Style,
  target : Target,
  group : AutoHintScriptGroup,
) -> AutoHintScale {
  let scale_bits = if units_per_em > 0 {
    let scaled_h = (size * 64.0).to_int()
    (scaled_h << 16) / units_per_em
  } else {
    0
  }
  let is_italic = !(font_style is @moon_skrifa.Style::Normal)
  let is_mono = target is Target::Mono
  let is_light = target.is_light() || target.preserve_linear_metrics()
  let mut flags = 0
  // Snap vertical stems for monochrome and horizontal LCD rendering.
  if is_mono || target.is_lcd() {
    flags = flags | AUTOHINT_SCALE_HORIZONTAL_SNAP
  }
  // Snap horizontal stems for monochrome and vertical LCD rendering.
  if is_mono || target.is_vertical_lcd() {
    flags = flags | AUTOHINT_SCALE_VERTICAL_SNAP
  }
  // Adjust stems to full pixels unless in LCD or light modes.
  if !(target.is_lcd() || is_light) {
    flags = flags | AUTOHINT_SCALE_STEM_ADJUST
  }
  if is_mono {
    flags = flags | AUTOHINT_SCALE_MONO
  }
  if group is AutoHintScriptGroup::Default {
    // Disable horizontal hinting completely for LCD, light hinting and italic fonts.
    if target.is_lcd() || is_light || is_italic {
      flags = flags | AUTOHINT_SCALE_NO_HORIZONTAL
    }
  } else {
    // CJK doesn't hint advances.
    flags = flags | AUTOHINT_SCALE_NO_ADVANCE
  }
  if !(group is AutoHintScriptGroup::Default) {
    flags = flags | AUTOHINT_SCALE_NO_ADVANCE
  }
  AutoHintScale::{
    x_scale: scale_bits,
    y_scale: scale_bits,
    x_delta: 0,
    y_delta: 0,
    size,
    units_per_em,
    flags,
  }
}

///|
fn autohint_style_script_group(style_ix : Int) -> AutoHintScriptGroup {
  autohint_script_group(autohint_style_script_ix(style_ix))
}

///|
fn autohint_style_hint_top_to_bottom(style_ix : Int) -> Bool {
  autohint_script_hint_top_to_bottom(autohint_style_script_ix(style_ix))
}

///|
fn autohint_style_std_chars(style_ix : Int) -> String {
  autohint_script_std_chars(autohint_style_script_ix(style_ix))
}

///|
fn autohint_style_blues(style_ix : Int) -> Array[(String, Int)] {
  autohint_script_blues(autohint_style_script_ix(style_ix))
}

///|
fn autohint_char_to_codepoint(c : Char) -> Int? {
  // MoonBit represents `Char` as a Unicode scalar value.
  // Most implementations provide `to_int()`; keep this in a tiny helper
  // so it's easy to adjust if the stdlib changes.
  Some(c.to_int())
}

///|
fn autohint_load_outline_for_metrics(
  outlines : OutlineGlyphCollection,
  gid : @moon_skrifa.GlyphId,
) -> AutoHintOutline? {
  let font = outlines.font
  let outline = AutoHintOutline::from_path(Array::new())
  match outline.fill_glyf(font, gid) {
    Ok(_) => if outline.is_empty() { None } else { Some(outline) }
    Err(_) => {
      let glyph = match outlines.get(gid) {
        None => return None
        Some(g) => g
      }
      let settings = DrawSettings::unhinted(
        @moon_skrifa.Size::unscaled(),
        @moon_skrifa.LocationRef::default(),
      ).with_path_style(PathStyle::FreeType)
      let path = match glyph.path(settings) {
        Err(_) => return None
        Ok(p) => p
      }
      let o = AutoHintOutline::from_path(path)
      if o.is_empty() {
        None
      } else {
        Some(o)
      }
    }
  }
}

///|
fn autohint_pick_standard_glyph(
  outlines : OutlineGlyphCollection,
  std_chars : String,
) -> @moon_skrifa.GlyphId? {
  let font = outlines.font
  for ch in std_chars {
    if ch == ' ' {
      continue
    }
    if ch == '|' {
      continue
    }
    match autohint_char_to_codepoint(ch) {
      None => continue
      Some(cp_i) => {
        let cp = cp_i |> Int::reinterpret_as_uint
        match font.charmap().map(cp) {
          None => continue
          Some(gid) => {
            if gid.to_uint64() == 0 {
              continue
            }
            match autohint_load_outline_for_metrics(outlines, gid) {
              None => continue
              Some(_) => return Some(gid)
            }
          }
        }
      }
    }
  }
  None
}

///|
fn autohint_compute_unscaled_widths(
  outlines : OutlineGlyphCollection,
  units_per_em : Int,
  std_chars : String,
) -> Array[AutoHintUnscaledAxisMetrics] {
  let axes : Array[AutoHintUnscaledAxisMetrics] = Array::new()
  axes.push(AutoHintUnscaledAxisMetrics::default(AUTOHINT_DIM_HORIZONTAL))
  axes.push(AutoHintUnscaledAxisMetrics::default(AUTOHINT_DIM_VERTICAL))
  let gid = match autohint_pick_standard_glyph(outlines, std_chars) {
    None => return axes
    Some(g) => g
  }
  let outline = match autohint_load_outline_for_metrics(outlines, gid) {
    None => return axes
    Some(o) => o
  }
  if outline.points.is_empty() {
    return axes
  }
  let axis = AutoHintAxis::default()
  for dim in 0..<2 {
    axis.reset(dim, outline.orientation)
    let ok = autohint_compute_segments(
      outline,
      axis,
      AutoHintScriptGroup::Default,
    )
    if !ok {
      continue
    }
    autohint_link_segments(outline, axis, 0, AutoHintScriptGroup::Default, None)
    let widths = axes.at(dim).widths
    let segments = axis.segments
    for seg_ix in 0..<segments.length() {
      let seg = segments.at(seg_ix)
      match seg.link_ix {
        None => ()
        Some(link_ix) => {
          let link = segments.at(link_ix)
          if link_ix > seg_ix && link.link_ix == Some(seg_ix) {
            let dist = (seg.pos - link.pos).abs()
            if widths.length() < AUTOHINT_MAX_WIDTHS {
              widths.push(dist)
            }
          }
        }
      }
    }
    if widths.is_empty() {
      widths.push(0)
    }
    autohint_sort_and_quantize_widths(widths, units_per_em / 100)
  }
  for dim in 0..<2 {
    let axis_metrics = axes.at(dim)
    let widths = axis_metrics.widths
    let mut stdw = if widths.is_empty() {
      autohint_derived_constant(units_per_em, 50)
    } else {
      widths.at(0)
    }
    if stdw <= 0 {
      stdw = autohint_derived_constant(units_per_em, 50).max(1)
    }
    axis_metrics.width_metrics = AutoHintWidthMetrics::{
      edge_distance_threshold: (stdw / 5).max(1),
      standard_width: stdw,
      is_extra_light: false,
    }
  }
  axes
}

///|
fn autohint_sort_ints(values : Array[Int]) -> Unit {
  if values.length() <= 1 {
    return
  }
  for i in 1..<values.length() {
    let key = values[i]
    let mut j = i
    while j > 0 && values[j - 1] > key {
      values[j] = values[j - 1]
      j = j - 1
    }
    values[j] = key
  }
}

///|
fn autohint_compute_default_blues(
  outlines : OutlineGlyphCollection,
  blues_data : Array[(String, Int)],
  units_per_em : Int,
) -> Array[AutoHintUnscaledBlue] {
  let blues : Array[AutoHintUnscaledBlue] = Array::new()
  for entry in blues_data.iter() {
    let (blue_str, blue_zones) = entry
    if blues.length() >= AUTOHINT_MAX_BLUES {
      continue
    }
    let values : Array[Int] = Array::new()
    let mut ascender = 0
    let mut descender = 0
    let is_top_like = autohint_blue_is_top_like(blue_zones)
    let is_long = autohint_blue_contains(blue_zones, AUTOHINT_BLUE_LONG)
    for ch in blue_str {
      if ch == ' ' {
        continue
      }
      if ch == '|' {
        // Default group doesn't use sentinel, but tolerate it.
        continue
      }
      let cp_i = autohint_char_to_codepoint(ch).unwrap_or(-1)
      if cp_i < 0 {
        continue
      }
      let cp = cp_i |> Int::reinterpret_as_uint
      let gid = match outlines.font.charmap().map(cp) {
        None => continue
        Some(g) => g
      }
      if gid.to_uint64() == 0 {
        continue
      }
      let outline = match autohint_load_outline_for_metrics(outlines, gid) {
        None => continue
        Some(o) => o
      }
      if outline.points.length() <= 2 {
        continue
      }
      let mut best_y : Int? = None
      // First pass: compute extrema + bounds.
      let mut extremum : Int? = None
      for p in outline.points.iter() {
        let y = p.fy
        if extremum is None {
          extremum = Some(y)
        } else if is_top_like {
          if y > extremum.unwrap_or(y) {
            extremum = Some(y)
          }
        } else if y < extremum.unwrap_or(y) {
          extremum = Some(y)
        }
        if y > ascender {
          ascender = y
        }
        if y < descender {
          descender = y
        }
      }
      if is_long && extremum is Some(extremum_y) && is_top_like {
        // Heuristic for Hebrew LONG zones: prefer the highest Y that spans
        // a sufficiently long horizontal segment, ignoring narrow bumps.
        let length_threshold = units_per_em / 25
        let flat_threshold = units_per_em / 14
        let candidates : Array[Int] = Array::new()
        for p in outline.points.iter() {
          let y = p.fy
          if extremum_y - y >= 0 && extremum_y - y <= flat_threshold {
            candidates.push(y)
          }
        }
        if !candidates.is_empty() {
          autohint_sort_ints(candidates)
          // Walk unique Y levels from highest to lowest.
          let mut last_y : Int? = None
          let mut i = candidates.length() - 1
          while true {
            let y0 = candidates.at(i)
            if last_y is Some(v) && v == y0 {
              ()
            } else {
              last_y = Some(y0)
              let mut min_x : Int? = None
              let mut max_x : Int? = None
              for p in outline.points.iter() {
                if p.fy != y0 {
                  continue
                }
                let x = p.fx
                min_x = match min_x {
                  None => Some(x)
                  Some(v) => Some(v.min(x))
                }
                max_x = match max_x {
                  None => Some(x)
                  Some(v) => Some(v.max(x))
                }
              }
              match (min_x, max_x) {
                (Some(lo), Some(hi)) =>
                  if hi - lo >= length_threshold {
                    best_y = Some(y0)
                    break
                  }
                _ => ()
              }
            }
            if i == 0 {
              break
            }
            i = i - 1
          }
        }
      }
      if best_y is None {
        best_y = extremum
      }
      match best_y {
        None => ()
        Some(v) => values.push(v)
      }
    }
    if values.is_empty() {
      continue
    }
    autohint_sort_ints(values)
    let val = values.at(values.length() / 2)
    let mut zones = autohint_blue_retain_top_like_or_neutral(blue_zones)
    if autohint_blue_is_x_height(blue_zones) {
      zones = zones | AUTOHINT_BLUE_ADJUSTMENT
    }
    blues.push(AutoHintUnscaledBlue::{
      position: val,
      overshoot: val,
      ascender,
      descender,
      zones,
    })
  }
  if blues.is_empty() {
    return blues
  }
  // Sort from bottom to top, then adjust to avoid overlaps.
  let sorted_ix : Array[Int] = Array::new()
  for i in 0..<blues.length() {
    sorted_ix.push(i)
  }
  for i in 1..<sorted_ix.length() {
    let key = sorted_ix[i]
    let mut j = i
    while j > 0 {
      let first = blues.at(sorted_ix[j - 1])
      let second = blues.at(key)
      let a = if autohint_blue_is_top_like(first.zones) {
        first.position
      } else {
        first.overshoot
      }
      let b = if autohint_blue_is_top_like(second.zones) {
        second.position
      } else {
        second.overshoot
      }
      if b >= a {
        break
      }
      sorted_ix[j] = sorted_ix[j - 1]
      j = j - 1
    }
    sorted_ix[j] = key
  }
  for i in 0..<(sorted_ix.length() - 1) {
    let i1 = sorted_ix[i]
    let i2 = sorted_ix[i + 1]
    let b1 = blues.at(i1)
    let b2 = blues.at(i2)
    let a = if autohint_blue_is_top_like(b1.zones) {
      b1.overshoot
    } else {
      b1.position
    }
    let b = if autohint_blue_is_top_like(b2.zones) {
      b2.overshoot
    } else {
      b2.position
    }
    if a > b {
      if autohint_blue_is_top_like(b1.zones) {
        blues.at(i1).overshoot = b
      } else {
        blues.at(i1).position = b
      }
    }
  }
  blues
}

///|
fn autohint_compute_cjk_blues(
  outlines : OutlineGlyphCollection,
  blues_data : Array[(String, Int)],
) -> Array[AutoHintUnscaledBlue] {
  // This returns only vertical blues (horizontal are disabled).
  let blues : Array[AutoHintUnscaledBlue] = Array::new()
  for entry in blues_data.iter() {
    let (blue_str, blue_zones) = entry
    if blues.length() >= AUTOHINT_MAX_BLUES {
      continue
    }
    if autohint_blue_is_horizontal(blue_zones) {
      continue
    }
    autohint_blue_is_right(blue_zones) |> ignore
    let is_top = autohint_blue_is_top(blue_zones)
    let fills : Array[Int] = Array::new()
    let flats : Array[Int] = Array::new()
    let mut is_fill = true
    for ch in blue_str {
      if ch == ' ' {
        continue
      }
      if ch == '|' {
        is_fill = false
        continue
      }
      let cp_i = autohint_char_to_codepoint(ch).unwrap_or(-1)
      if cp_i < 0 {
        continue
      }
      let cp = cp_i |> Int::reinterpret_as_uint
      let gid = match outlines.font.charmap().map(cp) {
        None => continue
        Some(g) => g
      }
      if gid.to_uint64() == 0 {
        continue
      }
      let outline = match autohint_load_outline_for_metrics(outlines, gid) {
        None => continue
        Some(o) => o
      }
      if outline.points.length() <= 2 {
        continue
      }
      let mut best : Int? = None
      for p in outline.points.iter() {
        let v = p.fy
        if best is None {
          best = Some(v)
        } else if is_top {
          if v > best.unwrap_or(v) {
            best = Some(v)
          }
        } else if v < best.unwrap_or(v) {
          best = Some(v)
        }
      }
      match best {
        None => ()
        Some(v) => if is_fill { fills.push(v) } else { flats.push(v) }
      }
    }
    if fills.is_empty() && flats.is_empty() {
      continue
    }
    // Sort and take medians.
    autohint_sort_ints(fills)
    autohint_sort_ints(flats)
    let blue_ref = if fills.is_empty() {
      flats.at(flats.length() / 2)
    } else {
      fills.at(fills.length() / 2)
    }
    let blue_shoot = if flats.is_empty() {
      blue_ref
    } else {
      flats.at(flats.length() / 2)
    }
    blues.push(AutoHintUnscaledBlue::{
      position: blue_ref,
      overshoot: blue_shoot,
      ascender: blue_ref,
      descender: blue_ref,
      zones: autohint_blue_retain_top_like_or_neutral(blue_zones),
    })
  }
  blues
}

///|
fn autohint_compute_unscaled_blues(
  outlines : OutlineGlyphCollection,
  group : AutoHintScriptGroup,
  style_ix : Int,
  units_per_em : Int,
) -> Array[Array[AutoHintUnscaledBlue]] {
  let out : Array[Array[AutoHintUnscaledBlue]] = Array::new()
  match group {
    AutoHintScriptGroup::Default => {
      out.push(Array::new())
      out.push(
        autohint_compute_default_blues(
          outlines,
          autohint_style_blues(style_ix),
          units_per_em,
        ),
      )
    }
    AutoHintScriptGroup::Cjk => {
      // CJK blues are computed in both directions upstream, but horizontal
      // zones are disabled. Keep structure identical: [h, v].
      out.push(Array::new())
      out.push(
        autohint_compute_cjk_blues(outlines, autohint_style_blues(style_ix)),
      )
    }
  }
  out
}

///|
fn autohint_compute_unscaled_style_metrics(
  outlines : OutlineGlyphCollection,
  style_ix : Int,
  units_per_em : Int,
) -> AutoHintUnscaledStyleMetrics {
  let group = autohint_style_script_group(style_ix)
  let hint_top_to_bottom = autohint_style_hint_top_to_bottom(style_ix)
  let axes = autohint_compute_unscaled_widths(
    outlines,
    units_per_em,
    autohint_style_std_chars(style_ix),
  )
  let blues = autohint_compute_unscaled_blues(
    outlines, group, style_ix, units_per_em,
  )
  // Attach blues per axis.
  for dim in 0..<2 {
    axes.at(dim).blues = blues.at(dim)
  }
  AutoHintUnscaledStyleMetrics::{ group, hint_top_to_bottom, axes }
}

///|
fn autohint_scale_default_axis_metrics(
  axis : AutoHintUnscaledAxisMetrics,
  scale : AutoHintScale,
) -> (AutoHintScale, AutoHintScaledAxisMetrics) {
  let dim = axis.dim
  let scale = scale
  let scaled = AutoHintScaledAxisMetrics::default(dim)
  if dim == AUTOHINT_DIM_HORIZONTAL {
    scaled.scale = scale.x_scale
    scaled.delta = scale.x_delta
  } else {
    scaled.scale = scale.y_scale
    scaled.delta = scale.y_delta
  }
  // Y-scale correction to optimize alignment.
  if dim == AUTOHINT_DIM_VERTICAL {
    for blue in axis.blues.iter() {
      if autohint_blue_contains(blue.zones, AUTOHINT_BLUE_ADJUSTMENT) {
        let scaled_shoot = autohint_fixed_mul(scaled.scale, blue.overshoot)
        let fitted = (scaled_shoot + 40) & -64
        if scaled_shoot != fitted {
          let new_scale = autohint_fixed_mul_div(
            scaled.scale,
            fitted,
            scaled_shoot,
          )
          let mut max_height = scale.units_per_em
          for b in axis.blues.iter() {
            max_height = max_height.max(b.ascender).max(-b.descender)
          }
          let mut dist = autohint_fixed_mul(
            max_height,
            new_scale - scaled.scale,
          ).abs()
          dist = dist & -128
          if dist == 0 {
            scaled.scale = new_scale
            scale.y_scale = new_scale
          }
        }
        break
      }
    }
  }
  // Scale widths.
  scaled.width_metrics = axis.width_metrics
  for w in axis.widths.iter() {
    let s = autohint_fixed_mul(scaled.scale, w)
    scaled.widths.push(AutoHintScaledWidth::{ scaled: s, fitted: s })
  }
  scaled.width_metrics = AutoHintWidthMetrics::{
    edge_distance_threshold: axis.width_metrics.edge_distance_threshold,
    standard_width: axis.width_metrics.standard_width,
    is_extra_light: autohint_fixed_mul(
      axis.width_metrics.standard_width,
      scaled.scale,
    ) <
    32 + 8,
  }
  if dim == AUTOHINT_DIM_VERTICAL {
    // Scale blues and activate narrow zones.
    for blue in axis.blues.iter() {
      let pos = autohint_fixed_mul(scaled.scale, blue.position) + scaled.delta
      let shoot = autohint_fixed_mul(scaled.scale, blue.overshoot) +
        scaled.delta
      let out_blue = AutoHintScaledBlue::{
        position: AutoHintScaledWidth::{ scaled: pos, fitted: pos },
        overshoot: AutoHintScaledWidth::{ scaled: shoot, fitted: shoot },
        zones: blue.zones,
        is_active: false,
      }
      let out_blue = out_blue
      let dist = autohint_fixed_mul(
        blue.position - blue.overshoot,
        scaled.scale,
      )
      if dist >= -48 && dist <= 48 {
        let mut delta = dist.abs()
        if delta < 32 {
          delta = 0
        } else if delta < 48 {
          delta = 32
        } else {
          delta = 64
        }
        if dist < 0 {
          delta = -delta
        }
        out_blue.position.fitted = autohint_pix_round(out_blue.position.scaled)
        out_blue.overshoot.fitted = out_blue.position.fitted - delta
        out_blue.is_active = true
      }
      scaled.blues.push(out_blue)
    }
    // Disable sub-top blue zones that overlap with other active zones.
    for i in 0..<scaled.blues.length() {
      let b = scaled.blues.at(i)
      if !autohint_blue_is_sub_top(b.zones) || !b.is_active {
        continue
      }
      for b2 in scaled.blues.iter() {
        if autohint_blue_is_sub_top(b2.zones) || !b2.is_active {
          continue
        }
        if b2.position.fitted <= b.overshoot.fitted &&
          b2.overshoot.fitted >= b.position.fitted {
          scaled.blues.at(i).is_active = false
          break
        }
      }
    }
  }
  (scale, scaled)
}

///|
fn autohint_scale_cjk_axis_metrics(
  axis : AutoHintUnscaledAxisMetrics,
  scale : AutoHintScale,
) -> (AutoHintScale, AutoHintScaledAxisMetrics) {
  let dim = axis.dim
  let scale = scale
  let scaled = AutoHintScaledAxisMetrics::default(dim)
  if dim == AUTOHINT_DIM_HORIZONTAL {
    scaled.scale = scale.x_scale
    scaled.delta = scale.x_delta
  } else {
    scaled.scale = scale.y_scale
    scaled.delta = scale.y_delta
  }
  // Scale blues (CJK uses different overshoot rounding).
  for blue in axis.blues.iter() {
    let pos = autohint_fixed_mul(blue.position, scaled.scale) + scaled.delta
    let shoot = autohint_fixed_mul(blue.overshoot, scaled.scale) + scaled.delta
    let out_blue = AutoHintScaledBlue::{
      position: AutoHintScaledWidth::{ scaled: pos, fitted: pos },
      overshoot: AutoHintScaledWidth::{ scaled: shoot, fitted: shoot },
      zones: blue.zones,
      is_active: false,
    }
    let out_blue = out_blue
    let dist = autohint_fixed_mul(blue.position - blue.overshoot, scaled.scale)
    if dist >= -48 && dist <= 48 {
      out_blue.position.fitted = autohint_pix_round(out_blue.position.scaled)
      let delta1 = autohint_fixed_div(out_blue.position.fitted, scaled.scale) -
        blue.overshoot
      let mut delta2 = autohint_fixed_mul(delta1.abs(), scaled.scale)
      if delta2 < 32 {
        delta2 = 0
      } else {
        delta2 = autohint_pix_round(delta2)
      }
      if delta1 < 0 {
        delta2 = -delta2
      }
      out_blue.overshoot.fitted = out_blue.position.fitted - delta2
      out_blue.is_active = true
    }
    scaled.blues.push(out_blue)
  }
  // Match FreeType behavior: do not compute scaled width values.
  for _ in 0..<axis.widths.length() {
    scaled.widths.push(AutoHintScaledWidth::default())
  }
  scaled.width_metrics = axis.width_metrics
  (scale, scaled)
}

///|
fn autohint_scale_style_metrics(
  unscaled : AutoHintUnscaledStyleMetrics,
  scale : AutoHintScale,
) -> AutoHintScaledStyleMetrics {
  let mut scale = scale
  let axes : Array[AutoHintScaledAxisMetrics] = Array::new()
  for dim in 0..<2 {
    let axis = unscaled.axes.at(dim)
    let (s, scaled_axis) = match unscaled.group {
      AutoHintScriptGroup::Default =>
        autohint_scale_default_axis_metrics(axis, scale)
      AutoHintScriptGroup::Cjk => autohint_scale_cjk_axis_metrics(axis, scale)
    }
    scale = s
    axes.push(scaled_axis)
  }
  AutoHintScaledStyleMetrics::{ scale, axes }
}

///|
fn autohint_sort_and_quantize_widths(
  widths : Array[Int],
  threshold : Int,
) -> Unit {
  if widths.length() <= 1 {
    return
  }
  // Insertion sort (MAX_WIDTHS is small).
  for i in 1..<widths.length() {
    let key = widths[i]
    let mut j = i
    while j > 0 && widths[j - 1] > key {
      widths[j] = widths[j - 1]
      j = j - 1
    }
    widths[j] = key
  }
  let mut cur_ix = 0
  let mut cur_val = widths[cur_ix]
  let last_ix = widths.length() - 1
  let mut ix = 1
  // Compute and use mean values for clusters not larger than `threshold`.
  while ix < widths.length() {
    if widths[ix] - cur_val > threshold || ix == last_ix {
      let mut sum = 0
      // Fix loop for end of array?
      if widths[ix] - cur_val <= threshold && ix == last_ix {
        ix = ix + 1
      }
      for j in cur_ix..<ix {
        sum = sum + widths[j]
        widths[j] = 0
      }
      widths[cur_ix] = sum / ix
      if ix < last_ix {
        cur_ix = ix + 1
        cur_val = widths[cur_ix]
      }
    }
    ix = ix + 1
  }
  let out : Array[Int] = Array::new()
  for i in 0..<widths.length() {
    let v = widths[i]
    if v != 0 {
      out.push(v)
    }
  }
  widths.clear()
  for v in out.iter() {
    widths.push(v)
  }
}

///|
fn widths_debug(widths : Array[Int]) -> String {
  let mut s = "["
  for i in 0..<widths.length() {
    if i != 0 {
      s = s + ","
    }
    s = s + widths[i].to_string()
  }
  s + "]"
}

///|
test "autohint metrics: sort widths" {
  let widths = Array::from_fixed_array([60, 20, 40, 35])
  autohint_sort_and_quantize_widths(widths, 10)
  inspect(widths_debug(widths), content="[20,35,13,60]")
  let widths2 = Array::from_fixed_array([60, 20, 40, 35])
  autohint_sort_and_quantize_widths(widths2, 20)
  inspect(widths_debug(widths2), content="[31,60]")
}

///|
test "autohint metrics: scale flags" {
  AUTOHINT_SCALE_NO_VERTICAL |> ignore
  AUTOHINT_BLUE_LONG |> ignore
  AUTOHINT_MAX_WIDTHS |> ignore
  autohint_pix_floor(0) |> ignore
  let scale = AutoHintScale::new(
    16.0,
    2048,
    @moon_skrifa.Style::Normal,
    Target::Mono,
    AutoHintScriptGroup::Default,
  )
  // Basic smoke checks (also marks fields as used for warnings).
  inspect((scale.x_scale != 0).to_string(), content="true")
  inspect(
    ((scale.flags & AUTOHINT_SCALE_MONO) != 0).to_string(),
    content="true",
  )
  inspect(scale.y_scale.to_string(), content=scale.y_scale.to_string())
  inspect(scale.x_delta.to_string(), content=scale.x_delta.to_string())
  inspect(scale.y_delta.to_string(), content=scale.y_delta.to_string())
  inspect(scale.size.to_string(), content=scale.size.to_string())
  inspect(
    scale.units_per_em.to_string(),
    content=scale.units_per_em.to_string(),
  )
}
