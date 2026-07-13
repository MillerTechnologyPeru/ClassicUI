//---------------------------------------------------------------------------------
//
//  Renderer.swift -- software rasterizer for the iPod Classic screen.
//
//  Draws the classic look (glossy status bar, menu rows, blue selection
//  gradient, chevrons, scrollbar, Notes text pages, Now Playing stacks)
//  into a 16bpp RGB565 row-major canvas; Main.swift hands the canvas to
//  ctru_present_bottom, which transposes it into the bottom LCD's
//  column-major hardware framebuffer (see common/shim.c).
//
//  The 3DS bottom screen is 320x240 -- exactly the real iPod Classic LCD.
//
//  Deliberately imports nothing (no CTRU): the same file compiles on the
//  host for snapshot verification (tools/host_preview).
//
//---------------------------------------------------------------------------------

// MARK: - Canvas

struct Canvas {
  var pixels: UnsafeMutablePointer<UInt16>
  var width: Int32
  var height: Int32

  @inline(__always)
  func set(_ x: Int32, _ y: Int32, _ color: UInt16) {
    guard x >= 0, x < width, y >= 0, y < height else { return }
    pixels[Int(y &* width &+ x)] = color
  }
}

// MARK: - Colors (RGB565)

@inline(__always)
func rgb565(_ r: Int32, _ g: Int32, _ b: Int32) -> UInt16 {
  let r5 = UInt16((r &* 31) / 255) & 0x1F
  let g6 = UInt16((g &* 63) / 255) & 0x3F
  let b5 = UInt16((b &* 31) / 255) & 0x1F
  return (r5 << 11) | (g6 << 5) | b5
}

/// Linear interpolation between two 0...255 RGB triples at t/64.
@inline(__always)
func lerpColor(_ a: (Int32, Int32, Int32), _ b: (Int32, Int32, Int32), _ t: Int32) -> UInt16 {
  rgb565(
    a.0 &+ ((b.0 &- a.0) &* t) / 64,
    a.1 &+ ((b.1 &- a.1) &* t) / 64,
    a.2 &+ ((b.2 &- a.2) &* t) / 64)
}

// Theme colors, converted from ClassicUICore/Theme.swift's classic look.
let colorBackground = rgb565(255, 255, 255)
let colorText = rgb565(0, 0, 0)
let colorSelectedText = rgb565(255, 255, 255)
let colorSeparator = rgb565(115, 115, 120)
let colorDetailText = rgb565(115, 115, 120)
let colorScrollTrack = rgb565(217, 217, 222)
let colorScrollThumb = rgb565(115, 115, 128)
let colorBatteryGreen = rgb565(89, 199, 71)
let statusGradientTop: (Int32, Int32, Int32) = (250, 250, 250)
let statusGradientBottom: (Int32, Int32, Int32) = (191, 191, 196)
let selectionGradientTop: (Int32, Int32, Int32) = (107, 173, 242)
let selectionGradientBottom: (Int32, Int32, Int32) = (13, 89, 217)

// Metrics (ClassicUICore/Theme.swift).
let statusBarHeight: Int32 = 20
let rowHeight: Int32 = 24
let textLineHeight: Int32 = 17
let horizontalPadding: Int32 = 6
let iPodWidth: Int32 = 320
let iPodHeight: Int32 = 240
let visibleRows: Int32 = (iPodHeight - statusBarHeight) / rowHeight
let visibleTextLines: Int32 = (iPodHeight - statusBarHeight - 2) / textLineHeight

// MARK: - Primitives

func fillRect(_ canvas: Canvas, x: Int32, y: Int32, width: Int32, height: Int32, color: UInt16) {
  let x0 = max(0, x), y0 = max(0, y)
  let x1 = min(canvas.width, x &+ width), y1 = min(canvas.height, y &+ height)
  guard x0 < x1, y0 < y1 else { return }
  var dy = y0
  while dy < y1 {
    let row = canvas.pixels + Int(dy &* canvas.width)
    var dx = x0
    while dx < x1 {
      row[Int(dx)] = color
      dx &+= 1
    }
    dy &+= 1
  }
}

