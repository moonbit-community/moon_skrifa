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
/// Table provider abstraction.
///
/// Upstream skrifa is built on top of `read-fonts` which exposes a `TableProvider`
/// trait returning raw table bytes by tag. In MoonBit we keep `FontRef::table`
/// as the low-level primitive (`UInt` tag), and provide this trait adapter for
/// Tag-based APIs.
pub(open) trait TableProvider {
  table(Self, Tag) -> BytesView?
}

///|
pub impl TableProvider for FontRef with table(font, tag) {
  font.table(tag.to_uint())
}
