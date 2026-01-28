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
fn hvar_b64_val(c : Int) -> Int? {
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
fn hvar_b64_decode(s : String) -> Bytes {
  let out : Array[Byte] = Array::new()
  let vals : Array[Int] = Array::new()
  let n = s.length()
  for i in 0..<n {
    let c = s.code_unit_at(i).to_int()
    if c == 61 {
      vals.push(-1)
    } else {
      match hvar_b64_val(c) {
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
fn hvar_font() -> @moon_skrifa.FontRef {
  @moon_skrifa.FontRef::new(hvar_b64_decode(hvar_truncated_adv_index_map_b64())).unwrap()
}

///|
fn hvar_truncated_adv_index_map_b64() -> String {
  "AAEAAAAQAIAAAwBwR0RFRgAdAA4AAAc4AAAAFkhWQVKtmEO2AAAHUAAAAElPUy8yX1tdgQAAAXgAAABg" +
  "U1RBVHhwaIwAAAecAAAAHGNtYXAKEQaaAAACKAAAAIhmdmFyhp5pkgAAB7gAAAA8Z2x5ZolB98gAAALk" +
  "AAABfmd2YXJrjwj1AAAH9AAAAd5oZWFkI6ywUwAAAPwAAAA2aGhlYQXpAHsAAAE0AAAAJGhtdHgSrwFD" +
  "AAAB2AAAAE5sb2NhBs0GggAAArAAAAAybWF4cAAgABwAAAFYAAAAIG5hbWVXhKJ5AAAEZAAAAhNwb3N0" +
  "5C3L5wAABngAAAC9AAEAAAABAADg7JZ0Xw889QADA+gAAAAA4TsYowAAAADhXFP8/8L/OAI8A5kAAAAG" +
  "AAIAAAAAAAAAAQAAA+j/OAAAAkT/wv7vAjwAAQAAAAAAAAAAAAAAAAAAAA8AAQAAABgACwACAA8AAwAB" +
  "AAAAAAAAAAAAAAAAAAIAAQAEAY8BkAAFAAgCigJYAAAASwKKAlgAAAFeADIBLAAAAAAAAAAAAAAAAAAA" +
  "AEcAAAAAAAAAAAAAAABOT05FAEAAIAMEAyD/OADIA+gAyAAAAAEAAAAAAfQCvAAAACAAAAH0ADIBkAAA" +
  "AkQACgC+ADMBkAAHAkQACgJEAAoAvgAzAL7/9gJEAAoAvv/mAAAAkgAAAEwAAP/CAZAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAgAAAAMAAAAUAAMAAQAAABQABAB0AAAAFgAQAAMABgAgAEEASQBUAMEAzQEA" +
  "ASoDAQME//8AAAAgAEEASQBUAMAAzAEAASoDAAME////4f/B/7r/sAAAAAD/Cf7gAAD9CQABAAAAAAAA" +
  "AAAADgAQAAAAAAAOAAAAAAAGAAUACAAHAAwACwAAABUAFQAwAD0AUABcAGgAdACAAIwAlwClALMAvwC/" +
  "AL8AvwC/AL8AvwC/AL8AvwC/AAAAAgAy/zgBwgMgAAMABwAAFxEhESUhESEyAZD+ogEs/tTIA+j8GDID" +
  "hAAAAgAK/+wCPALOAAYACgAANwExAQcDAzc3BRcKARcBG0jR0CgUASQHCwLD/T0fAj7918ZYCkYAAQAz" +
  "AAAAiwLLAAMAABMzESMzWFgCy/01AAACAAcAAAGHArwAAwAHAAATIRUhNzMRIwcBgP6AklZWArxHE/14" +
  "//8ACv/sAjwDlwImAAIAAAAHAAsAgQCd//8ACv/sAjwDmQImAAIAAAAHAAwAaQCf//8AMwAAAMsDkAIm" +
  "AAMAAAAHAAv/ugCW////9gAAAIsDkQImAAMAAAAHAAz/qgCX//8ACv/sAjwDIwImAAIAAAAHAA0A2QBn" +
  "////5gAAAOEDJgImAAMAAAAGAA0kagABAJICUgERAvoAAwAAEzcXB5I2SVcCUqgCpQAAAQBMAlIAywL6" +
  "AAMAABMnJzfLKFdJAlIBpQIAAAH/wgKEAL0CvAADAAADMxUjPvv7Arw4AAAAAAAOAK4AAQAAAAABAAAG" +
  "AAAAAQAAAAABAQAHAAYAAQAAAAABAgAGAA0AAQAAAAABAwAEABMAAwABBAkAAQAyABcAAwABBAkAAgAO" +
  "AEkAAwABBAkAAwBUAFcAAwABBAkABABCAKsAAwABBAkABQAaAO0AAwABBAkABgA+AQcAAwABBAkBAAAM" +
  "AUUAAwABBAkBAQAOAEkAAwABBAkBAgAMAVEAAwABBAkBAwAIAV1XZWlnaHRSZWd1bGFyTWVkaXVtQm9s" +
  "ZABIAFYAQQBSACAAUwBpAG4AZwBsAGUATQBvAGQAZQBsACAASQBuAGQAaQByAGUAYwB0AFIAZQBnAHUA" +
  "bABhAHIAMQAuADAAMAAwADsATgBPAE4ARQA7AEgAVgBBAFIAUwBpAG4AZwBsAGUATQBvAGQAZQBsAEkA" +
  "bgBkAGkAcgBlAGMAdAAtAFIAZQBnAHUAbABhAHIASABWAEEAUgAgAFMAaQBuAGcAbABlAE0AbwBkAGUA" +
  "bAAgAEkAbgBkAGkAcgBlAGMAdAAgAFIAZQBnAHUAbABhAHIAVgBlAHIAcwBpAG8AbgAgADEALgAwADAA" +
  "MABIAFYAQQBSAFMAaQBuAGcAbABlAE0AbwBkAGUAbABJAG4AZABpAHIAZQBjAHQALQBSAGUAZwB1AGwA" +
  "YQByAFcAZQBpAGcAaAB0AE0AZQBkAGkAdQBtAEIAbwBsAGQAAAIAAAAAAAD/nAAyAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAGAAAAAMAJAAsADcAyQCtAMwAzwECAQMBBAEFAQYBBwEIAQkBCgELAQwBDQEOAQ8BEAdB" +
  "bWFjcm9uB0ltYWNyb24JYWN1dGVjb21iCWdyYXZlY29tYgptYWNyb25jb21iBUEuMDAxBUEuMDAyBUEu" +
  "MDAzBUEuMDA0BUEuMDA1BUEuMDA2BUEuMDA3BUEuMDA4BUEuMDA5BUEuMDEwAAAAAAEAAAAMAAAAAAAA" +
  "AAIAAQALAA0AAwAAAAEAAAAAABQAAAA2AAAAAAAAAAAAAQAAAAwAAQAAABYAAQABAABAAEAAAAQAAAAB" +
  "AAAARmR4AAEADwACAwECAwMBAQMBAAAAAgAAAAABAAEACAABAAAAFAAAAAAAAAACd2dodAEAAAAAAQAA" +
  "ABAAAgABABQAAwAId2dodAGQAAABkAAAArwAAAAAAQABAQAAAZAAAAECAAAB9AAAAQMAAAK8AAAAAQAA" +
  "AAEAAQAAAEYAGAAAAAAASAAAAAAABwAaACMAMAA5AEIASwBUAF0AZgBxAHwAhQCMAJMAmgChAKgArwC2" +
  "AL0AxADLQACAAQAIAAUAAACAAGSBg4ABAAgAHAAAAAwJC31wID1WEB1WYAB4gQoZ//8NAdTr4w4e6IMA" +
  "gAEACAAJAAAABQ44OA4ARoGHgAEACAALAAAFBAECAgICBGQCUyFkgAHi4oGAAQAIAAYAAAIBAQIBRngB" +
  "DwCAAQAIAAYAAAIBAQIBPngBDgCAAQAIAAYAAAIBAQIBI0YBCQCAAQAIAAYAAAIBAQIBG0YBAQCAAQAI" +
  "AAYAAAIBAQIBPXgBMgCAAQAIAAYAAAIBAQIBDUYBOACAAQAIAAwAAAAD7fUgEIMD/vn3+oMAgAEACAAM" +
  "AAAAAxbz4w6DA/769/mDAIABAAgABgAAAgEBAgEl7IAA2YABAAgABQAAAIAAZIGDgAEACAAFAAAAgABk" +
  "gYOAAQAIAAUAAACAAGSBg4ABAAgABQAAAIAAZIGDgAEACAAFAAAAgABkgYOAAQAIAAUAAACAAGSBg4AB" +
  "AAgABQAAAIAAZIGDgAEACAAFAAAAgABkgYOAAQAIAAUAAACAAGSBg4ABAAgABQAAAIAAZIGDAAA="
}

///|
test "hvar truncated adv: hinter kind + empty advance" {
  let font = hvar_font()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let coords : Array[@moon_skrifa.NormalizedCoord] = Array::from_fixed_array([
    8192,
  ])
  let loc = @moon_skrifa.LocationRef::new(coords.op_as_view())
  let size = @moon_skrifa.Size::new(24.0)
  let hinting = HintingInstance::new(
    outlines0,
    size,
    loc,
    HintingOptions::default(),
  ).unwrap()
  let kind_tag = match hinting.kind {
    HinterKind::None_ => "None"
    HinterKind::Glyf(_) => "Glyf"
    HinterKind::Cff(_) => "Cff"
    HinterKind::Auto(_) => "Auto"
  }
  inspect(kind_tag, content="Auto")
  let outlines = OutlineGlyphCollection::from_font(font)
  let gid = font.charmap().glyph_id((32).reinterpret_as_uint()).unwrap()
  let glyph = outlines.get(gid).unwrap()
  let metrics = glyph
    .draw(DrawSettings::hinted(hinting, false), NullPen::new())
    .unwrap()
  inspect(metrics.advance_width, content="Some(11)")
}
