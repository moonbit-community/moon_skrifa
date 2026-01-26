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
  OutlinePen::move_to(pen, 0.0, 0.0)
  OutlinePen::line_to(pen, 10.0, 0.0)
  OutlinePen::close(pen)
  inspect(pen.to_string(), content="M0,0 L10,0 Z")
}

///|
test "SvgPen precision" {
  let pen0 = SvgPen::new()
  OutlinePen::move_to(pen0, 1.0, 2.45556)
  OutlinePen::line_to(pen0, 1.2, 4.0)
  OutlinePen::quad_to(pen0, 2.0345, 3.56789, -0.157, -425.07)
  OutlinePen::curve_to(pen0, -37.0010, 4.5, 2.0, 1.0, -0.5, -0.25)
  OutlinePen::close(pen0)
  inspect(
    pen0.to_string(),
    content="M1,2.45556 L1.2,4 Q2.0345,3.56789 -0.157,-425.07 C-37.001,4.5 2,1 -0.5,-0.25 Z",
  )
  let pen1 = SvgPen::with_precision(1)
  OutlinePen::move_to(pen1, 1.0, 2.45556)
  OutlinePen::line_to(pen1, 1.2, 4.0)
  OutlinePen::quad_to(pen1, 2.0345, 3.56789, -0.157, -425.07)
  OutlinePen::curve_to(pen1, -37.0010, 4.5, 2.0, 1.0, -0.5, -0.25)
  OutlinePen::close(pen1)
  inspect(
    pen1.to_string(),
    content="M1.0,2.5 L1.2,4.0 Q2.0,3.6 -0.2,-425.1 C-37.0,4.5 2.0,1.0 -0.5,-0.2 Z",
  )
  let pen4 = SvgPen::with_precision(4)
  OutlinePen::move_to(pen4, 1.0, 2.45556)
  OutlinePen::line_to(pen4, 1.2, 4.0)
  OutlinePen::quad_to(pen4, 2.0345, 3.56789, -0.157, -425.07)
  OutlinePen::curve_to(pen4, -37.0010, 4.5, 2.0, 1.0, -0.5, -0.25)
  OutlinePen::close(pen4)
  inspect(
    pen4.to_string(),
    content="M1.0000,2.4556 L1.2000,4.0000 Q2.0345,3.5679 -0.1570,-425.0700 C-37.0010,4.5000 2.0000,1.0000 -0.5000,-0.2500 Z",
  )
}
