# Milky2018/moon_skrifa

MoonBit port of Fontations `skrifa` (font parsing + metrics + color/bitmap glyph helpers).

Repository: https://github.com/moonbit-community/moon_skrifa

## Status

- The public API and behavior aim to match `fontations/skrifa` (`fontations-reference/` in this repo).
- Embedded hinting (TrueType `glyf`) is implemented and wired into outline drawing via `HintingInstance` + `DrawSettings::hinted(...)`.
  - Supports both simple and composite `glyf` glyphs (FreeType-style path building).
  - Non-pedantic hinting matches fontations behavior (interpreter errors may be ignored); pedantic mode returns errors.
- Runtime autohinting (for fonts without embedded instructions) is still WIP:
  - style classification + outline topology (segments) are ported
  - edge building / metrics / hint application are not yet implemented
- CFF/CFF2 outlines are supported; CFF/CFF2 hinting for `Engine::Interpreter` is not yet implemented.

## Packages

- `Milky2018/moon_skrifa`: facade re-exporting `Milky2018/moon_skrifa/core` (+ `OutlineGlyph*`)
- `Milky2018/moon_skrifa/core`: core metadata (FontRef, charmap, names/strings, metrics, bitmaps, COLR traversal)
- `Milky2018/moon_skrifa/outline`: outline extraction (glyf/CFF/CFF2), pens + SVG path output

## Install / Import

Add the dependency to your package `moon.pkg.json`:

```json
{
  "import": [
    "moonbitlang/core/prelude",
    "moonbitlang/core/bytes",
    { "path": "Milky2018/moon_skrifa", "alias": "moon_skrifa" },
    { "path": "Milky2018/moon_skrifa/outline", "alias": "moon_skrifa_outline" }
  ]
}
```

Then use the package via `@moon_skrifa` / `@moon_skrifa_outline`:

```moonbit
let font = @moon_skrifa.FontRef::new(font_bytes).unwrap()
let outlines = @moon_skrifa_outline.OutlineGlyphCollection::from_font(font)
```

## Core APIs

### Variation Axes / Locations (fvar/avar)

If you have user-space axis values (e.g. `wght=700`), use `axes().location(...)` to
build a normalized location (this also applies `avar` remapping when present):

```moonbit
let axes = font.axes()
let settings : Array[@moon_skrifa.VariationSetting] = Array::from_fixed_array([
  @moon_skrifa.Setting::new(@moon_skrifa.Tag::from_str("wght").unwrap(), 700.0),
])
let loc = axes.location(settings.op_as_view()).as_ref()
```

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
let fm = font.metrics(@moon_skrifa.Size::new(16.0), @moon_skrifa.LocationRef::default())
let gm = font.glyph_metrics(@moon_skrifa.Size::unscaled(), @moon_skrifa.LocationRef::default())

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
- `location` (`@moon_skrifa.LocationRef`)
  - normalized coords are `Int` in F2Dot14; `16384` == `1.0`
  - if you have user coords, prefer `font.axes().location(...).as_ref()`
- `path_style` (`PathStyle::FreeType` or `PathStyle::HarfBuzz`)
- optional embedded hinting via `HintingInstance` + `DrawSettings::hinted(...)`

Create and use a hinting instance:

```moonbit
let outlines0 = @moon_skrifa_outline.OutlineGlyphCollection::from_font(font)
let hinter =
  @moon_skrifa_outline.HintingInstance::new(
    outlines0,
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
    @moon_skrifa_outline.HintingOptions::default(),
  ).unwrap()

let settings = @moon_skrifa_outline.DrawSettings::hinted(hinter, false)
let svg = outlines.svg_path(gid, settings).unwrap()
```

## Development

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`
