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
fn tt_def_code() -> Bytes {
  // Non-empty code so we can use a non-zero end bound when needed.
  Bytes::from_array(Array::from_fixed_array([(0).to_byte()]).op_as_view())
}

///|
test "tt_hint: definition set too many + invalid range" {
  let code0 = tt_def_code()
  let code = code0[:]
  inspect(code.length() == 1, content="true")
  let defs = TtDefinitionSet::new(32)
  for i in 0..<32 {
    inspect(defs.set_definition(i, code, 0, 0) is Ok(_), content="true")
  }
  inspect(
    defs.set_definition(33, code, 0, 0) is Err(HintError::TooManyDefinitions),
    content="true",
  )
  // Invalid byte range => InvalidDefinition
  inspect(
    defs.set_definition(0, code, 0, 2) is Err(HintError::InvalidDefinition(0)),
    content="true",
  )
  // Missing definition returns None.
  inspect(defs.get(33) is None, content="true")
}

///|
test "tt_hint: definition set allocate dense" {
  let code0 = tt_def_code()
  let code = code0[:]
  let defs = TtDefinitionSet::new(32)
  for i in 0..<32 {
    inspect(defs.set_definition(i, code, 0, 0) is Ok(_), content="true")
  }
  for i in 0..<32 {
    inspect(defs.get(i) is Some(_), content="true")
    let d = defs.defs.at(i)
    inspect(d.key == i, content="true")
    inspect(d.is_defined(), content="true")
  }
}

///|
test "tt_hint: definition set allocate sparse" {
  let code0 = tt_def_code()
  let code = code0[:]
  let defs = TtDefinitionSet::new(3)
  let keys = [42, 88, 107]
  for k in keys {
    inspect(defs.set_definition(k, code, 0, 0) is Ok(_), content="true")
  }
  for k in keys {
    inspect(defs.get(k) is Some(_), content="true")
    if defs.get(k) is Some(d) {
      inspect(d.key == k, content="true")
    }
  }
  // Backing store allocation is from the end (matches fontations behavior).
  inspect(defs.defs.at(0).key == 107, content="true")
  inspect(defs.defs.at(1).key == 88, content="true")
  inspect(defs.defs.at(2).key == 42, content="true")
}

///|
test "tt_hint: definition set allocate mixed" {
  let code0 = tt_def_code()
  let code = code0[:]
  let defs = TtDefinitionSet::new(10)
  let keys = [0, 1, 2, 3, 123456, -42, -5555, 5, 7]
  for k in keys {
    inspect(defs.set_definition(k, code, 0, 0) is Ok(_), content="true")
  }

  // Mirror fontations expected allocation pattern.
  inspect(defs.defs.at(0).key == 0, content="true")
  inspect(defs.defs.at(1).key == 1, content="true")
  inspect(defs.defs.at(2).key == 2, content="true")
  inspect(defs.defs.at(3).key == 3, content="true")
  inspect(defs.defs.at(4).key == 0, content="true")
  inspect(defs.defs.at(5).key == 5, content="true")
  inspect(defs.defs.at(6).key == 7, content="true")
  inspect(defs.defs.at(7).key == -5555, content="true")
  inspect(defs.defs.at(8).key == -42, content="true")
  inspect(defs.defs.at(9).key == 123456, content="true")
  for k in keys {
    inspect(defs.get(k) is Some(_), content="true")
    if defs.get(k) is Some(d) {
      inspect(d.key == k, content="true")
    }
  }
}
