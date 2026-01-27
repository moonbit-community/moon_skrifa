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
/// Axes of variation in a variable font.
///
/// Ported from `fontations/skrifa/src/variation.rs` (Apache-2.0 OR MIT).
const TAG_FVAR : UInt = 0x66766172 // "fvar"

///|
const TAG_AVAR : UInt = 0x61766172 // "avar"

///|
const F2DOT14_SCALE : Double = 16384.0

///|
fn variation_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn variation_read_i16_be(view : BytesView, offset : Int) -> Int? {
  match variation_read_u16_be(view, offset) {
    None => None
    Some(u) => if u >= 0x8000 { Some(u - 0x10000) } else { Some(u) }
  }
}

///|
fn variation_read_u32_be(view : BytesView, offset : Int) -> UInt? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_uint()
    let b1 = view.at(offset + 1).to_uint()
    let b2 = view.at(offset + 2).to_uint()
    let b3 = view.at(offset + 3).to_uint()
    Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
}

///|
fn variation_read_i32_be(view : BytesView, offset : Int) -> Int? {
  match variation_read_u32_be(view, offset) {
    None => None
    Some(u) => Some(u.reinterpret_as_int())
  }
}

///|
fn variation_read_fixed_16_16(view : BytesView, offset : Int) -> Double? {
  match variation_read_i32_be(view, offset) {
    None => None
    Some(bits) => Some(bits.to_double() / 65536.0)
  }
}

///|
fn variation_clamp(x : Double, min : Double, max : Double) -> Double {
  if x < min {
    min
  } else if x > max {
    max
  } else {
    x
  }
}

///|
fn variation_normalize_coord(
  coord : Double,
  min_value : Double,
  default_value : Double,
  max_value : Double,
) -> NormalizedCoord {
  let c = variation_clamp(coord, min_value, max_value)
  if c == default_value {
    return 0
  }
  if c < default_value {
    let denom = default_value - min_value
    if denom == 0.0 {
      0
    } else {
      let n = (c - default_value) / denom
      (n * F2DOT14_SCALE).round().to_int()
    }
  } else {
    let denom = max_value - default_value
    if denom == 0.0 {
      0
    } else {
      let n = (c - default_value) / denom
      (n * F2DOT14_SCALE).round().to_int()
    }
  }
}

///|
priv struct AxisRecord {
  tag : Tag
  min_value : Double
  default_value : Double
  max_value : Double
  flags : Int
  name_id : StringId
}

///|
pub struct Axis {
  priv index : Int
  priv record : AxisRecord
}

///|
pub fn Axis::tag(self : Axis) -> Tag {
  self.record.tag
}

///|
pub fn Axis::index(self : Axis) -> Int {
  self.index
}

///|
pub fn Axis::name_id(self : Axis) -> StringId {
  self.record.name_id
}

///|
pub fn Axis::is_hidden(self : Axis) -> Bool {
  // fvar hidden axis flag: 0x0001
  (self.record.flags & 0x1) != 0
}

///|
pub fn Axis::min_value(self : Axis) -> Double {
  self.record.min_value
}

///|
pub fn Axis::default_value(self : Axis) -> Double {
  self.record.default_value
}

///|
pub fn Axis::max_value(self : Axis) -> Double {
  self.record.max_value
}

///|
pub fn Axis::normalize(self : Axis, coord : Double) -> NormalizedCoord {
  variation_normalize_coord(
    coord,
    self.record.min_value,
    self.record.default_value,
    self.record.max_value,
  )
}

///|
priv struct AvarAxisMap {
  from_coords : Array[Int]
  to_coords : Array[Int]
}

///|
priv struct AvarData {
  axes : Array[AvarAxisMap]
}

///|
fn avar_apply(map : AvarAxisMap, coord : Int) -> Int {
  let n = map.from_coords.length()
  if n <= 0 || map.to_coords.length() != n {
    return coord
  }
  let from0 = map.from_coords.at(0)
  let to0 = map.to_coords.at(0)
  if coord <= from0 {
    return to0
  }
  let from_last = map.from_coords.at(n - 1)
  let to_last = map.to_coords.at(n - 1)
  if coord >= from_last {
    return to_last
  }
  for i in 0..<(n - 1) {
    let from_a = map.from_coords.at(i)
    let from_b = map.from_coords.at(i + 1)
    if coord >= from_a && coord <= from_b {
      let to_a = map.to_coords.at(i)
      let to_b = map.to_coords.at(i + 1)
      let denom = from_b - from_a
      if denom == 0 {
        return to_a
      }
      let t = (coord - from_a).to_double() / denom.to_double()
      return (to_a.to_double() + t * (to_b - to_a).to_double()).round().to_int()
    }
  }
  coord
}

