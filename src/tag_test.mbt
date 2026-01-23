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
test "Tag parse + roundtrip" {
  let tag = Tag::from_str("fvar").unwrap()
  inspect(tag.to_uint().to_string(), content="1719034226")
  inspect(tag.to_string(), content="fvar")
}

///|
test "Tag invalid string length" {
  inspect(Tag::from_str("abc") is None, content="true")
}
