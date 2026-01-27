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
/// Support for applying embedded hinting instructions.
///
/// Ported from `fontations/skrifa/src/outline/hint.rs` (Apache-2.0 OR MIT).

///|
pub(all) suberror HintError {
  Unsupported
  UnexpectedEndOfBytecode
  /// Execution stopped on an opcode that this port does not yet implement.
  UnhandledOpcode(Int, Int)
  DefinitionInGlyphProgram
  NestedDefinition
  DefinitionTooLarge
  TooManyDefinitions
  InvalidDefinition(Int)
  ValueStackOverflow
  ValueStackUnderflow
  CallStackOverflow
  CallStackUnderflow
  InvalidStackValue(Int)
  InvalidPointIndex(Int)
  InvalidPointRange(Int, Int)
  InvalidContourIndex(Int)
  InvalidCvtIndex(Int)
  InvalidStorageIndex(Int)
  DivideByZero
  InvalidZoneIndex(Int)
  NegativeLoopCounter
  InvalidJump
  ExceededExecutionBudget
}

///|
pub struct HintingOptions {
  engine : Engine
  target : Target
}

///|
pub fn HintingOptions::default() -> HintingOptions {
  HintingOptions::{ engine: Engine::AutoFallback, target: Target::default() }
}

///|
/// Creates hinting options with explicit engine + target.
pub fn HintingOptions::new(engine : Engine, target : Target) -> HintingOptions {
  HintingOptions::{ engine, target }
}

///|
pub(all) enum Engine {
  Interpreter
  /// Automatic hinter that adjusts outlines without embedded instructions.
  ///
  /// Glyph styles can be precomputed per font and may be provided here as an
  /// optimization to avoid recomputing them for each instance.
  Auto(GlyphStyles?)
  AutoFallback
}

///|
/// Resolves `AutoFallback` based on outline collection preference.
pub fn Engine::resolve_auto_fallback(
  self : Engine,
  outlines : OutlineGlyphCollection,
) -> Engine {
  match self {
    Engine::AutoFallback =>
      if outlines.prefer_interpreter() {
        Engine::Interpreter
      } else {
        Engine::Auto(None)
      }
    _ => self
  }
}

///|
/// Converts an engine selection into `HintingOptions` with default target.
pub fn Engine::into(self : Engine) -> HintingOptions {
  HintingOptions::new(self, Target::default())
}

///|
pub(all) enum Target {
  Mono
  Smooth(SmoothMode, Bool, Bool)
}

///|
pub fn Target::default() -> Target {
  SmoothMode::Normal.into()
}

///|
pub(all) enum SmoothMode {
  Normal
  Light
  Lcd
  VerticalLcd
}

///|
pub fn SmoothMode::into(self : SmoothMode) -> Target {
  Target::Smooth(self, true, false)
}

///|
/// Modes that control hinting when using embedded instructions.
///
/// This mirrors the legacy FreeType hinting mode selector and is intentionally
/// undocumented upstream.
pub(all) enum HintingMode {
  Strong
  Smooth(LcdLayout?, Bool)
}

///|
/// Specifies direction of pixel layout for LCD-based subpixel hinting.
pub(all) enum LcdLayout {
  Horizontal
  Vertical
}

///|
pub fn HintingMode::into(self : HintingMode) -> HintingOptions {
  let target = match self {
    HintingMode::Strong => Target::Mono
    HintingMode::Smooth(lcd_subpixel, preserve_linear_metrics) => {
      let mode = match lcd_subpixel {
        None => SmoothMode::Normal
        Some(LcdLayout::Horizontal) => SmoothMode::Lcd
        Some(LcdLayout::Vertical) => SmoothMode::VerticalLcd
      }
      Target::Smooth(mode, true, preserve_linear_metrics)
    }
  }
  HintingOptions::{ engine: Engine::AutoFallback, target }
}

///|
pub fn Target::mode(self : Target) -> SmoothMode? {
  match self {
    Target::Smooth(mode, _, _) => Some(mode)
    _ => None
  }
}

///|
pub fn Target::symmetric_rendering(self : Target) -> Bool {
  match self {
    Target::Smooth(_, symmetric, _) => symmetric
    _ => false
  }
}

///|
pub fn Target::preserve_linear_metrics(self : Target) -> Bool {
  match self {
    Target::Smooth(_, _, preserve) => preserve
    _ => false
  }
}