/// Vertical gradient with the classic glossy top half (lightened toward
/// white), one band per scanline.
func fillVerticalGradient(
  _ canvas: Canvas, x: Int32, y: Int32, width: Int32, height: Int32,
  top: (Int32, Int32, Int32), bottom: (Int32, Int32, Int32), gloss: Bool
) {
  guard height > 0 else { return }
  var row: Int32 = 0
  while row < height {
    let t = height > 1 ? (row &* 64) / (height &- 1) : 0
    var r = top.0 &+ ((bottom.0 &- top.0) &* t) / 64
    var g = top.1 &+ ((bottom.1 &- top.1) &* t) / 64
    var b = top.2 &+ ((bottom.2 &- top.2) &* t) / 64
    if gloss, row < height / 2 {
      // ~20% toward white, like the desktop renderer's gloss overlay
      r = r &+ (255 &- r) / 5
      g = g &+ (255 &- g) / 5
      b = b &+ (255 &- b) / 5
    }
    fillRect(canvas, x: x, y: y &+ row, width: width, height: 1, color: rgb565(r, g, b))
    row &+= 1
  }
}

// MARK: - Text (see tools/gen_font.py)

/// Draws one run of ASCII bytes; returns the x after the last glyph.
@discardableResult
func drawBytes(
  _ canvas: Canvas, _ bytes: UnsafePointer<UInt8>, _ count: Int32,
  x: Int32, y: Int32, color: UInt16, maxX: Int32 = Int32.max
) -> Int32 {
  var penX = x
  var i: Int32 = 0
  while i < count {
    var code = Int32(bytes[Int(i)])
    if code < fontFirstCode || code > fontLastCode { code = 63 }  // '?'
    let glyph = Int(code - fontFirstCode)
    let width = fontGlyphWidths[glyph]
    if penX &+ width > maxX { break }
    let rowBase = glyph * Int(fontGlyphHeight)
    var gy: Int32 = 0
    while gy < fontGlyphHeight {
      let bits = fontGlyphRows[rowBase + Int(gy)]
      var gx: Int32 = 0
      while gx < width {
        if bits & (1 << UInt16(gx)) != 0 {
          canvas.set(penX &+ gx, y &+ gy, color)
        }
        gx &+= 1
      }
      gy &+= 1
    }
    penX &+= width
    i &+= 1
  }
  return penX
}

@discardableResult
func drawText(
  _ canvas: Canvas, _ text: StaticString, x: Int32, y: Int32, color: UInt16,
  maxX: Int32 = Int32.max
) -> Int32 {
  text.withUTF8Buffer { buffer in
    guard let base = buffer.baseAddress else { return x }
    return drawBytes(canvas, base, Int32(buffer.count), x: x, y: y, color: color, maxX: maxX)
  }
}

func measureBytes(_ bytes: UnsafePointer<UInt8>, _ count: Int32) -> Int32 {
  var width: Int32 = 0
  var i: Int32 = 0
  while i < count {
    var code = Int32(bytes[Int(i)])
    if code < fontFirstCode || code > fontLastCode { code = 63 }
    width &+= fontGlyphWidths[Int(code - fontFirstCode)]
    i &+= 1
  }
  return width
}

func measure(_ text: StaticString) -> Int32 {
  text.withUTF8Buffer { buffer in
    guard let base = buffer.baseAddress else { return 0 }
    return measureBytes(base, Int32(buffer.count))
  }
}

/// Draws a decimal integer; returns the x after the last digit.
@discardableResult
func drawInt(_ canvas: Canvas, _ value: Int32, x: Int32, y: Int32, color: UInt16) -> Int32 {
  var digits = [UInt8]()
  var v = value
  if v < 0 {
    digits.append(45)  // '-'
    v = -v
  }
  var stack = [UInt8]()
  repeat {
    stack.append(UInt8(48 &+ v % 10))
    v /= 10
  } while v > 0
  while let d = stack.popLast() {
    digits.append(d)
  }
  return digits.withUnsafeBufferPointer { buffer in
    drawBytes(canvas, buffer.baseAddress!, Int32(buffer.count), x: x, y: y, color: color)
  }
}

/// Advance width of a decimal integer.
func intWidth(_ value: Int32) -> Int32 {
  var width: Int32 = 0
  var v = value
  if v < 0 {
    width &+= fontGlyphWidths[Int(45 - fontFirstCode)]
    v = -v
  }
  repeat {
    width &+= fontGlyphWidths[Int(48 &+ v % 10 - fontFirstCode)]
    v /= 10
  } while v > 0
  return width
}

/// Text y that vertically centers the glyph box in a row of `height` at `y`.
@inline(__always)
func textTop(rowY: Int32, rowHeight height: Int32) -> Int32 {
  rowY &+ (height &- fontGlyphHeight) / 2 &+ 1
}

// MARK: - Chrome

