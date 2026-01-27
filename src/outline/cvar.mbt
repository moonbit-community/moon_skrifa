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
/// cvar support (CVT variations) for embedded hinting.
///
/// Ported from `read-fonts` cvar parsing + `skrifa` hint instance setup
/// (Apache-2.0 OR MIT).
const TAG_CVAR : UInt = 0x63766172 // "cvar"

///|
fn cvar_fixed16_16_to_f26_6(bits : Int) -> Int {
  // Matches `font_types::Fixed::to_f26dot6()` rounding.
  ((bits.to_int64() + (0x200).to_int64()) >> 10).to_int()
}

///|
fn cvar_read_u16_be(view : BytesView, offset : Int) -> Int? {
  gvar_read_u16_be(view, offset)
}

///|
fn cvar_read_i16_be(view : BytesView, offset : Int) -> Int? {
  gvar_read_i16_be(view, offset)
}

///|
/// Computes accumulated cvar deltas (in 16.16 fixed bits) for the current
/// normalized coordinates.
///
/// Returns None if cvar is missing, invalid, or if variation is inactive.
fn cvar_deltas_fixed16_16(
  font : @moon_skrifa.FontRef,
  axis_count : Int,
  coords : ArrayView[@moon_skrifa.NormalizedCoord],
  cvt_len : Int,
) -> Array[Int]? {
  if axis_count <= 0 || cvt_len <= 0 || coords.is_empty() {
    return None
  }
  let cvar = match font.table(TAG_CVAR) {
    None => return None
    Some(v) => v
  }
  if cvar.length() < 8 {
    return None
  }
  let major = cvar_read_u16_be(cvar, 0).unwrap_or(-1)
  let minor = cvar_read_u16_be(cvar, 2).unwrap_or(-1)
  if major != 1 || minor != 0 {
    return None
  }
  let tuple_count_flags = cvar_read_u16_be(cvar, 4).unwrap_or(0)
  let tuple_count = tuple_count_flags & 0x0FFF
  let shared_points = (tuple_count_flags & 0x8000) != 0
  let data_off = cvar_read_u16_be(cvar, 6).unwrap_or(-1)
  if tuple_count <= 0 || data_off < 8 || data_off > cvar.length() {
    return None
  }
  let sizes : Array[Int] = Array::new()
  let tuple_indexes : Array[Int] = Array::new()
  let scalars : Array[Double] = Array::new()
  let mut header_off = 8
  for _ in 0..<tuple_count {
    let s = cvar_read_u16_be(cvar, header_off).unwrap_or(-1)
    let ti = cvar_read_u16_be(cvar, header_off + 2).unwrap_or(-1)
    if s < 0 || ti < 0 {
      return None
    }
    header_off = header_off + 4
    sizes.push(s)
    tuple_indexes.push(ti)
    let embedded = (ti & 0x8000) != 0
    let intermediate = (ti & 0x4000) != 0
    if !embedded {
      // cvar has no shared tuples; treat this as malformed.
      return None
    }
    let peak : Array[Int] = Array::make(axis_count, 0)
    let need_peak = header_off + axis_count * 2
    if need_peak < header_off || need_peak > cvar.length() {
      return None
    }
    for ax in 0..<axis_count {
      peak.set(ax, cvar_read_i16_be(cvar, header_off + ax * 2).unwrap_or(0))
    }
    header_off = need_peak
    let mut start_t : Array[Int]? = None
    let mut end_t : Array[Int]? = None
    if intermediate {
      let st : Array[Int] = Array::make(axis_count, 0)
      let et : Array[Int] = Array::make(axis_count, 0)
      let need = header_off + axis_count * 4
      if need < header_off || need > cvar.length() {
        return None
      }
      for ax in 0..<axis_count {
        st.set(ax, cvar_read_i16_be(cvar, header_off + ax * 2).unwrap_or(0))
        et.set(
          ax,
          cvar_read_i16_be(cvar, header_off + axis_count * 2 + ax * 2).unwrap_or(
            0,
          ),
        )
      }
      header_off = need
      start_t = Some(st)
      end_t = Some(et)
    }
    scalars.push(gvar_tuple_scalar(coords, peak, start_t, end_t))
  }
  if header_off > data_off {
    return None
  }
  let out : Array[Double] = Array::make(cvt_len, 0.0)
  let mut cursor = data_off
  let mut shared_points_list : Array[Int]? = None
  if shared_points {
    let (pts, off2) = match gvar_points(cvar, cursor, cvt_len) {
      None => return None
      Some(v) => v
    }
    shared_points_list = pts
    cursor = off2
  }
  for i in 0..<tuple_count {
    let size = sizes.at(i)
    let ti = tuple_indexes.at(i)
    let tuple_end = cursor + size
    if size < 0 || tuple_end < cursor || tuple_end > cvar.length() {
      return None
    }
    let scalar = scalars.at(i)
    if scalar == 0.0 {
      cursor = tuple_end
      continue
    }
    // PRIVATE_POINT_NUMBERS = 0x2000.
    let private_points = (ti & 0x2000) != 0
    let mut points_list : Array[Int]? = None
    let mut after_points = cursor
    if private_points || !shared_points {
      let (pts, off2) = match gvar_points(cvar, cursor, cvt_len) {
        None => return None
        Some(v) => v
      }
      points_list = pts
      after_points = off2
    } else {
      points_list = shared_points_list
      after_points = cursor
    }
    let count = match points_list {
      None => cvt_len
      Some(arr) => arr.length()
    }
    let (dxs, after_x) = match gvar_deltas(cvar, after_points, count) {
      None => return None
      Some(v) => v
    }
    if after_x > tuple_end {
      return None
    }
    match points_list {
      None =>
        for ix in 0..<cvt_len {
          out.set(ix, out.at(ix) + dxs.at(ix).to_double() * scalar)
        }
      Some(list) =>
        for j in 0..<list.length() {
          let ix = list.at(j)
          if ix >= 0 && ix < cvt_len {
            out.set(ix, out.at(ix) + dxs.at(j).to_double() * scalar)
          }
        }
    }
    cursor = tuple_end
  }
  let out_bits : Array[Int] = Array::make(cvt_len, 0)
  for i in 0..<cvt_len {
    out_bits.set(i, (out.at(i) * 65536.0).round().to_int())
  }
  Some(out_bits)
}

