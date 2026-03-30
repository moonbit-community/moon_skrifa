# Skrifa Parity Issue Tracker

Last updated: 2026-03-30

## Status Legend

- `TODO`: not started
- `IN_PROGRESS`: currently being fixed
- `BLOCKED_PLATFORM`: blocked by platform/public API limitations or external dependency constraints
- `DONE`: fixed and verified locally

## Issues

| ID | Source | Problem | Status | Notes |
| --- | --- | --- | --- | --- |
| `PARITY-001` | `src/core/bitmap.mbt` vs `fontations-reference/skrifa/src/bitmap.rs` | `BitmapStrikes` lacks upstream convenience APIs (`glyph_for_size`, iterator-style traversal), so strike selection behavior coverage is narrower. | `TODO` | Reference has `glyph_for_size()` + `iter()`; Moon side currently exposes `len()` + `get(index)` only. |
| `PARITY-002` | `src/core/colr.mbt`, `src/core/color_traversal.mbt` vs `fontations-reference/skrifa/src/color/mod.rs` | High-level color glyph abstraction mismatch: missing `ColorGlyphFormat`/`ColorGlyph` and `get_with_format` workflow used upstream. | `TODO` | Moon side has `ColorGlyphCollection::layers()` and `FontRef::paint_colr_v1*` but no `ColorGlyph` object API. |
| `PARITY-003` | `src/core/color.mbt` vs `fontations-reference/skrifa/src/color/mod.rs` | CPAL API is reduced: missing `ColorPalette` abstraction and palette metadata APIs (palette type/label/index, color labels). | `TODO` | Reference exposes `ColorPalette` and `ColorPalettes::get()/color_label()`. |
| `PARITY-004` | `src/core/glyph_name.mbt:151,403` vs `fontations-reference/skrifa/src/glyph_name.rs` | Glyph-name decoding scope is limited (ASCII-only custom strings, CFF charset format 0 only). | `TODO` | Comments explicitly mark MVP constraints; upstream uses generic charset access. |
| `PARITY-005` | `src/core/metrics.mbt:537` vs `fontations-reference/skrifa/src/metrics.rs` | `GlyphMetrics` is marked as partial port; behavior parity for all metric paths and var-delta edge cases is not yet fully audited. | `TODO` | Source comment states current support subset; needs symbol/behavior diff against upstream metrics paths. |
| `PARITY-006` | `src/outline/glyf.mbt:792` vs `fontations-reference/skrifa/src/outline/glyf/mod.rs` | Composite glyph point-matching path is unsupported (`return None`), causing composite handling divergence. | `TODO` | Moon code explicitly exits for point matching; upstream glyf scaler handles anchor-based composites. |
| `PARITY-007` | `src/outline/gvar.mbt:16` vs `fontations-reference/skrifa/src/outline/glyf/deltas.rs` and related | `gvar` implementation is documented as MVP (simple deltas + IUP), leaving potential gaps for full variation semantics. | `TODO` | Needs targeted audit for composite/tuple edge behavior parity. |
| `PARITY-008` | `src/outline/cff.mbt:16` vs `fontations-reference/skrifa/src/outline/cff/mod.rs` | CFF support is scoped to MVP with single-font FontSet assumption; broader upstream coverage may be missing. | `TODO` | Source comment states single-font support only. |
| `PARITY-009` | `src/outline/cff2.mbt:16` vs `fontations-reference/skrifa/src/outline/cff/mod.rs` + `type2` paths | CFF2 implementation is MVP-scoped; full operator/variation coverage parity is not yet guaranteed. | `TODO` | Source comment marks MVP scope; requires focused operator-level diff audit. |
| `PARITY-010` | `src/outline/tt_hint_zone.mbt:16` vs `fontations-reference/skrifa/src/outline/glyf/hint/zone.rs` | TrueType hint zone subsystem is marked partial port, implying remaining opcode/zone-behavior drift risk. | `TODO` | Track with existing TT hint wbtests and add upstream case imports as needed. |
| `PARITY-011` | `src/core/charmap.mbt:669` vs `fontations-reference/skrifa/src/charmap.rs` | cmap format 4 iteration is intentionally simplified instead of faithful iterator port; edge-case behavior may differ. | `TODO` | Comment documents simplified algorithm; audit against upstream iterator outputs on tricky fonts. |
| `PARITY-012` | `src/core/collections.mbt:31` vs `fontations-reference/skrifa/src/collections.rs` | `SmallVec` diverges from upstream const-generic model (`inline_cap` runtime), which may affect edge behavior/perf characteristics. | `TODO` | Comment documents representation difference; validate no semantic regressions in boundary cases. |

## Current Work Queue

1. `PARITY-006`
2. `PARITY-004`
3. `PARITY-002`
4. `PARITY-003`
5. `PARITY-001`
6. `PARITY-007`
7. `PARITY-008`
8. `PARITY-009`
9. `PARITY-010`
10. `PARITY-011`
11. `PARITY-005`
12. `PARITY-012`
