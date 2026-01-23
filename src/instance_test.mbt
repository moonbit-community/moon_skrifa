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
test "Size::ppem and linear_scale" {
  let s = Size::new(20.0)
  inspect(s.ppem(), content="Some(20)")
  inspect(s.linear_scale(1000), content="0.02")
  inspect(s.linear_scale(0), content="1")
}

///|
test "Size::unscaled linear_scale" {
  let s = Size::unscaled()
  inspect(s.ppem(), content="None")
  inspect(s.linear_scale(1000), content="1")
  inspect(s.value(), content="0")
}