///|
fn cvar_test_font_cvar_b64() -> String {
  "AAEAAAAMAIAAAwBAT1MvMm4kh4gAAAFIAAAAYGN2YXI8NRkyAAADEAAAARtjdnQgCgsBHwAAAawAAADw" +
  "ZnZhcnhQU38AAAQsAAABDGdseWYdRDvlAAACoAAAACpndmFyAAUAMAAABTgAAAAYaGVhZAyV7XwAAADM" +
  "AAAANmhoZWEGqQF/AAABBAAAACRobXR4AfQAMgAAAagAAAAEbG9jYQAAABUAAAKcAAAABG1heHACPA/Z" +
  "AAABKAAAACBwb3N03jWOyQAAAswAAABEAAEAAABb5ytjRkQ5Xw889QALA+gAAAAA1F3isQAAAADWQuC1" +
  "ABL/EAJpAvgAAAAGAAIAAAAAAAAAAQAABCz+3AAAAoUAEgAcAmkAAQAAAAAAAAAAAAAAAAAAAAEAAQAA" +
  "AAEAMwACAAAAAAACABAALwCaAAABjg91AAAAAAAEAgsBkAAFAAACigJYAAAASwKKAlgAAAFeADIBQgAA" +
  "AgIFAgYFBQICBOAAAv9AAAAfCAAAKQAQAABHT09HAUAAIABvBCz+3AAABCwBJAAAAAAAAAAAAhgCygAA" +
  "ACAAAAH0ADIC+AAKAsoAAALKAAoCGAAKAAAAAAAA//YAAP/2/wb/9gAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAEAAXgBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1" +
  "AAAAQAAAAAAAAAAAAAAAKgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAVAAIAM/8GAc0DtgADAAcAABcRIRElIREhMwGa/pkBNP7M+gSw+1AzBEoAAAAAAgAA" +
  "AAAAAP+cADIAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAHdW5pMDAyMAd1bmkwMDY4B3VuaTAwNkUHdW5p" +
  "MDA2RgABAAAACwB2AA+gAAAAwAAAAAAPoADAAMAAAAAAD6AAQADAAAAAAA+gAMAAAAAAAAAPoABAAAAA" +
  "AAAAD6AAAAAAAEAAAA+gAAAAwABAAAAPoABAAMAAQAAAD6AAwAAAAEAAAA+gAEAAAABAAAAPoADAAMAA" +
  "QAAGBUEBARICBgUI+Aj1AP8GBUEBARICBgX+CPkLAAEGBUEBARICBgU46CoG9vwGBUEBARICBgXUvtnk" +
  "2eoGBUEBARICBgUWZCQTJBMGBUEBARICBgUIAAjVz+AGBUEBARICBgX4APgLCQEGBUEBARICBgWwAKb6" +
  "0QQGBUEBARICBgXwAOscJxYGBUEBARICBgXSAOrtI+0GBUEBARICBgUCAAf19/8AAAEAAAAQAAIAAwAU" +
  "AAwAEHdnaHQAHAAAAF4AAADCAAAAAAEAd2R0aABGAAAAZAAAAGQAAAAAAQFvcHN6AAwAAAAMAAAASAAA" +
  "AAABAgEHAAAAXgAAAGQAAAAMAAABAwAAABwAAABGAAAADAAAAQQAAABeAAAARgAAAAwAAAEFAAAAwgAA" +
  "AEYAAAAMAAABBgAAABwAAABkAAAADAAAAQgAAADCAAAAZAAAAAwAAAEJAAAAHAAAAEYAAABIAAABCgAA" +
  "AF4AAABGAAAASAAAAQsAAADCAAAARgAAAEgAAAEMAAAAHAAAAGQAAABIAAABDQAAAF4AAABkAAAASAAA" +
  "AQ4AAADCAAAAZAAAAEgAAAABAAAAAwAAAAAAGAABAAAAAAAYAAAAAA=="
}

