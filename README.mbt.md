# Milky2018/moon_skrifa

MoonBit port of Fontations `skrifa` (font parsing + metrics + color/bitmap glyph helpers).

Repository: https://github.com/moonbit-community/moon_skrifa

## Status

- The tracked porting tasks in this repo are complete and pushed to `main`.
- This is still an incremental port: API/behavior may differ from upstream in places.

## Packages

- `Milky2018/moon_skrifa`: core (FontRef, charmap, names/strings, metrics, bitmaps, COLR traversal)
- `Milky2018/moon_skrifa/outline`: outline extraction (glyf/CFF/CFF2), pens + SVG path output

## Install / Import

Add the dependency to your package `moon.pkg.json`:

```json
{
  "import": [
    "moonbitlang/core/prelude",
    "moonbitlang/core/bytes",
    "Milky2018/moon_skrifa"
  ]
}
```

Then use the package via `@moon_skrifa`:

```moonbit
let font = @moon_skrifa.FontRef::new(font_bytes).unwrap()
```

## Core APIs

### Charmap (codepoint -> glyph id)

```moonbit
let cmap = font.charmap().unwrap()
let gid = cmap.glyph_id(0x41).unwrap() // 'A'
```

### Name / Localized Strings (name table)

```moonbit
let family = font.localized_strings(@moon_skrifa.STRING_ID_FAMILY_NAME)
match family.english_or_first() {
  None => ()
  Some(s) => {
    let lang = s.language() // Option[String]
    let value = s.to_string()
    // ...
  }
}
```

### Font / Glyph Metrics

```moonbit
let fm = font.font_metrics(@moon_skrifa.Size::new(16.0))
let gm = font.glyph_metrics(@moon_skrifa.Size::unscaled(), @moon_skrifa.LocationRef::default()).unwrap()

let aw = gm.advance_width(gid).unwrap()
let lsb = gm.left_side_bearing(gid).unwrap()
let bounds = gm.bounds(gid) // Option[GlyphBounds]
```

`GlyphMetrics` supports:
- HVAR deltas when present
- gvar phantom-deltas fallback for advance/lsb when HVAR is missing

### Bitmap Strikes (sbix/CBDT/EBDT)

```moonbit
let strikes = font.bitmap_strikes()
for i in 0..<strikes.len() {
  let strike = strikes.get(i).unwrap()
  let bmp = strike.get(gid)
  // BitmapGlyph has format/data/ppem/origin/width/height
}
```

### COLRv1 Paint Traversal (gradients/var/clip)

Implement `ColorPainter` and call:

```moonbit
let loc = @moon_skrifa.LocationRef::default()
try! font.paint_colr_v1_at(gid, loc, painter) |> ignore
```

Brush variants include:
- `Solid(palette_index, alpha)`
- `LinearGradient(p0, p1, stops, extend)`
- `RadialGradient(c0, r0, c1, r1, stops, extend)`
- `SweepGradient(c0, start_deg, end_deg, stops, extend)`

## Outline Package

Add `Milky2018/moon_skrifa/outline` and use:

```moonbit
let c = @moon_skrifa_outline.OutlineGlyphCollection::from_font(font)
let svg = c.svg_path(gid)
```

## Development

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`
