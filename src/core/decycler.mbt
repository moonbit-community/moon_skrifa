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
/// Support for cycle detection in DFS graph traversals.
///
/// Ported from `fontations/skrifa/src/decycler.rs` (Apache-2.0 OR MIT).
///
/// Upstream uses const generics + RAII guards for depth tracking. Here we model
/// `max_depth` at runtime and use explicit `leave()` in a threaded traversal.
priv enum DecyclerError {
  DepthLimitExceeded
  CycleDetected
}

///|
priv struct Decycler[T] {
  node_ids : FixedArray[T]
  depth : Int
  max_depth : Int
}

///|
fn[T : Default] Decycler::new(max_depth : Int) -> Decycler[T] {
  Decycler::{
    node_ids: FixedArray::make(max_depth, T::default()),
    depth: 0,
    max_depth,
  }
}

///|
fn[T : Eq] Decycler::enter(
  self : Decycler[T],
  node_id : T,
) -> Result[Decycler[T], DecyclerError] {
  if self.depth < self.max_depth {
    if self.depth == 0 || self.node_ids.at(self.depth / 2) != node_id {
      self.node_ids.set(self.depth, node_id)
      Ok(Decycler::{
        node_ids: self.node_ids,
        depth: self.depth + 1,
        max_depth: self.max_depth,
      })
    } else {
      Err(CycleDetected)
    }
  } else {
    Err(DepthLimitExceeded)
  }
}

///|
fn[T] Decycler::leave(self : Decycler[T]) -> Decycler[T] {
  // Safe for intended usage (paired with a successful `enter`).
  Decycler::{
    node_ids: self.node_ids,
    depth: self.depth - 1,
    max_depth: self.max_depth,
  }
}

///|
test "graph_with_cycles" {
  let nodes = Array::new()
  nodes.push(Node::new(Array::from_fixed_array([1, 2])))
  nodes.push(Node::new(Array::from_fixed_array([2, 3])))
  nodes.push(Node::new(Array::new()))
  nodes.push(Node::new(Array::from_fixed_array([0, 1])))
  let tree = Tree::{ nodes, }
  let decycler : Decycler[Int] = Decycler::new(MAX_DEPTH)
  let ok = match tree.traverse(decycler) {
    Err(CycleDetected) => true
    _ => false
  }
  inspect(ok, content="true")
}

///|
test "exceeds_max_depth" {
  let nodes = Array::new()
  for ix in 0..<MAX_DEPTH {
    nodes.push(Node::new(Array::from_fixed_array([ix + 1])))
  }
  nodes.push(Node::new(Array::new()))
  let tree = Tree::{ nodes, }
  let decycler : Decycler[Int] = Decycler::new(MAX_DEPTH)
  let ok = match tree.traverse(decycler) {
    Err(DepthLimitExceeded) => true
    _ => false
  }
  inspect(ok, content="true")
}

///|
test "well_formed_tree" {
  let nodes = Array::new()
  for ix in 0..<(MAX_DEPTH - 1) {
    nodes.push(Node::new(Array::from_fixed_array([ix + 1])))
  }
  nodes.push(Node::new(Array::new()))
  let tree = Tree::{ nodes, }
  let decycler : Decycler[Int] = Decycler::new(MAX_DEPTH)
  let ok = match tree.traverse(decycler) {
    Ok(_) => true
    _ => false
  }
  inspect(ok, content="true")
}

///|
const MAX_DEPTH : Int = 64

///|
priv struct Node {
  child_ids : Array[Int]
}

///|
fn Node::new(child_ids : Array[Int]) -> Node {
  Node::{ child_ids, }
}

///|
priv struct Tree {
  nodes : Array[Node]
}

///|
fn Tree::traverse(
  self : Tree,
  decycler : Decycler[Int],
) -> Result[Unit, DecyclerError] {
  match self.traverse_impl(decycler, 0) {
    Ok(_d) => Ok(())
    Err(e) => Err(e)
  }
}

///|
fn Tree::traverse_impl(
  self : Tree,
  decycler : Decycler[Int],
  node_id : Int,
) -> Result[Decycler[Int], DecyclerError] {
  match decycler.enter(node_id) {
    Err(e) => Err(e)
    Ok(d1) => {
      let node = self.nodes.at(node_id)
      let mut d = d1
      for child_id in node.child_ids {
        match self.traverse_impl(d, child_id) {
          Err(e) => return Err(e)
          Ok(d2) => d = d2
        }
      }
      Ok(d.leave())
    }
  }
}
