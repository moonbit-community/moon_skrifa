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
fn tt_make_engine_for_misc(
  retained : TtRetainedGraphicsState,
  axis_count : Int,
  coords : Array[@moon_skrifa.NormalizedCoord],
) -> TtEngine {
  let empty = Bytes::from_array(Array::new().op_as_view())
  TtEngine::new(
    empty[:],
    empty[:],
    empty[:],
    retained,
    Array::new(),
    Array::new(),
    None,
    axis_count,
    coords.op_as_view(),
    64,
    32,
    64,
    64,
  )
}

// GETINFO selector/result bit constants (matching fontations).

///|
const VERSION_SELECTOR_BIT : Int = 1 << 0

///|
const GLYPH_ROTATED_SELECTOR_BIT : Int = 1 << 1

///|
const GLYPH_ROTATED_RESULT_BIT : Int = 1 << 8

///|
const GLYPH_STRETCHED_SELECTOR_BIT : Int = 1 << 2

///|
const GLYPH_STRETCHED_RESULT_BIT : Int = 1 << 9

///|
const FONT_VARIATIONS_SELECTOR_BIT : Int = 1 << 3

///|
const FONT_VARIATIONS_RESULT_BIT : Int = 1 << 10

///|
const SUBPIXEL_HINTING_SELECTOR_BIT : Int = 1 << 6

///|
const SUBPIXEL_HINTING_RESULT_BIT : Int = 1 << 13

///|
const VERTICAL_LCD_SELECTOR_BIT : Int = 1 << 8

///|
const VERTICAL_LCD_RESULT_BIT : Int = 1 << 15

///|
const SUBPIXEL_POSITIONED_SELECTOR_BIT : Int = 1 << 10

///|
const SUBPIXEL_POSITIONED_RESULT_BIT : Int = 1 << 17

///|
const SYMMETRICAL_SMOOTHING_SELECTOR_BIT : Int = 1 << 11

///|
const SYMMETRICAL_SMOOTHING_RESULT_BIT : Int = 1 << 18

///|
const GRAYSCALE_CLEARTYPE_SELECTOR_BIT : Int = 1 << 12

///|
const GRAYSCALE_CLEARTYPE_RESULT_BIT : Int = 1 << 19

