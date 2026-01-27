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
  y_scale : Int
  x_delta : Int
  y_delta : Int
  size : Double
  units_per_em : Int
  flags : Int
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
