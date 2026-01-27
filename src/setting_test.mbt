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
test "Setting::new" {
  let tag = Tag::from_str("wght").unwrap()
  let s : Setting[Double] = Setting::new(tag, 400.0)
  inspect(s.selector.to_string(), content="wght")
  inspect(s.value, content="400")
}

///|
test "Setting::from_tuple" {
  let tag = Tag::from_str("wght").unwrap()
  let s : Setting[Double] = Setting::from_tuple((tag, 720.0))
  inspect(s.selector.to_string(), content="wght")
  inspect(s.value, content="720")
}

///|
test "Setting::from_str uses Tag::from_str_or_default" {
  let s : Setting[Double] = Setting::from_str("wght", 650.0)
  inspect(s.selector.to_string(), content="wght")
  inspect(s.value, content="650")
  let bad : Setting[Double] = Setting::from_str("abc", 1.0)
  inspect(bad.selector.to_uint(), content="0")
}
