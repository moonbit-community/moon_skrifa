# Milky2018/moon_skrifa

MoonBit port of Fontations `skrifa` (font parsing + metrics + color/bitmap glyph helpers).

Repository: https://github.com/moonbit-community/moon_skrifa

## Status

- The public API and behavior aim to match `fontations/skrifa` (`fontations-reference/` in this repo).
- Embedded hinting is currently a no-op skeleton (API surface exists; grid-fitting not implemented yet).

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
    "Milky2018/moon_skrifa",
    "Milky2018/moon_skrifa/outline"
  ]
}
```

Then use the package via `@moon_skrifa` / `@moon_skrifa_outline`:

```moonbit
let font = @moon_skrifa.FontRef::new(font_bytes).unwrap()
let outlines = @moon_skrifa_outline.OutlineGlyphCollection::from_font(font)
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

Use `OutlineGlyphCollection` to get outlines from `glyf`/`CFF`/`CFF2`:

```moonbit
let gid = 1

let settings =
  @moon_skrifa_outline.DrawSettings::unhinted(
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
  )

let svg = outlines.svg_path(gid, settings).unwrap()
let path = outlines.path(gid, settings).unwrap()
```

`DrawSettings` controls:
- `size` (`@moon_skrifa.Size`)
- `location` (`@moon_skrifa.LocationRef`, normalized coords as `Int` in F2Dot14; `16384` == `1.0`)
- `path_style` (`PathStyle::FreeType` or `PathStyle::HarfBuzz`)
- optional hinting via `HintingInstance` (currently disabled/no-op)

## Development

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`