func drawStatusBar(_ canvas: Canvas, title: StaticString, playing: Bool) {
  fillVerticalGradient(
    canvas, x: 0, y: 0, width: canvas.width, height: statusBarHeight,
    top: statusGradientTop, bottom: statusGradientBottom, gloss: true)
  fillRect(canvas, x: 0, y: statusBarHeight - 1, width: canvas.width, height: 1, color: colorSeparator)

  let titleWidth = measure(title)
  drawText(
    canvas, title, x: (canvas.width - titleWidth) / 2,
    y: textTop(rowY: 0, rowHeight: statusBarHeight), color: colorText)

  // battery
  let batteryRight = canvas.width - 4
  fillRect(canvas, x: batteryRight - 17, y: 5, width: 17, height: 9, color: colorSeparator)
  fillRect(canvas, x: batteryRight - 19, y: 8, width: 2, height: 4, color: colorSeparator)
  fillRect(canvas, x: batteryRight - 16, y: 6, width: 15, height: 7, color: colorBatteryGreen)

  if playing {
    // play triangle
    var i: Int32 = 0
    while i < 4 {
      fillRect(canvas, x: 6 &+ i, y: 6 &+ i, width: 2, height: 9 &- i &* 2, color: colorSeparator)
      i &+= 1
    }
  }
}

func drawChevron(_ canvas: Canvas, right: Int32, centerY: Int32, color: UInt16) {
  var i: Int32 = 0
  while i < 5 {
    canvas.set(right - 5 &+ i, centerY - 4 &+ i, color)
    canvas.set(right - 6 &+ i, centerY - 4 &+ i, color)
    canvas.set(right - 5 &+ i, centerY + 4 &- i, color)
    canvas.set(right - 6 &+ i, centerY + 4 &- i, color)
    i &+= 1
  }
}

func drawScrollBar(
  _ canvas: Canvas, rowCount: Int32, visibleCount: Int32, scrollOffset: Int32
) {
  let x = canvas.width - 8
  let trackY = statusBarHeight
  let trackHeight = canvas.height - statusBarHeight
  fillRect(canvas, x: x, y: trackY, width: 8, height: trackHeight, color: colorScrollTrack)
  fillRect(canvas, x: x, y: trackY, width: 1, height: trackHeight, color: colorSeparator)
  guard rowCount > visibleCount else { return }
  let usable = trackHeight - 4
  var thumbHeight = (usable &* visibleCount) / rowCount
  if thumbHeight < 8 { thumbHeight = 8 }
  let maxOffset = rowCount - visibleCount
  let thumbY = trackY &+ 2 &+ ((usable &- thumbHeight) &* scrollOffset) / maxOffset
  fillRect(canvas, x: x + 2, y: thumbY, width: 4, height: thumbHeight, color: colorScrollThumb)
}

func drawProgressBar(_ canvas: Canvas, y: Int32, permille: Int32) {
  let x = horizontalPadding
  let width = canvas.width - horizontalPadding &* 2
  let barY = y &+ (rowHeight - 9) / 2
  fillRect(canvas, x: x, y: barY, width: width, height: 9, color: colorSeparator)
  fillRect(canvas, x: x + 1, y: barY + 1, width: width - 2, height: 7, color: colorBackground)
  var clamped = permille
  if clamped < 0 { clamped = 0 }
  if clamped > 1000 { clamped = 1000 }
  let filled = ((width - 2) &* clamped) / 1000
  if filled > 0 {
    fillVerticalGradient(
      canvas, x: x + 1, y: barY + 1, width: filled, height: 7,
      top: selectionGradientTop, bottom: selectionGradientBottom, gloss: true)
  }
}

// MARK: - Screen rendering

func renderScreen(_ canvas: Canvas, screen: Screen, playing: Bool) {
  fillRect(canvas, x: 0, y: 0, width: canvas.width, height: canvas.height, color: colorBackground)
  drawStatusBar(canvas, title: screen.title, playing: playing)

  switch screen.content {
  case .menu(let items):
    renderMenu(canvas, screen: screen, items: items)
  case .text(let text):
    renderTextPage(canvas, text: text, topLine: screen.selection)
  case .stack(let lines):
    renderStack(canvas, lines: lines)
  }
}

