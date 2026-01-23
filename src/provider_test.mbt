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
fn provider_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn provider_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn provider_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
const PROVIDER_TEST_TAG_TEST : UInt = 0x74657374 // "test"

///|
fn provider_test_make_min_sfnt() -> Bytes {
  let out = Array::new()
  provider_test_push_u32_be(out, provider_test_u32(0x00010000))
  provider_test_push_u16_be(out, 1)
  provider_test_push_u16_be(out, 0)
  provider_test_push_u16_be(out, 0)
  provider_test_push_u16_be(out, 0)
  provider_test_push_u32_be(out, PROVIDER_TEST_TAG_TEST)
  provider_test_push_u32_be(out, provider_test_u32(0))
  provider_test_push_u32_be(out, provider_test_u32(28))
  provider_test_push_u32_be(out, provider_test_u32(4))
  out.push(0x61 |> Int::to_byte)
  out.push(0x62 |> Int::to_byte)
  out.push(0x63 |> Int::to_byte)
  out.push(0x64 |> Int::to_byte)
  Bytes::from_array(out.op_as_view())
}

///|
test "MetadataProvider facade basic" {
  let font = FontRef::new(provider_test_make_min_sfnt()).unwrap()
  let attrs = MetadataProvider::attributes(font)
  inspect(attrs.weight().value(), content="400")
  inspect(attrs.stretch().ratio(), content="1")
  inspect(MetadataProvider::metrics(font) is None, content="true")
  inspect(MetadataProvider::charmap(font) is None, content="true")
  inspect(MetadataProvider::axes(font).len(), content="0")
  inspect(MetadataProvider::named_instances(font).len(), content="0")
  inspect(MetadataProvider::glyph_names(font).num_glyphs(), content="0")
  inspect(MetadataProvider::bitmap_strikes(font).len(), content="0")
  inspect(MetadataProvider::color_palettes(font) is None, content="true")
  inspect(MetadataProvider::color_glyphs(font) is None, content="true")
}