///|
fn cvar_test_b64_val(c : Int) -> Int? {
  if c >= 65 && c <= 90 {
    Some(c - 65)
  } else if c >= 97 && c <= 122 {
    Some(c - 97 + 26)
  } else if c >= 48 && c <= 57 {
    Some(c - 48 + 52)
  } else if c == 43 {
    Some(62)
  } else if c == 47 {
    Some(63)
  } else {
    None
  }
}

///|
fn cvar_test_b64_decode(s : String) -> Bytes {
  let out : Array[Byte] = Array::new()
  let vals : Array[Int] = Array::new()
  let n = s.length()
  for i in 0..<n {
    let c = s.code_unit_at(i).to_int()
    if c == 61 {
      // "=" padding
      vals.push(-1)
    } else {
      match cvar_test_b64_val(c) {
        None => ()
        Some(v) => vals.push(v)
      }
    }
    if vals.length() == 4 {
      let v0 = vals.at(0)
      let v1 = vals.at(1)
      let v2 = vals.at(2)
      let v3 = vals.at(3)
      out.push((((v0 << 2) | (v1 >> 4)) & 0xFF).to_byte())
      if v2 != -1 {
        out.push(((((v1 & 0x0F) << 4) | (v2 >> 2)) & 0xFF).to_byte())
        if v3 != -1 {
          out.push(((((v2 & 0x03) << 6) | v3) & 0xFF).to_byte())
        }
      }
      vals.clear()
    }
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn cvar_test_font() -> @moon_skrifa.FontRef {
  @moon_skrifa.FontRef::new(cvar_test_b64_decode(cvar_test_font_cvar_b64())).unwrap()
}

///|
test "cvar: scaled deltas (coords=0.5,-0.5)" {
  let font = cvar_test_font()
  let axis_count = match font.table(0x66766172) {
    None => 0
    Some(fvar) => cvar_read_u16_be(fvar, 8).unwrap_or(0)
  }
  let cvt_len = match font.table(0x63767420) {
    None => 0
    Some(cvt) => cvt.length() / 2
  }
  let coords : Array[@moon_skrifa.NormalizedCoord] = Array::from_fixed_array([
    8192, -8192,
  ])
  let deltas = cvar_deltas_fixed16_16(
    font,
    axis_count,
    coords.op_as_view(),
    cvt_len,
  ).unwrap()
  inspect(deltas.at(65).to_string(), content="1900544")
  inspect(deltas.at(66).to_string(), content="2621440")
  inspect(deltas.at(67).to_string(), content="2129920")
  inspect(deltas.at(85).to_string(), content="360448")
  inspect(deltas.at(87).to_string(), content="1015808")
  inspect(deltas.at(93).to_string(), content="524288")
}