private func renderMenu(_ canvas: Canvas, screen: Screen, items: [MenuItem]) {
  let count = Int32(items.count)
  let showsScrollBar = count > visibleRows
  let rowWidth = showsScrollBar ? canvas.width - 8 : canvas.width

  var slot: Int32 = 0
  while slot < visibleRows, screen.scrollOffset &+ slot < count {
    let index = screen.scrollOffset &+ slot
    let item = items[Int(index)]
    let y = statusBarHeight &+ slot &* rowHeight
    let selected = index == screen.selection

    if selected {
      fillVerticalGradient(
        canvas, x: 0, y: y, width: rowWidth, height: rowHeight,
        top: selectionGradientTop, bottom: selectionGradientBottom, gloss: true)
    }

    let textColor = selected ? colorSelectedText : colorText
    let textY = textTop(rowY: y, rowHeight: rowHeight)
    var maxX = rowWidth - horizontalPadding
    if item.isNavigation { maxX -= 14 }

    if let detail = item.detail {
      let value = detail()
      let valueWidth = measure(value)
      drawText(
        canvas, value, x: maxX - valueWidth, y: textY,
        color: selected ? colorSelectedText : colorDetailText)
      maxX -= valueWidth &+ 8
    }

    let afterTitle = drawText(
      canvas, item.title, x: horizontalPadding, y: textY, color: textColor, maxX: maxX)
    if let number = item.numberSuffix, afterTitle < maxX {
      drawInt(canvas, number, x: afterTitle, y: textY, color: textColor)
    }

    if item.isNavigation {
      drawChevron(canvas, right: rowWidth - horizontalPadding, centerY: y &+ rowHeight / 2, color: textColor)
    }
    slot &+= 1
  }

  if showsScrollBar {
    drawScrollBar(canvas, rowCount: count, visibleCount: visibleRows, scrollOffset: screen.scrollOffset)
  }
}

private func renderStack(_ canvas: Canvas, lines: [StackLine]) {
  var y = statusBarHeight &+ 8
  for line in lines {
    switch line.content {
    case .text(let text):
      let value = text()
      let width = measure(value)
      drawText(
        canvas, value, x: (canvas.width - width) / 2,
        y: textTop(rowY: y, rowHeight: rowHeight), color: colorText)
    case .trackOf(let position):
      let (number, count) = position()
      let of: StaticString = " of "
      let width =
        intWidth(number) &+ measure(of) &+ intWidth(count)
      let textY = textTop(rowY: y, rowHeight: rowHeight)
      var x = (canvas.width - width) / 2
      x = drawInt(canvas, number, x: x, y: textY, color: colorText)
      x = drawText(canvas, of, x: x, y: textY, color: colorText)
      _ = drawInt(canvas, count, x: x, y: textY, color: colorText)
    case .progress(let permille):
      drawProgressBar(canvas, y: y, permille: permille())
    case .times(let times):
      let (elapsed, remaining) = times()
      let textY = textTop(rowY: y, rowHeight: rowHeight)
      drawTimestamp(canvas, seconds: elapsed, x: horizontalPadding, y: textY, negative: false)
      // right-aligned "-m:ss": measure digits first
      let width = timestampWidth(seconds: remaining, negative: true)
      drawTimestamp(
        canvas, seconds: remaining, x: canvas.width - horizontalPadding - width, y: textY,
        negative: true)
    }
    y &+= rowHeight
  }
}

private func timestampDigits(seconds: Int32, negative: Bool) -> [UInt8] {
  var bytes = [UInt8]()
  if negative { bytes.append(45) }  // '-'
  let total = seconds < 0 ? 0 : seconds
  var minutes = total / 60
  let secs = total % 60
  var minuteStack = [UInt8]()
  repeat {
    minuteStack.append(UInt8(48 &+ minutes % 10))
    minutes /= 10
  } while minutes > 0
  while let d = minuteStack.popLast() { bytes.append(d) }
  bytes.append(58)  // ':'
  bytes.append(UInt8(48 &+ secs / 10))
  bytes.append(UInt8(48 &+ secs % 10))
  return bytes
}

func timestampWidth(seconds: Int32, negative: Bool) -> Int32 {
  let bytes = timestampDigits(seconds: seconds, negative: negative)
  return bytes.withUnsafeBufferPointer { measureBytes($0.baseAddress!, Int32($0.count)) }
}

func drawTimestamp(_ canvas: Canvas, seconds: Int32, x: Int32, y: Int32, negative: Bool) {
  let bytes = timestampDigits(seconds: seconds, negative: negative)
  bytes.withUnsafeBufferPointer {
    _ = drawBytes(canvas, $0.baseAddress!, Int32($0.count), x: x, y: y, color: colorText)
  }
}

// MARK: - Text pages (Notes)

