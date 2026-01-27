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
test "OutlineGlyphCollection basic" {
  fn push_u16_be(out : Array[Byte], v : Int) -> Unit {
    let u = v.reinterpret_as_uint()
    let mask = 255 |> Int::reinterpret_as_uint
    out.push(((u >> 8) & mask).to_byte())
    out.push((u & mask).to_byte())
  }

  fn push_u32_be(out : Array[Byte], v : UInt) -> Unit {
    let mask = 255 |> Int::reinterpret_as_uint
    out.push(((v >> 24) & mask).to_byte())
    out.push(((v >> 16) & mask).to_byte())
    out.push(((v >> 8) & mask).to_byte())
    out.push((v & mask).to_byte())
  }

  fn u32(x : Int) -> UInt {
    x.reinterpret_as_uint()
  }
  // Minimal SFNT with no tables (valid enough for FontRef table lookups).
  let out : Array[Byte] = Array::new()
  push_u32_be(out, u32(0x00010000))
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  let font = @moon_skrifa.FontRef::new(Bytes::from_array(out.op_as_view())).unwrap()
  let c = OutlineGlyphCollection::new(font)
  inspect(c.format() is None, content="true")
}