///|
fn avar_parse(table : BytesView, axis_count : Int) -> AvarData? {
  // avar header: major u16, minor u16, axisCount u16, reserved u16
  if table.length() < 8 {
    return None
  }
  let major = variation_read_u16_be(table, 0).unwrap_or(-1)
  let minor = variation_read_u16_be(table, 2).unwrap_or(-1)
  if major != 1 || minor != 0 {
    return None
  }
  let count = variation_read_u16_be(table, 4).unwrap_or(-1)
  if count != axis_count || count < 0 {
    return None
  }
  let mut off = 8
  let axes : Array[AvarAxisMap] = Array::new()
  for _ in 0..<axis_count {
    if off + 2 > table.length() {
      return None
    }
    let map_count = variation_read_u16_be(table, off).unwrap_or(-1)
    off = off + 2
    if map_count <= 0 {
      return None
    }
    let from_coords : Array[Int] = Array::new()
    let to_coords : Array[Int] = Array::new()
    for _ in 0..<map_count {
      let from = variation_read_i16_be(table, off).unwrap_or(0)
      let to = variation_read_i16_be(table, off + 2).unwrap_or(0)
      off = off + 4
      from_coords.push(from)
      to_coords.push(to)
    }
    axes.push(AvarAxisMap::{ from_coords, to_coords })
  }
  Some(AvarData::{ axes, })
}

///|
priv struct InstanceRecord {
  subfamily_name_id : StringId
  postscript_name_id : StringId?
  user_coords : Array[Double]
}

///|
pub struct AxisCollection {
  priv axes : Array[AxisRecord]
  priv instances : Array[InstanceRecord]
  priv avar : AvarData?
}

///|
pub fn AxisCollection::new(font : FontRef) -> AxisCollection {
  let fvar = match font.table(TAG_FVAR) {
    None =>
      return AxisCollection::{
        axes: Array::new(),
        instances: Array::new(),
        avar: None,
      }
    Some(v) => v
  }
  if fvar.length() < 16 {
    return AxisCollection::{
      axes: Array::new(),
      instances: Array::new(),
      avar: None,
    }
  }
  let major = variation_read_u16_be(fvar, 0).unwrap_or(-1)
  let minor = variation_read_u16_be(fvar, 2).unwrap_or(-1)
  if major != 1 || minor != 0 {
    return AxisCollection::{
      axes: Array::new(),
      instances: Array::new(),
      avar: None,
    }
  }
  let axes_offset = variation_read_u16_be(fvar, 4).unwrap_or(-1)
  let axis_count = variation_read_u16_be(fvar, 8).unwrap_or(-1)
  let axis_size = variation_read_u16_be(fvar, 10).unwrap_or(-1)
  let instance_count = variation_read_u16_be(fvar, 12).unwrap_or(-1)
  let instance_size = variation_read_u16_be(fvar, 14).unwrap_or(-1)
  if axes_offset < 0 ||
    axis_count < 0 ||
    axis_size < 20 ||
    instance_count < 0 ||
    instance_size < 4 {
    return AxisCollection::{
      axes: Array::new(),
      instances: Array::new(),
      avar: None,
    }
  }
  let axes : Array[AxisRecord] = Array::new()
  let axis_count_i = axis_count
  let axis_size_i = axis_size
  let axes_end = axes_offset + axis_count_i * axis_size_i
  if axes_end < axes_offset || axes_end > fvar.length() {
    return AxisCollection::{
      axes: Array::new(),
      instances: Array::new(),
      avar: None,
    }
  }
  for i in 0..<axis_count_i {
    let base = axes_offset + i * axis_size_i
    let tag_u = variation_read_u32_be(fvar, base).unwrap_or(0)
    let tag = Tag::from_uint(tag_u)
    let min_value = variation_read_fixed_16_16(fvar, base + 4).unwrap_or(0.0)
    let default_value = variation_read_fixed_16_16(fvar, base + 8).unwrap_or(
      0.0,
    )
    let max_value = variation_read_fixed_16_16(fvar, base + 12).unwrap_or(0.0)
    let flags = variation_read_u16_be(fvar, base + 16).unwrap_or(0)
    let name_id = variation_read_u16_be(fvar, base + 18).unwrap_or(0)
    axes.push(AxisRecord::{
      tag,
      min_value,
      default_value,
      max_value,
      flags,
      name_id: name_id.to_uint16(),
    })
  }

  // Instances follow axes.
  let instances_base = axes_end
  let instances_end = instances_base + instance_count * instance_size
  if instances_end < instances_base || instances_end > fvar.length() {
    return AxisCollection::{ axes, instances: Array::new(), avar: None }
  }
  let instances : Array[InstanceRecord] = Array::new()
  for i in 0..<instance_count {
    let base = instances_base + i * instance_size
    let subfamily_name_id = variation_read_u16_be(fvar, base).unwrap_or(0)
    let _flags = variation_read_u16_be(fvar, base + 2).unwrap_or(0)
    let coords_base = base + 4
    let coords_len = axis_count_i * 4
    if coords_base + coords_len > fvar.length() {
      continue
    }
    let user_coords : Array[Double] = Array::new()
    for j in 0..<axis_count_i {
      let c = variation_read_fixed_16_16(fvar, coords_base + j * 4).unwrap_or(
        0.0,
      )
      user_coords.push(c)
    }
    let ps_pos = coords_base + coords_len
    let postscript_name_id : StringId? = if ps_pos + 2 <= base + instance_size {
      let ps = variation_read_u16_be(fvar, ps_pos).unwrap_or(0)
      if ps == 0 {
        None
      } else {
        Some(ps.to_uint16())
      }
    } else {
      None
    }
    instances.push(InstanceRecord::{
      subfamily_name_id: subfamily_name_id.to_uint16(),
      postscript_name_id,
      user_coords,
    })
  }
  let avar = match font.table(TAG_AVAR) {
    None => None
    Some(avar_tbl) => avar_parse(avar_tbl, axis_count_i)
  }
  AxisCollection::{ axes, instances, avar }
}

