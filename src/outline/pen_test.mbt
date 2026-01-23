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
test "SvgPen basic" {
  let pen = SvgPen::new()
  OutlinePen::move_to(pen, 0, 0)
  OutlinePen::line_to(pen, 10, 0)
  OutlinePen::close(pen)
  inspect(pen.to_string(), content="M0,0 L10,0 Z")
}