/// Word-wraps `text` and draws the page from `topLine`; returns the wrapped
/// line count (for scroll clamping in Main.swift).
@discardableResult
func renderTextPage(_ canvas: Canvas, text: StaticString, topLine: Int32) -> Int32 {
  let maxWidth = canvas.width - horizontalPadding &* 2 - 8
  return text.withUTF8Buffer { buffer -> Int32 in
    guard let base = buffer.baseAddress else { return 0 }
    let count = Int32(buffer.count)

    // wrap into (start, length) runs
    var lineStarts = [Int32]()
    var lineLengths = [Int32]()
    var lineStart: Int32 = 0
    var lastSpace: Int32 = -1
    var lineWidth: Int32 = 0
    var i: Int32 = 0
    while i < count {
      let byte = base[Int(i)]
      if byte == 10 {  // newline
        lineStarts.append(lineStart)
        lineLengths.append(i - lineStart)
        lineStart = i + 1
        lastSpace = -1
        lineWidth = 0
        i &+= 1
        continue
      }
      var code = Int32(byte)
      if code < fontFirstCode || code > fontLastCode { code = 63 }
      let glyphWidth = fontGlyphWidths[Int(code - fontFirstCode)]
      if lineWidth &+ glyphWidth > maxWidth, lastSpace > lineStart {
        // break at the last space
        lineStarts.append(lineStart)
        lineLengths.append(lastSpace - lineStart)
        lineStart = lastSpace + 1
        lineWidth = measureBytes(base + Int(lineStart), i - lineStart)
        lastSpace = -1
      }
      if byte == 32 { lastSpace = i }
      lineWidth &+= glyphWidth
      i &+= 1
    }
    if lineStart <= count {
      lineStarts.append(lineStart)
      lineLengths.append(count - lineStart)
    }

    let lineCount = Int32(lineStarts.count)
    var slot: Int32 = 0
    while slot < visibleTextLines, topLine &+ slot < lineCount {
      let line = Int(topLine &+ slot)
      let y = statusBarHeight &+ 2 &+ slot &* textLineHeight
      _ = drawBytes(
        canvas, base + Int(lineStarts[line]), lineLengths[line],
        x: horizontalPadding, y: textTop(rowY: y, rowHeight: textLineHeight), color: colorText)
      slot &+= 1
    }

    if lineCount > visibleTextLines {
      drawScrollBar(
        canvas, rowCount: lineCount, visibleCount: visibleTextLines, scrollOffset: topLine)
    }
    return lineCount
  }
}

/// Wrapped line count without drawing (scroll clamping).
func textPageLineCount(_ text: StaticString) -> Int32 {
  // render into a 0x0 canvas: all set() calls clip, wrap math still runs
  var dummy: UInt16 = 0
  return withUnsafeMutablePointer(to: &dummy) { pointer in
    renderTextPage(Canvas(pixels: pointer, width: 0, height: 0), text: text, topLine: 0)
  }
}

// MARK: - Navigation slide (ClassicUICore/ClassicScreen.swift's composite)

/// Composites `outgoing` and `incoming` side by side at eased progress
/// `p64` (0...64) into `present`. Push slides in from the right, pop from
/// the left; the status bar stays pinned to the incoming screen.
func compositeSlide(
  present: UnsafeMutablePointer<UInt16>,
  outgoing: UnsafePointer<UInt16>,
  incoming: UnsafePointer<UInt16>,
  width: Int32, height: Int32, p64: Int32, push: Bool
) {
  // ease-out: 64 - (64-p)^2/64
  let inverted = 64 - p64
  let eased = 64 - (inverted &* inverted) / 64
  var offset = (width &* eased) / 64
  if offset < 0 { offset = 0 }
  if offset > width { offset = width }

  var y: Int32 = 0
  while y < height {
    let rowStart = Int(y &* width)
    if y < statusBarHeight {
      // pinned status bar, always the incoming screen's
      var x = 0
      while x < Int(width) {
        present[rowStart + x] = incoming[rowStart + x]
        x += 1
      }
    } else if push {
      // outgoing slides left, incoming enters from the right
      var x: Int32 = 0
      while x < width {
        let source = x &+ offset
        present[rowStart + Int(x)] =
          source < width
          ? outgoing[rowStart + Int(source)]
          : incoming[rowStart + Int(source &- width)]
        x &+= 1
      }
    } else {
      // incoming enters from the left, outgoing slides right
      var x: Int32 = 0
      while x < width {
        present[rowStart + Int(x)] =
          x < offset
          ? incoming[rowStart + Int(width &- offset &+ x)]
          : outgoing[rowStart + Int(x &- offset)]
        x &+= 1
      }
    }
    y &+= 1
  }
}
