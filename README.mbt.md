# Milky2018/moon_skrifa

A MoonBit library for OpenType font reading and outline drawing.

It provides:
- font metadata access (cmap, names, metrics, variation axes)
- bitmap glyph access (`sbix`, `CBDT/EBDT`)
- color glyph paint traversal (`COLR`)
- outline extraction and drawing (`glyf`, `CFF`, `CFF2`)

Repository: https://github.com/moonbit-community/moon_skrifa

## Packages

- `Milky2018/moon_skrifa`: facade exports for common entry points
- `Milky2018/moon_skrifa/core`: font metadata, metrics, strings, bitmap/color helpers
- `Milky2018/moon_skrifa/outline`: outline extraction, pens, and SVG path helpers

## Install

Add dependency imports in `moon.pkg`:

```moon
import {
  "moonbitlang/core/prelude",
  "moonbitlang/core/bytes",
  "Milky2018/moon_skrifa" @moon_skrifa,
  "Milky2018/moon_skrifa/outline" @moon_skrifa_outline,
}
```

## Quick Start

```moonbit
let font = @moon_skrifa.FontRef::new(font_bytes).unwrap()
let outlines = @moon_skrifa_outline.OutlineGlyphCollection::from_font(font)

let cmap = font.charmap().unwrap()
let gid = cmap.glyph_id(0x41).unwrap() // 'A'

let settings =
  @moon_skrifa_outline.DrawSettings::unhinted(
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
  )

let svg_path = outlines.svg_path(gid, settings).unwrap()
```

## Core API Guide

### Variation Axes and Locations

Build normalized locations from user-space axis values:

```moonbit
let axes = font.axes()
let settings : Array[@moon_skrifa.VariationSetting] = Array::from_fixed_array([
  @moon_skrifa.Setting::new(@moon_skrifa.Tag::from_str("wght").unwrap(), 700.0),
])
let loc = axes.location(settings.op_as_view()).as_ref()
```

### Character Mapping

```moonbit
let cmap = font.charmap().unwrap()
let gid = cmap.glyph_id(0x4F60).unwrap() // example codepoint
```

### Localized Name Strings

```moonbit
let family = font.localized_strings(@moon_skrifa.STRING_ID_FAMILY_NAME)
match family.english_or_first() {
  None => ()
  Some(s) => {
    let lang = s.language() // Option[String]
    let value = s.to_string()
    lang |> ignore
    value |> ignore
  }
}
```

### Metrics

```moonbit
let fm = font.metrics(
  @moon_skrifa.Size::new(16.0),
  @moon_skrifa.LocationRef::default(),
)
let gm = font.glyph_metrics(
  @moon_skrifa.Size::unscaled(),
  @moon_skrifa.LocationRef::default(),
)

let aw = gm.advance_width(gid)
let lsb = gm.left_side_bearing(gid)
let bounds = gm.bounds(gid)

fm |> ignore
aw |> ignore
lsb |> ignore
bounds |> ignore
```

### Bitmap Glyphs

```moonbit
let strikes = font.bitmap_strikes()
for i in 0..<strikes.len() {
  let strike = strikes.get(i).unwrap()
  let bmp = strike.get(gid)
  bmp |> ignore
}
```

### Color Paint Traversal (COLR)

Implement `ColorPainter`, then call:

```moonbit
let loc = @moon_skrifa.LocationRef::default()
try! font.paint_colr_v1_at(gid, loc, painter) |> ignore
```

## Outline API Guide

### Unhinted Draw

```moonbit
let settings =
  @moon_skrifa_outline.DrawSettings::unhinted(
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
  )
let path = outlines.path(gid, settings)
path |> ignore
```

### Hinted Draw

```moonbit
let hinter =
  @moon_skrifa_outline.HintingInstance::new(
    outlines,
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
    @moon_skrifa_outline.HintingOptions::default(),
  ).unwrap()

let settings = @moon_skrifa_outline.DrawSettings::hinted(hinter, false)
let svg = outlines.svg_path(gid, settings)
svg |> ignore
```

### Path Styles

`DrawSettings` supports:
- `PathStyle::FreeType`
- `PathStyle::HarfBuzz`

Set with:

```moonbit
let settings =
  @moon_skrifa_outline.DrawSettings::unhinted(
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
  ).with_path_style(@moon_skrifa_outline.PathStyle::HarfBuzz)
settings |> ignore
```

## Development

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`