///|
pub fn Target::is_smooth(self : Target) -> Bool {
  match self {
    Target::Smooth(_, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_grayscale_cleartype(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::Normal, _, _) => true
    Target::Smooth(SmoothMode::Light, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_light(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::Light, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_lcd(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::Lcd, _, _) => true
    _ => false
  }
}

///|
pub fn Target::is_vertical_lcd(self : Target) -> Bool {
  match self {
    Target::Smooth(SmoothMode::VerticalLcd, _, _) => true
    _ => false
  }
}

///|
/// Hinting instance that uses information embedded in the font to perform
/// grid-fitting.
///
/// This follows the same high-level behavior as upstream:
/// - The backend engine is selected at configuration time (Interpreter/Auto).
/// - For TrueType outlines, `fpgm` + `prep` are executed during configuration.
pub struct HintingInstance {
  priv mut size : @moon_skrifa.Size
  priv coords : Array[@moon_skrifa.NormalizedCoord]
  priv mut target : Target
  priv mut kind : HinterKind
}

///|
priv enum HinterKind {
  None_
  Glyf(TtHintInstance)
  Auto(AutoHintInstance)
}

///|
priv struct AutoHintInstance {
  styles : GlyphStyles
}

///|
fn AutoHintInstance::new(
  outlines : OutlineGlyphCollection,
  styles : GlyphStyles?,
) -> AutoHintInstance {
  let resolved = match styles {
    Some(s) => s
    None => GlyphStyles::new(outlines)
  }
  AutoHintInstance::{ styles: resolved }
}

///|
fn hint_round_ppem(scale_bits : Int, upem : Int) -> Int {
  let v = scale_bits.to_int64() * upem.to_int64()
  let ppem_26_6 = (v + (0x8000).to_int64()) >> 16
  ((ppem_26_6 + (32).to_int64()) >> 6).to_int()
}

///|
pub fn HintingInstance::new(
  outlines : OutlineGlyphCollection,
  size : @moon_skrifa.Size,
  location : @moon_skrifa.LocationRef,
  options : HintingOptions,
) -> Result[HintingInstance, DrawError] {
  let h = HintingInstance::{
    size: @moon_skrifa.Size::unscaled(),
    coords: Array::new(),
    target: options.target,
    kind: HinterKind::None_,
  }
  match h.reconfigure(outlines, size, location, options) {
    Err(e) => Err(e)
    Ok(_) => Ok(h)
  }
}

///|
pub fn HintingInstance::size(self : HintingInstance) -> @moon_skrifa.Size {
  self.size
}

///|
pub fn HintingInstance::location(
  self : HintingInstance,
) -> @moon_skrifa.LocationRef {
  @moon_skrifa.LocationRef::new(self.coords.op_as_view())
}

///|
pub fn HintingInstance::target(self : HintingInstance) -> Target {
  self.target
}

///|
pub fn HintingInstance::is_enabled(self : HintingInstance) -> Bool {
  match self.kind {
    HinterKind::None_ => false
    HinterKind::Glyf(tt) => tt.is_enabled()
    HinterKind::Auto(_) => true
  }
}

///|
pub fn HintingInstance::reconfigure(
  self : HintingInstance,
  outlines : OutlineGlyphCollection,
  size : @moon_skrifa.Size,
  location : @moon_skrifa.LocationRef,
  options : HintingOptions,
) -> Result[Unit, DrawError] {
  self.size = size
  self.coords.clear()
  for c in location.effective_coords().iter() {
    self.coords.push(c)
  }
  self.target = options.target
  let engine = match options.engine {
    Engine::AutoFallback =>
      if outlines.prefer_interpreter() {
        Engine::Interpreter
      } else {
        Engine::Auto(None)
      }
    _ => options.engine
  }
  let prev = self.kind
  self.kind = HinterKind::None_
  match engine {
    Engine::Interpreter =>
      match outlines.format() {
        Some(OutlineGlyphFormat::Glyf) => {
          let tt = match prev {
            HinterKind::Glyf(inst) => inst
            _ => TtHintInstance::default()
          }
          let upem = outline_units_per_em(outlines.font).to_int()
          let size_for_scale = match size.ppem() {
            None => size
            Some(ppem) =>
              if outlines.fractional_size_hinting() {
                size
              } else {
                @moon_skrifa.Size::new(ppem.round())
              }
          }
          let (_, scale_bits) = glyf_compute_scale_bits(
            size_for_scale,
            upem.to_uint16(),
          )
          let rounded_ppem = hint_round_ppem(scale_bits, upem)
          match
            tt.reconfigure(
              outlines.font,
              scale_bits,
              rounded_ppem,
              self.target,
              self.coords.op_as_view(),
            ) {
            Err(e) => return Err(DrawError::HintingFailed(e))
            Ok(_) => ()
          }
          self.kind = HinterKind::Glyf(tt)
        }
        _ => ()
      }
    Engine::Auto(_styles) =>
      match outlines.format() {
        None => ()
        Some(_) =>
          self.kind = HinterKind::Auto(AutoHintInstance::new(outlines, _styles))
      }
    _ => ()
  }
  Ok(())
}

///|
fn tt_bits_to_double(bits : Int) -> Double {
  bits.to_double() / 64.0
}

///|
fn tt_zone_emit_contour_freetype(
  out : Array[PathElement],
  zone : TtZone,
  start : Int,
  end : Int,
  x_shift : Int,
) -> Unit {
  let n = end - start + 1
  if n <= 0 {
    return
  }
  let first = zone.points.at(start)
  let last = zone.points.at(end)
  let first_on = (zone.flags.at(start) & TT_POINT_ON_CURVE) != 0
  let last_on = (zone.flags.at(end) & TT_POINT_ON_CURVE) != 0
  let (sx, sy, start_idx) = if first_on {
    (first.x - x_shift, first.y, start)
  } else if last_on {
    (last.x - x_shift, last.y, end)
  } else {
    (
      glyf_midpoint_i32(last.x - x_shift, first.x - x_shift),
      glyf_midpoint_i32(last.y, first.y),
      -1,
    )
  }
  out.push(MoveTo(tt_bits_to_double(sx), tt_bits_to_double(sy)))
  let mut control : (Int, Int)? = None
  if start_idx == -1 {
    for i in start..<(end + 1) {
      let p = zone.points.at(i)
      let on = (zone.flags.at(i) & TT_POINT_ON_CURVE) != 0
      let px = p.x - x_shift
      let py = p.y
      if on {
        match control {
          None => out.push(LineTo(tt_bits_to_double(px), tt_bits_to_double(py)))
          Some((cx, cy)) => {
            out.push(
              QuadTo(
                tt_bits_to_double(cx),
                tt_bits_to_double(cy),
                tt_bits_to_double(px),
                tt_bits_to_double(py),
              ),
            )
            control = None
          }
        }
      } else {
        match control {
          None => control = Some((px, py))
          Some((cx, cy)) => {
            let mx = glyf_midpoint_i32(cx, px)
            let my = glyf_midpoint_i32(cy, py)
            out.push(
              QuadTo(
                tt_bits_to_double(cx),
                tt_bits_to_double(cy),
                tt_bits_to_double(mx),
                tt_bits_to_double(my),
              ),
            )
            control = Some((px, py))
          }
        }
      }
    }
  } else {
    let base = start_idx - start
    for step in 1..<n {
      let idx = start + (base + step) % n
      let p = zone.points.at(idx)
      let on = (zone.flags.at(idx) & TT_POINT_ON_CURVE) != 0
      let px = p.x - x_shift
      let py = p.y
      if on {
        match control {
          None => out.push(LineTo(tt_bits_to_double(px), tt_bits_to_double(py)))
          Some((cx, cy)) => {
            out.push(
              QuadTo(
                tt_bits_to_double(cx),
                tt_bits_to_double(cy),
                tt_bits_to_double(px),
                tt_bits_to_double(py),
              ),
            )
            control = None
          }
        }
      } else {
        match control {
          None => control = Some((px, py))
          Some((cx, cy)) => {
            let mx = glyf_midpoint_i32(cx, px)
            let my = glyf_midpoint_i32(cy, py)
            out.push(
              QuadTo(
                tt_bits_to_double(cx),
                tt_bits_to_double(cy),
                tt_bits_to_double(mx),
                tt_bits_to_double(my),
              ),
            )
            control = Some((px, py))
          }
        }
      }
    }
  }
  match control {
    Some((cx, cy)) =>
      out.push(
        QuadTo(
          tt_bits_to_double(cx),
          tt_bits_to_double(cy),
          tt_bits_to_double(sx),
          tt_bits_to_double(sy),
        ),
      )
    None => ()
  }
  out.push(Close)
}

///|
fn tt_zone_to_path_freetype(zone : TtZone) -> Array[PathElement] {
  if zone.contours.length() == 0 {
    return Array::new()
  }
  let last_end = zone.contours.at(zone.contours.length() - 1)
  let num_points = last_end + 1
  if num_points <= 0 || zone.points.length() < num_points + 4 {
    return Array::new()
  }
  let x_shift = zone.points.at(num_points).x
  let out : Array[PathElement] = Array::new()
  let mut start = 0
  for end_ix in zone.contours.iter() {
    if end_ix >= start {
      tt_zone_emit_contour_freetype(out, zone, start, end_ix, x_shift)
    }
    start = end_ix + 1
  }
  out
}

///|
const TAG_HDMX_TT_HINT : UInt = 0x68646D78 // "hdmx"

///|
const TAG_MAXP_TT_HINT : UInt = 0x6D617870 // "maxp"

///|
fn hint_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn hint_read_u32_be(view : BytesView, offset : Int) -> UInt? {
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
fn hint_hdmx_width(
  font : @moon_skrifa.FontRef,
  ppem : Int,
  gid : @moon_skrifa.GlyphId,
) -> Int? {
  let hdmx = match font.table(TAG_HDMX_TT_HINT) {
    None => return None
    Some(v) => v
  }
  if hdmx.length() < 8 {
    return None
  }
  let maxp = match font.table(TAG_MAXP_TT_HINT) {
    None => return None
    Some(v) => v
  }
  let num_glyphs = hint_read_u16_be(maxp, 4).unwrap_or(0)
  if num_glyphs <= 0 {
    return None
  }
  let idx = gid.to_uint64().to_int()
  if idx < 0 || idx >= num_glyphs {
    return None
  }
  let num_records = hint_read_u16_be(hdmx, 2).unwrap_or(0)
  let rec_size = hint_read_u32_be(hdmx, 4).unwrap_or(0).to_uint64().to_int()
  if rec_size <= 0 {
    return None
  }
  let base = 8
  for i in 0..<num_records {
    let off = base + i * rec_size
    if off < 0 || off + rec_size > hdmx.length() {
      continue
    }
    // record: ppem (u8), max_width (u8), widths[num_glyphs]
    if off + 2 + num_glyphs > hdmx.length() {
      continue
    }
    let pix = hdmx.at(off).to_int()
    if pix == ppem {
      let widths_off = off + 2
      return Some(hdmx.at(widths_off + idx).to_int())
    }
  }
  None
}

///|
fn HintingInstance::hinted_path(
  self : HintingInstance,
  glyph : OutlineGlyph,
  is_pedantic : Bool,
  path_style : PathStyle,
) -> Result[(AdjustedMetrics, Array[PathElement]), DrawError] {
  match self.kind {
    HinterKind::None_ => Err(DrawError::NoSources)
    HinterKind::Auto(a) =>
      a.hinted_path(
        glyph,
        self.size,
        @moon_skrifa.LocationRef::new(self.coords.op_as_view()),
        path_style,
      )
    HinterKind::Glyf(tt) => {
      if path_style is PathStyle::HarfBuzz {
        return Err(DrawError::HarfBuzzHintingUnsupported)
      }
      if !tt.is_enabled() {
        let settings = DrawSettings::unhinted(
          self.size,
          @moon_skrifa.LocationRef::new(self.coords.op_as_view()),
        ).with_path_style(path_style)
        let metrics0 = match glyph.draw(settings, NullPen::new()) {
          Err(e) => return Err(e)
          Ok(m) => m
        }
        let metrics = AdjustedMetrics::{
          has_overlaps: metrics0.has_overlaps,
          lsb: metrics0.lsb,
          advance_width: match metrics0.advance_width {
            None => None
            Some(v) => Some(v.round())
          },
        }
        let path = match glyph.path(settings) {
          Err(e) => return Err(e)
          Ok(p) => p
        }
        return Ok((metrics, path))
      }
      self.hinted_glyf_path(glyph, is_pedantic)
    }
  }
}

///|
fn AutoHintInstance::hinted_path(
  self : AutoHintInstance,
  glyph : OutlineGlyph,
  size : @moon_skrifa.Size,
  location : @moon_skrifa.LocationRef,
  path_style : PathStyle,
) -> Result[(AdjustedMetrics, Array[PathElement]), DrawError] {
  let unscaled = DrawSettings::unhinted(@moon_skrifa.Size::unscaled(), location).with_path_style(
    path_style,
  )
  let unscaled_path = match glyph.path(unscaled) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  let outline = match glyph.kind {
    OutlineGlyphFormat::Glyf => {
      let o = AutoHintOutline::from_path(Array::new())
      match o.fill_glyf(glyph.font, glyph.glyph_id) {
        Ok(_) => o
        Err(_) => AutoHintOutline::from_path(unscaled_path)
      }
    }
    _ => AutoHintOutline::from_path(unscaled_path)
  }
  if outline.is_empty() {
    return Ok((AdjustedMetrics::default(), Array::new()))
  }
  outline.stats() |> ignore
  let axis_h = AutoHintAxis::default()
  axis_h.reset(AUTOHINT_DIM_HORIZONTAL, outline.orientation)
  autohint_compute_segments(outline, axis_h, AutoHintScriptGroup::Default)
  |> ignore
  autohint_link_segments(outline, axis_h, 0, AutoHintScriptGroup::Default, None)
  for seg in axis_h.segments.iter() {
    seg.delta |> ignore
    seg.serif_ix |> ignore
  }
  let axis_v = AutoHintAxis::default()
  axis_v.reset(AUTOHINT_DIM_VERTICAL, outline.orientation)
  autohint_compute_segments(outline, axis_v, AutoHintScriptGroup::Default)
  |> ignore
  autohint_link_segments(outline, axis_v, 0, AutoHintScriptGroup::Default, None)
  for seg in axis_v.segments.iter() {
    seg.delta |> ignore
    seg.serif_ix |> ignore
  }
  let settings = DrawSettings::unhinted(size, location).with_path_style(
    path_style,
  )
  let metrics0 = match glyph.draw(settings, NullPen::new()) {
    Err(e) => return Err(e)
    Ok(m) => m
  }
  let metrics = AdjustedMetrics::{
    has_overlaps: metrics0.has_overlaps,
    lsb: metrics0.lsb,
    advance_width: match metrics0.advance_width {
      None => None
      Some(v) => Some(v.round())
    },
  }
  let path = match glyph.path(settings) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  self.styles |> ignore
  Ok((metrics, path))
}

///|
fn HintingInstance::hinted_glyf_path(
  self : HintingInstance,
  glyph : OutlineGlyph,
  is_pedantic : Bool,
) -> Result[(AdjustedMetrics, Array[PathElement]), DrawError] {
  let tt = match self.kind {
    HinterKind::Glyf(tt) => tt
    _ => return Err(DrawError::NoSources)
  }
  let font = glyph.font
  let gid = glyph.glyph_id
  let scale_bits = tt.retained.scale
  let fpgm = font.table(TAG_FPGM_TT).unwrap_or(tt_empty_bytes_view())
  let prep = font.table(TAG_PREP_TT).unwrap_or(tt_empty_bytes_view())
  let zone = match
    tt_load_glyph_zone_for_hinting(
      font,
      gid,
      self.coords.op_as_view(),
      scale_bits,
      tt,
      fpgm,
      prep,
      is_pedantic,
    ) {
    Err(e) => return Err(e)
    Ok(z) => z
  }
  if zone.contours.length() == 0 {
    return Ok((AdjustedMetrics::default(), Array::new()))
  }
  let last_end = zone.contours.at(zone.contours.length() - 1)
  let num_points = last_end + 1
  if num_points < 0 || zone.points.length() < num_points + 4 {
    return Err(DrawError::GlyphNotFound(gid))
  }
  let phantom0 = zone.points.at(num_points)
  let phantom1 = zone.points.at(num_points + 1)
  let mut hdmx : Int? = None
  if !tt.backward_compatibility() {
    match self.size.ppem() {
      None => ()
      Some(ppem) => {
        let ip = ppem.to_int()
        if ip.to_double() == ppem && ip >= 0 && ip <= 255 {
          hdmx = hint_hdmx_width(font, ip, gid)
        }
      }
    }
  }
  let advance0 = match hdmx {
    Some(w) => w.to_double()
    None => tt_bits_to_double(phantom1.x - phantom0.x)
  }
  let advance = advance0.round()
  let lsb = tt_bits_to_double(phantom0.x)
  let metrics = AdjustedMetrics::{
    has_overlaps: glyph.has_overlaps().unwrap_or(false),
    lsb: Some(lsb),
    advance_width: Some(advance),
  }
  Ok((metrics, tt_zone_to_path_freetype(zone)))
}
