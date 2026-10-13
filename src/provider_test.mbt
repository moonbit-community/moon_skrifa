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
fn provider_test_push_u16_be(out : Array[Byte], v : Int32) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int32::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn provider_test_push_u32_be(out : Array[Byte], v : UInt32) -> Unit {
  let mask = 255 |> Int32::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn provider_test_u32(x : Int32) -> UInt32 {
  x.reinterpret_as_uint()
}

///|
const PROVIDER_TEST_TAG_TEST : UInt32 = 0x74657374 // "test"

///|
fn provider_test_make_min_sfnt() -> Bytes {
  let out = []
  provider_test_push_u32_be(out, provider_test_u32(0x00010000))
  provider_test_push_u16_be(out, 1)
  provider_test_push_u16_be(out, 0)
  provider_test_push_u16_be(out, 0)
  provider_test_push_u16_be(out, 0)
  provider_test_push_u32_be(out, PROVIDER_TEST_TAG_TEST)
  provider_test_push_u32_be(out, provider_test_u32(0))
  provider_test_push_u32_be(out, provider_test_u32(28))
  provider_test_push_u32_be(out, provider_test_u32(4))
  out.push(0x61 |> Int32::to_byte)
  out.push(0x62 |> Int32::to_byte)
  out.push(0x63 |> Int32::to_byte)
  out.push(0x64 |> Int32::to_byte)
  Bytes::from_array(out[:])
}

///|
test "MetadataProvider facade basic" {
  let font = @moon_skrifa.FontRef::from_bytes(provider_test_make_min_sfnt()).unwrap()
  let attrs = @moon_skrifa.MetadataProvider::attributes(font)
  inspect(attrs.weight().value(), content="400")
  inspect(attrs.stretch().ratio(), content="1")
  let metrics = @moon_skrifa.MetadataProvider::metrics(
    font,
    @moon_skrifa.Size::unscaled(),
    @moon_skrifa.LocationRef::default(),
  )
  inspect(metrics.units_per_em().to_int(), content="0")
  let gm = @moon_skrifa.MetadataProvider::glyph_metrics(
    font,
    @moon_skrifa.Size::unscaled(),
    @moon_skrifa.LocationRef::default(),
  )
  inspect(gm.glyph_count(), content="0")
  let cmap = @moon_skrifa.MetadataProvider::charmap(font)
  inspect(!cmap.has_map(), content="true")
  inspect(!cmap.has_variant_map(), content="true")
  inspect(@moon_skrifa.MetadataProvider::axes(font).len(), content="0")
  inspect(
    @moon_skrifa.MetadataProvider::named_instances(font).len(),
    content="0",
  )
  inspect(
    @moon_skrifa.MetadataProvider::glyph_names(font).num_glyphs(),
    content="0",
  )
  inspect(
    @moon_skrifa.MetadataProvider::bitmap_strikes(font).len(),
    content="0",
  )
  inspect(
    @moon_skrifa.MetadataProvider::color_palettes(font).len(),
    content="0",
  )
  inspect(
    @moon_skrifa.MetadataProvider::color_glyphs(font).layers(
      @moon_skrifa.GlyphId::default(),
    )
    is None,
    content="true",
  )
}