///|
test "tt_hint: misc GETINFO" {
  let coords0 : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let retained0 = TtRetainedGraphicsState::new_with_flags(
    0x10000,
    20,
    Target::default(),
    false,
    false,
  )
  let engine = tt_make_engine_for_misc(retained0, 0, coords0)

  // version
  engine.value_stack.push(VERSION_SELECTOR_BIT).unwrap() |> ignore
  engine.op_getinfo().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 40, content="true")

  // not rotated
  engine.value_stack.push(GLYPH_ROTATED_SELECTOR_BIT).unwrap() |> ignore
  engine.op_getinfo().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 0, content="true")
  // rotated (new engine with rotated flag set)
  let retained_rot = TtRetainedGraphicsState::new_with_flags(
    0x10000,
    20,
    Target::default(),
    true,
    false,
  )
  let engine_rot = tt_make_engine_for_misc(retained_rot, 0, coords0)
  engine_rot.value_stack.push(GLYPH_ROTATED_SELECTOR_BIT).unwrap() |> ignore
  engine_rot.op_getinfo().unwrap() |> ignore
  inspect(
    engine_rot.value_stack.pop().unwrap() == GLYPH_ROTATED_RESULT_BIT,
    content="true",
  )

  // not stretched
  engine.value_stack.push(GLYPH_STRETCHED_SELECTOR_BIT).unwrap() |> ignore
  engine.op_getinfo().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 0, content="true")
  // stretched (new engine with stretched flag set)
  let retained_str = TtRetainedGraphicsState::new_with_flags(
    0x10000,
    20,
    Target::default(),
    false,
    true,
  )
  let engine_str = tt_make_engine_for_misc(retained_str, 0, coords0)
  engine_str.value_stack.push(GLYPH_STRETCHED_SELECTOR_BIT).unwrap() |> ignore
  engine_str.op_getinfo().unwrap() |> ignore
  inspect(
    engine_str.value_stack.pop().unwrap() == GLYPH_STRETCHED_RESULT_BIT,
    content="true",
  )

  // stretched and rotated
  let retained_both = TtRetainedGraphicsState::new_with_flags(
    0x10000,
    20,
    Target::default(),
    true,
    true,
  )
  let engine_both = tt_make_engine_for_misc(retained_both, 0, coords0)
  engine_both.value_stack
  .push(GLYPH_ROTATED_SELECTOR_BIT | GLYPH_STRETCHED_SELECTOR_BIT)
  .unwrap()
  |> ignore
  engine_both.op_getinfo().unwrap() |> ignore
  inspect(
    engine_both.value_stack.pop().unwrap() ==
    (GLYPH_ROTATED_RESULT_BIT | GLYPH_STRETCHED_RESULT_BIT),
    content="true",
  )

  // not variable
  engine.value_stack.push(FONT_VARIATIONS_SELECTOR_BIT).unwrap() |> ignore
  engine.op_getinfo().unwrap() |> ignore
  inspect(engine.value_stack.pop().unwrap() == 0, content="true")

  // variable: use a separate engine with axis_count=1.
  let engine_var = tt_make_engine_for_misc(retained0, 1, coords0)
  engine_var.value_stack.push(FONT_VARIATIONS_SELECTOR_BIT).unwrap() |> ignore
  engine_var.op_getinfo().unwrap() |> ignore
  inspect(
    engine_var.value_stack.pop().unwrap() == FONT_VARIATIONS_RESULT_BIT,
    content="true",
  )

  // in strong hinting mode, these selectors are always disabled
  let retained_mono = TtRetainedGraphicsState::new_with_flags(
    0x10000,
    20,
    Target::Mono,
    false,
    false,
  )
  let engine_mono = tt_make_engine_for_misc(retained_mono, 0, coords0)
  for
    selector in [
      SUBPIXEL_HINTING_SELECTOR_BIT,
      VERTICAL_LCD_SELECTOR_BIT,
      SUBPIXEL_POSITIONED_SELECTOR_BIT,
      SYMMETRICAL_SMOOTHING_SELECTOR_BIT,
      GRAYSCALE_CLEARTYPE_SELECTOR_BIT,
    ] {
    engine_mono.value_stack.push(selector).unwrap() |> ignore
    engine_mono.op_getinfo().unwrap() |> ignore
    inspect(engine_mono.value_stack.pop().unwrap() == 0, content="true")
  }

  // smooth mode bits
  let engine_smooth = tt_make_engine_for_misc(retained0, 0, coords0)
  let smooth_bits : Array[(Int, Int)] = Array::from_fixed_array([
    (GRAYSCALE_CLEARTYPE_SELECTOR_BIT, GRAYSCALE_CLEARTYPE_RESULT_BIT),
    (SUBPIXEL_HINTING_SELECTOR_BIT, SUBPIXEL_HINTING_RESULT_BIT),
    (SUBPIXEL_POSITIONED_SELECTOR_BIT, SUBPIXEL_POSITIONED_RESULT_BIT),
  ])
  for entry in smooth_bits.iter() {
    let (selector, result) = entry
    engine_smooth.value_stack.push(selector).unwrap() |> ignore
    engine_smooth.op_getinfo().unwrap() |> ignore
    inspect(engine_smooth.value_stack.pop().unwrap() == result, content="true")
  }

  // vertical lcd: enables VERTICAL_LCD, disables grayscale cleartype + symmetric smoothing.
  let retained_vlcd = TtRetainedGraphicsState::new_with_flags(
    0x10000,
    20,
    Target::Smooth(SmoothMode::VerticalLcd, false, true),
    false,
    false,
  )
  let engine_vlcd = tt_make_engine_for_misc(retained_vlcd, 0, coords0)
  engine_vlcd.value_stack.push(VERTICAL_LCD_SELECTOR_BIT).unwrap() |> ignore
  engine_vlcd.op_getinfo().unwrap() |> ignore
  inspect(
    engine_vlcd.value_stack.pop().unwrap() == VERTICAL_LCD_RESULT_BIT,
    content="true",
  )
  engine_vlcd.value_stack.push(SYMMETRICAL_SMOOTHING_SELECTOR_BIT).unwrap()
  |> ignore
  engine_vlcd.op_getinfo().unwrap() |> ignore
  inspect(engine_vlcd.value_stack.pop().unwrap() == 0, content="true")
  engine_vlcd.value_stack.push(GRAYSCALE_CLEARTYPE_SELECTOR_BIT).unwrap()
  |> ignore
  engine_vlcd.op_getinfo().unwrap() |> ignore
  inspect(engine_vlcd.value_stack.pop().unwrap() == 0, content="true")

  // reset to default: symmetric smoothing enabled.
  engine_smooth.value_stack.push(SYMMETRICAL_SMOOTHING_SELECTOR_BIT).unwrap()
  |> ignore
  engine_smooth.op_getinfo().unwrap() |> ignore
  inspect(
    engine_smooth.value_stack.pop().unwrap() == SYMMETRICAL_SMOOTHING_RESULT_BIT,
    content="true",
  )
}

///|
test "tt_hint: misc GETVARIATION pads/truncates and GETDATA returns 17" {
  let empty_coords : Array[@moon_skrifa.NormalizedCoord] = Array::new()
  let retained0 = TtRetainedGraphicsState::new_with_flags(
    0x10000,
    20,
    Target::default(),
    false,
    false,
  )
  let engine0 = tt_make_engine_for_misc(retained0, 0, empty_coords)
  match engine0.op_getvariation(0) {
    Err(HintError::UnhandledOpcode(0x91, 0)) => ()
    Ok(_) => fail("expected UnhandledOpcode(GETVARIATION)")
    Err(_) => fail("expected UnhandledOpcode(GETVARIATION)")
  }
  match engine0.op_getdata(0) {
    Err(HintError::UnhandledOpcode(0x92, 0)) => ()
    Ok(_) => fail("expected UnhandledOpcode(GETDATA)")
    Err(_) => fail("expected UnhandledOpcode(GETDATA)")
  }
  let coords : Array[@moon_skrifa.NormalizedCoord] = Array::from_fixed_array([
    -16384, 8192, 16384,
  ])

  // too few, pad with zeros
  let coords_1 : Array[@moon_skrifa.NormalizedCoord] = Array::from_fixed_array([
    coords.at(0),
  ])
  let engine1 = tt_make_engine_for_misc(retained0, 2, coords_1)
  engine1.op_getvariation(0).unwrap() |> ignore
  inspect(engine1.value_stack.pop().unwrap() == 0, content="true")
  inspect(engine1.value_stack.pop().unwrap() == coords.at(0), content="true")

  // too many, truncate
  let engine2 = tt_make_engine_for_misc(retained0, 2, coords)
  engine2.op_getvariation(0).unwrap() |> ignore
  inspect(engine2.value_stack.pop().unwrap() == coords.at(1), content="true")
  inspect(engine2.value_stack.pop().unwrap() == coords.at(0), content="true")

  // getdata: variable font returns 17
  let engine3 = tt_make_engine_for_misc(retained0, 1, coords)
  engine3.op_getdata(0).unwrap() |> ignore
  inspect(engine3.value_stack.pop().unwrap() == 17, content="true")
}
