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
/// Composite glyf hinting parity tests against `fontations-reference/skrifa`.
///
/// Fixtures are sourced from `fontations-reference/font-test-data` and embedded
/// as base64 strings to keep tests hermetic.
fn font_glyf_components_b64() -> String {
  "AAEAAAAKAIAAAwAgT1MvMl8hW20AAAEoAAAAYGNtYXAAQwDKAAABoAAAAERnbHlmnzO4LwAAAfgAAADgaGVhZCPvtOwAAACsAAAA" +
  "NmhoZWEGgQSyAAAA5AAAACRobXR4CQ4DdwAAAYgAAAAWbG9jYQEWAVQAAAHkAAAAFG1heHAADwAOAAABCAAAACBuYW1lD/godwAA" +
  "AtgAAAD4cG9zdIH5c5MAAAPQAAAArwABAAAAAQAAGz26Il8PPPUAAwPoAAAAAN/wqA4AAAAA4lHJo/92/zgDIAMgAAAABgACAAAA" +
  "AAAAAAEAAAPo/zgAAAJY/3b/OAMgA+gAAAAAAAAAAAAAAAAAAAACAAEAAAAJAAgAAgAEAAEAAQAAAAAAAAAAAAAAAAACAAEABAJK" +
  "AZAABQAIAooCWAAAAEsCigJYAAABXgAyASwAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAATk9ORQBAACwANQMg/zgAyAPoAMgA" +
  "AAABAAAAAAH0ArwAAAAgAAAB9AAyAlgA+gBD/3YCJgGpASwBLAEsAAAAAAACAAAAAwAAABQAAwABAAAAFAAEADAAAAAIAAgAAgAA" +
  "ACwALgA1//8AAAAsAC4AMP///9b/0//TAAEAAAAAAAAAAAAAABUAIQAuADsARQBUAFwAZgBwAAIAMv84AcIDIAADAAcAABcRIREl" +
  "IREhMgGQ/qIBLP7UyAPo/BgyA4QAAAEA+gAyAXcAZAADAAA3MxUj+n19ZDIA//8AQwD1AU4B2QCHAAH/F/9/aphKT7Wxapj///92" +
  "AGYAGgEDAIcAAf8X/382GCW2tbFqmP//AiYAfQMgAMgARgABMjJ//2AA//8BqQB9AyAA+gBmAAEyMn//YAAARgABMjJgAH////8B" +
  "LABkAakAlgAGAAEyMv//ASwAZAGpAJYIRgAEZGRGZkzN//8BLABkAakAlgBGAARkZEZmTM0AAAAGAE4AAwABBAkAAQAQAAAAAwAB" +
  "BAkAAgAOABAAAwABBAkAAwA0AB4AAwABBAkABAAgAFIAAwABBAkABQAaAHIAAwABBAkABgAeAIwATgBlAHcAIABGAG8AbgB0AFIA" +
  "ZQBnAHUAbABhAHIAMQAuADAAMAAwADsATgBPAE4ARQA7AE4AZQB3AEYAbwBuAHQALQBSAGUAZwB1AGwAYQByAE4AZQB3ACAARgBv" +
  "AG4AdAAgAFIAZQBnAHUAbABhAHIAVgBlAHIAcwBpAG8AbgAgADEALgAwADAAMABOAGUAdwBGAG8AbgB0AC0AUgBlAGcAdQBsAGEA" +
  "cgACAAAAAAAA/5wAMgAAAAAAAAAAAAAAAAAAAAAAAAAAAAkAAAARAA8BAgEDAQQBBQEGAQcRbm9uX3VuaWZvcm1fc2NhbGUQc2lt" +
  "cGxlX3RyYW5zZm9ybRZzaW1wbGVfdHJhbnNmb3JtX2FnYWluDnRyYW5zbGF0ZV9vbmx5F3NjYWxlZF9jb21wb25lbnRfb2Zmc2V0" +
  "GW5vc2NhbGVkX2NvbXBvbmVudF9vZmZzZXQA"
}

///|
test "hint: composite glyf nonuniform scale (glyf_components gid=3 size=16)" {
  let font = golden_font(font_glyf_components_b64())
  let gid = @moon_skrifa.GlyphId::new((3).to_uint16())
  let size = @moon_skrifa.Size::new(16.0)
  let loc = @moon_skrifa.LocationRef::default()
  let opts = Engine::Interpreter.into()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter = HintingInstance::new(outlines0, size, loc, opts).unwrap()
  let outlines = OutlineGlyphCollection::from_font(font)
  let glyph = outlines.get(gid).unwrap()
  let pen = SvgPen::new()
  glyph
  .draw(
    DrawSettings::hinted(hinter, false).with_path_style(PathStyle::FreeType),
    pen,
  )
  .unwrap()
  |> ignore
  inspect(
    pen.to_string(),
    content="M-2.203125,3.015625 L-0.5,4.1875 L0.421875,2.859375 L-1.28125,1.6875 Z",
  )
}

///|
test "hint: composite glyf scaled component offset (glyf_components gid=7 size=16)" {
  let font = golden_font(font_glyf_components_b64())
  let gid = @moon_skrifa.GlyphId::new((7).to_uint16())
  let size = @moon_skrifa.Size::new(16.0)
  let loc = @moon_skrifa.LocationRef::default()
  let opts = Engine::Interpreter.into()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter = HintingInstance::new(outlines0, size, loc, opts).unwrap()
  let outlines = OutlineGlyphCollection::from_font(font)
  let glyph = outlines.get(gid).unwrap()
  let pen = SvgPen::new()
  glyph
  .draw(
    DrawSettings::hinted(hinter, false).with_path_style(PathStyle::FreeType),
    pen,
  )
  .unwrap()
  |> ignore
  inspect(
    pen.to_string(),
    content="M11.4375,6.0625 L15.84375,6.0625 L15.84375,4.640625 L11.4375,4.640625 Z",
  )
}

///|
test "hint: composite glyf unscaled component offset (glyf_components gid=8 size=16)" {
  let font = golden_font(font_glyf_components_b64())
  let gid = @moon_skrifa.GlyphId::new((8).to_uint16())
  let size = @moon_skrifa.Size::new(16.0)
  let loc = @moon_skrifa.LocationRef::default()
  let opts = Engine::Interpreter.into()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter = HintingInstance::new(outlines0, size, loc, opts).unwrap()
  let outlines = OutlineGlyphCollection::from_font(font)
  let glyph = outlines.get(gid).unwrap()
  let pen = SvgPen::new()
  glyph
  .draw(
    DrawSettings::hinted(hinter, false).with_path_style(PathStyle::FreeType),
    pen,
  )
  .unwrap()
  |> ignore
  inspect(
    pen.to_string(),
    content="M11.265625,6.0625 L15.671875,6.0625 L15.671875,4.640625 L11.265625,4.640625 Z",
  )
}