///|
pub fn AxisCollection::len(self : AxisCollection) -> Int {
  self.axes.length()
}

///|
pub fn AxisCollection::is_empty(self : AxisCollection) -> Bool {
  self.axes.is_empty()
}

///|
pub fn AxisCollection::get(self : AxisCollection, index : Int) -> Axis? {
  match self.axes.get(index) {
    None => None
    Some(r) => Some(Axis::{ index, record: r })
  }
}

///|
pub fn AxisCollection::get_by_tag(self : AxisCollection, tag : Tag) -> Axis? {
  let n = self.axes.length()
  for i in 0..<n {
    let r = self.axes.at(i)
    if r.tag.to_uint() == tag.to_uint() {
      return Some(Axis::{ index: i, record: r })
    }
  }
  None
}

///|
pub fn AxisCollection::location(
  self : AxisCollection,
  settings : ArrayView[VariationSetting],
) -> Location {
  let n = self.axes.length()
  let coords : Array[NormalizedCoord] = Array::make(n, 0)
  for i in 0..<n {
    let axis = Axis::{ index: i, record: self.axes.at(i) }
    let mut selected : Double? = None
    for s in settings.iter() {
      if s.selector.to_uint() == axis.tag().to_uint() {
        selected = Some(s.value)
      }
    }
    let c = match selected {
      None => 0
      Some(v) => axis.normalize(v)
    }
    let remapped = match self.avar {
      None => c
      Some(a) =>
        if i < 0 || i >= a.axes.length() {
          c
        } else {
          avar_apply(a.axes.at(i), c)
        }
    }
    coords.set(i, remapped)
  }
  Location::from_array(coords)
}

///|
pub struct NamedInstance {
  priv axes : AxisCollection
  priv record : InstanceRecord
}

///|
pub fn NamedInstance::subfamily_name_id(self : NamedInstance) -> StringId {
  self.record.subfamily_name_id
}

///|
pub fn NamedInstance::postscript_name_id(self : NamedInstance) -> StringId? {
  self.record.postscript_name_id
}

///|
pub fn NamedInstance::user_coords(self : NamedInstance) -> ArrayView[Double] {
  self.record.user_coords.op_as_view()
}

///|
pub fn NamedInstance::location(self : NamedInstance) -> Location {
  let n = self.axes.len()
  let coords : Array[NormalizedCoord] = Array::make(n, 0)
  for i in 0..<n {
    let axis = self.axes
      .get(i)
      .unwrap_or(Axis::{
        index: i,
        record: AxisRecord::{
          tag: Tag::from_uint(0),
          min_value: 0.0,
          default_value: 0.0,
          max_value: 0.0,
          flags: 0,
          name_id: 0,
        },
      })
    let user = self.record.user_coords.get(i).unwrap_or(0.0)
    let c = axis.normalize(user)
    let remapped = match self.axes.avar {
      None => c
      Some(a) =>
        if i < 0 || i >= a.axes.length() {
          c
        } else {
          avar_apply(a.axes.at(i), c)
        }
    }
    coords.set(i, remapped)
  }
  Location::from_array(coords)
}

///|
pub struct NamedInstanceCollection {
  priv axes : AxisCollection
}

///|
pub fn NamedInstanceCollection::new(font : FontRef) -> NamedInstanceCollection {
  NamedInstanceCollection::{ axes: AxisCollection::new(font) }
}

///|
pub fn NamedInstanceCollection::len(self : NamedInstanceCollection) -> Int {
  self.axes.instances.length()
}

///|
pub fn NamedInstanceCollection::is_empty(
  self : NamedInstanceCollection,
) -> Bool {
  self.len() == 0
}

///|
pub fn NamedInstanceCollection::get(
  self : NamedInstanceCollection,
  index : Int,
) -> NamedInstance? {
  match self.axes.instances.get(index) {
    None => None
    Some(r) => Some(NamedInstance::{ axes: self.axes, record: r })
  }
}

///|
pub fn FontRef::axes(self : FontRef) -> AxisCollection {
  AxisCollection::new(self)
}

///|
pub fn FontRef::named_instances(self : FontRef) -> NamedInstanceCollection {
  NamedInstanceCollection::new(self)
}
