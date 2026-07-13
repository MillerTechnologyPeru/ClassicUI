//
//  ClassicRenderer.swift
//  ClassicUI
//
//  Draws the iPod Classic screen (status bar, menu rows, selection
//  gradient, scrollbar) into a Cairo ARGB32 surface via Silica.
//

import Foundation
import Cairo
import Silica

/// Errors thrown by ClassicUI.
public enum ClassicUIError: Error {

    /// None of the theme's font candidates could be resolved by FontConfig.
    case fontNotFound([String])

    /// The drawing surface could not be created.
    case surfaceCreationFailed
}

internal final class ClassicRenderer {

    let theme: Theme
    let font: Silica.CGFont

    /// Framebuffer size in device pixels. The theme's 320×240 is the
    /// minimum logical size: the scale is chosen so both dimensions fit,
    /// and the logical viewport extends to match the window's aspect
    /// ratio (wider windows get wider rows, taller windows more rows).
    /// All vector drawing — text in particular — renders crisply at
    /// native resolution, including Retina.
    private(set) var pixelWidth: Int
    private(set) var pixelHeight: Int

    /// Device pixels per logical point.
    private(set) var scale: CGFloat = 1

    /// Current logical viewport size (≥ the theme's screen size).
    private(set) var logicalWidth: CGFloat = 0
    private(set) var logicalHeight: CGFloat = 0

    /// Number of fully visible menu rows at the current logical height.
    var visibleRows: Int {
        max(1, Int((logicalHeight - theme.statusBarHeight) / theme.rowHeight))
    }

    private(set) var surface: Cairo.Surface.Image
    private(set) var context: Silica.CGContext

    /// FontConfig matching and Cairo font-face creation share global state
    /// that is not thread-safe; serialize renderer construction.
    private static let initializationLock = NSLock()

    init(theme: Theme, width: Int? = nil, height: Int? = nil) throws {
        Self.initializationLock.lock()
        defer { Self.initializationLock.unlock() }
        self.theme = theme
        let pixelWidth = max(1, width ?? theme.screenWidth)
        let pixelHeight = max(1, height ?? theme.screenHeight)
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        do {
            self.surface = try Cairo.Surface.Image(
                format: .argb32,
                width: pixelWidth,
                height: pixelHeight
            )
            self.context = try Silica.CGContext(
                surface: surface,
                size: CGSize(width: pixelWidth, height: pixelHeight)
            )
        } catch {
            throw ClassicUIError.surfaceCreationFailed
        }
        guard let font = theme.fontNames.lazy.compactMap({ Silica.CGFont(name: $0) }).first else {
            throw ClassicUIError.fontNotFound(theme.fontNames)
        }
        self.font = font
        applyTransform()
    }

    /// Recreates the framebuffer at a new pixel size (e.g. after a window
    /// resize or a display-scale change).
    func resize(width: Int, height: Int) throws {
        let width = max(1, width)
        let height = max(1, height)
        guard width != pixelWidth || height != pixelHeight else { return }
        Self.initializationLock.lock()
        defer { Self.initializationLock.unlock() }
        do {
            let newSurface = try Cairo.Surface.Image(format: .argb32, width: width, height: height)
            let newContext = try Silica.CGContext(
                surface: newSurface,
                size: CGSize(width: width, height: height)
            )
            surface = newSurface
            context = newContext
        } catch {
            throw ClassicUIError.surfaceCreationFailed
        }
        pixelWidth = width
        pixelHeight = height
        applyTransform()
    }

    /// Scales the logical coordinate system up to the pixel size; the
    /// logical viewport extends beyond 320×240 to match the window's
    /// aspect ratio.
    private func applyTransform() {
        scale = min(
            CGFloat(pixelWidth) / CGFloat(theme.screenWidth),
            CGFloat(pixelHeight) / CGFloat(theme.screenHeight)
        )
        if scale <= 0 { scale = 1 }
        logicalWidth = CGFloat(pixelWidth) / scale
        logicalHeight = CGFloat(pixelHeight) / scale
        context.scaleBy(x: scale, y: scale)
        // the page width changed, so cached text wrapping is stale
        wrapCache = nil
    }

    // MARK: - Frame

    func render(screen: ResolvedScreen, selection: Int, scrollOffset: Int, isPlaying: Bool) {
        fill(CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight), color: theme.background)

        drawStatusBar(title: screen.title, isPlaying: isPlaying)

        switch screen.content {
        case .menu(let rows):
            drawMenu(rows, selection: selection, scrollOffset: scrollOffset)
        case .text(let text):
            drawTextPage(text, topLine: selection)
        case .stack(let rows, let alignment, let spacing):
            drawStack(rows, alignment: alignment, spacing: spacing)
        }
    }

    /// Non-interactive stacked content (Now Playing-style screens):
    /// rows without a selection bar.
    private func drawStack(_ rows: [ResolvedRow], alignment: HorizontalAlignment, spacing: Double) {
        var y = theme.statusBarHeight + 8
        for row in rows {
            let rect = CGRect(x: 0, y: y, width: logicalWidth, height: theme.rowHeight)
            if let progress = row.progress {
                drawProgressBar(fraction: progress, in: rect)
            } else if let detail = row.detail, !detail.isEmpty {
                // HStack leading/trailing pair: text left, detail right
                let padding = CGFloat(theme.horizontalPadding)
                let detailWidth = font.singleLineWidth(text: detail, fontSize: theme.fontSize)
                drawText(
                    detail,
                    at: CGPoint(x: rect.maxX - padding - detailWidth, y: textTop(in: rect)),
                    color: theme.text
                )
                let text = truncated(row.text, width: rect.width - padding * 2 - detailWidth - 8)
                drawText(text, at: CGPoint(x: padding, y: textTop(in: rect)), color: theme.text)
            } else {
                let padding = CGFloat(theme.horizontalPadding)
                let text = truncated(row.text, width: rect.width - padding * 2)
                let textWidth = font.singleLineWidth(text: text, fontSize: theme.fontSize)
                let x: CGFloat
                switch alignment.id {
                case .leading: x = padding
                case .center: x = (rect.width - textWidth) / 2
                case .trailing: x = rect.maxX - padding - textWidth
                }
                drawText(text, at: CGPoint(x: x, y: textTop(in: rect)), color: theme.text)
            }
            y += theme.rowHeight + spacing
        }
    }

    private func drawMenu(_ rows: [ResolvedRow], selection: Int, scrollOffset: Int) {
        let width = logicalWidth
        let height = logicalHeight

        let showsScrollBar = rows.count > visibleRows
        let scrollBarWidth: CGFloat = showsScrollBar ? 8 : 0
        let rowWidth = width - scrollBarWidth

        let visibleRange = scrollOffset ..< min(rows.count, scrollOffset + visibleRows)
        for index in visibleRange {
            let y = theme.statusBarHeight + Double(index - scrollOffset) * theme.rowHeight
            drawRow(
                rows[index],
                in: CGRect(x: 0, y: y, width: rowWidth, height: theme.rowHeight),
                isSelected: index == selection
            )
        }

        if showsScrollBar {
            drawScrollBar(
                in: CGRect(
                    x: width - scrollBarWidth,
                    y: theme.statusBarHeight,
                    width: scrollBarWidth,
                    height: height - theme.statusBarHeight
                ),
                rowCount: rows.count,
                visibleCount: visibleRows,
                scrollOffset: scrollOffset
            )
        }
    }

    // MARK: - Text pages (Notes / ebook)

    /// Number of fully visible lines on a wrapped text screen.
    var visibleTextLines: Int {
        max(1, Int((logicalHeight - theme.statusBarHeight) / theme.textLineHeight))
    }

    /// Number of wrapped lines `text` produces at the page width.
    func lineCount(for text: String) -> Int {
        wrappedLines(for: text).count
    }

    private var wrapCache: (text: String, lines: [String])?

    /// Word-wraps text to the page width, honoring explicit newlines.
    /// The scrollbar gutter is always reserved so wrapping doesn't change
    /// with overflow.
    func wrappedLines(for text: String) -> [String] {
        if let wrapCache, wrapCache.text == text {
            return wrapCache.lines
        }
        let width = logicalWidth - CGFloat(theme.horizontalPadding) * 2 - 8
        var lines = [String]()
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard !paragraph.isEmpty else {
                lines.append("")
                continue
            }
            var current = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = current.isEmpty ? String(word) : current + " " + word
                if current.isEmpty
                    || font.singleLineWidth(text: candidate, fontSize: theme.fontSize) <= width {
                    current = candidate
                } else {
                    lines.append(current)
                    current = String(word)
                }
            }
            lines.append(current)
        }
        wrapCache = (text, lines)
        return lines
    }

    private func drawTextPage(_ text: String, topLine: Int) {
        let width = logicalWidth
        let height = logicalHeight
        let lines = wrappedLines(for: text)
        let visible = visibleTextLines
        let top = min(max(0, topLine), max(0, lines.count - visible))

        for (offset, line) in lines[top ..< min(lines.count, top + visible)].enumerated() {
            let y = theme.statusBarHeight + 2 + Double(offset) * theme.textLineHeight
            drawText(
                line,
                at: CGPoint(
                    x: CGFloat(theme.horizontalPadding),
                    y: textTop(in: CGRect(x: 0, y: y, width: width, height: theme.textLineHeight))
                ),
                color: theme.text
            )
        }

        if lines.count > visible {
            drawScrollBar(
                in: CGRect(
                    x: width - 8,
                    y: theme.statusBarHeight,
                    width: 8,
                    height: height - theme.statusBarHeight
                ),
                rowCount: lines.count,
                visibleCount: visible,
                scrollOffset: top
            )
        }
    }

    /// Bytes per framebuffer row.
    var stride: Int { surface.stride }

    /// Flushes pending drawing and exposes the raw ARGB32 pixels.
    func withPixels(_ body: (UnsafeMutablePointer<UInt8>, _ stride: Int) -> Void) {
        surface.flush()
        let stride = surface.stride
        surface.withUnsafeMutableBytes { pointer in
            body(pointer, stride)
        }
    }

    // MARK: - Status bar

    private func drawStatusBar(title: String?, isPlaying: Bool) {
        let width = logicalWidth
        let barHeight = theme.statusBarHeight
        let rect = CGRect(x: 0, y: 0, width: width, height: barHeight)

        fillVerticalGradient(rect, top: theme.statusBarGradientTop, bottom: theme.statusBarGradientBottom)
        // glossy highlight on the upper half
        fill(CGRect(x: 0, y: 0, width: width, height: barHeight / 2), color: .white, alpha: 0.35)
        // bottom separator
        fill(CGRect(x: 0, y: barHeight - 1, width: width, height: 1), color: theme.statusBarSeparator)

        if let title, !title.isEmpty {
            let text = truncated(title, width: width - 60)
            let textWidth = font.singleLineWidth(text: text, fontSize: theme.fontSize)
            drawText(
                text,
                at: CGPoint(x: (width - textWidth) / 2, y: textTop(in: rect)),
                color: theme.statusBarText
            )
        }

        drawBattery(right: width - 4, centerY: barHeight / 2)

        if isPlaying {
            drawPlayGlyph(at: CGPoint(x: 6, y: barHeight / 2))
        }
    }

    private func drawBattery(right: CGFloat, centerY: CGFloat) {
        let bodyWidth: CGFloat = 17
        let bodyHeight: CGFloat = 9
        let body = CGRect(
            x: right - bodyWidth,
            y: centerY - bodyHeight / 2,
            width: bodyWidth,
            height: bodyHeight
        )
        // outline
        fill(body, color: theme.statusBarSeparator)
        // nub
        fill(CGRect(x: body.minX - 2, y: centerY - 2, width: 2, height: 4), color: theme.statusBarSeparator)
        // charge fill
        fill(body.insetBy(dx: 1, dy: 1), color: Theme.Color(red: 0.35, green: 0.78, blue: 0.28))
    }

    private func drawPlayGlyph(at point: CGPoint) {
        setFillColor(theme.statusBarSeparator)
        context.beginPath()
        context.move(to: CGPoint(x: point.x, y: point.y - 4))
        context.addLine(to: CGPoint(x: point.x + 7, y: point.y))
        context.addLine(to: CGPoint(x: point.x, y: point.y + 4))
        context.closePath()
        context.fillPath()
    }

    // MARK: - Rows

    private func drawRow(_ row: ResolvedRow, in rect: CGRect, isSelected: Bool) {
        if isSelected {
            fillVerticalGradient(rect, top: theme.selectionGradientTop, bottom: theme.selectionGradientBottom)
            // glossy highlight on the upper half
            fill(
                CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2),
                color: .white,
                alpha: 0.2
            )
        }

        // a ProgressView row renders as the Now Playing progress bar
        if let progress = row.progress {
            drawProgressBar(fraction: progress, in: rect)
            return
        }

        let textColor = isSelected ? theme.selectedText : theme.text
        let chevronSpace: CGFloat = row.isNavigation ? 14 : 0
        var maxTextWidth = rect.width - CGFloat(theme.horizontalPadding) * 2 - chevronSpace

        // right-aligned value text (e.g. a Toggle's "On"/"Off")
        if let detail = row.detail, !detail.isEmpty {
            let detailWidth = font.singleLineWidth(text: detail, fontSize: theme.fontSize)
            let detailX = rect.maxX - CGFloat(theme.horizontalPadding) - chevronSpace - detailWidth
            drawText(
                detail,
                at: CGPoint(x: detailX, y: textTop(in: rect)),
                color: isSelected ? theme.selectedText : theme.detailText
            )
            maxTextWidth -= detailWidth + 8
        }

        let text = truncated(row.text, width: maxTextWidth)
        drawText(
            text,
            at: CGPoint(x: CGFloat(theme.horizontalPadding), y: textTop(in: rect)),
            color: textColor
        )

        if row.isNavigation {
            drawChevron(right: rect.maxX - CGFloat(theme.horizontalPadding), centerY: rect.midY, color: textColor)
        }
    }

    /// The classic Now Playing progress bar: outlined track with a blue
    /// gradient fill.
    private func drawProgressBar(fraction: Double, in rect: CGRect) {
        let barHeight: CGFloat = 9
        let bar = CGRect(
            x: rect.minX + CGFloat(theme.horizontalPadding),
            y: rect.midY - barHeight / 2,
            width: rect.width - CGFloat(theme.horizontalPadding) * 2,
            height: barHeight
        )
        // border + empty track
        fill(bar, color: theme.statusBarSeparator)
        fill(bar.insetBy(dx: 1, dy: 1), color: theme.background)
        // filled portion
        let clamped = min(max(fraction, 0), 1)
        let inner = bar.insetBy(dx: 1, dy: 1)
        let filled = CGRect(x: inner.minX, y: inner.minY, width: inner.width * CGFloat(clamped), height: inner.height)
        if filled.width >= 1 {
            fillVerticalGradient(filled, top: theme.selectionGradientTop, bottom: theme.selectionGradientBottom)
            fill(
                CGRect(x: filled.minX, y: filled.minY, width: filled.width, height: filled.height / 2),
                color: .white,
                alpha: 0.25
            )
        }
    }

    private func drawChevron(right: CGFloat, centerY: CGFloat, color: Theme.Color) {
        setStrokeColor(color)
        context.lineWidth = 1.8
        context.lineCap = .round
        context.lineJoin = .round
        context.beginPath()
        context.move(to: CGPoint(x: right - 4.5, y: centerY - 4))
        context.addLine(to: CGPoint(x: right, y: centerY))
        context.addLine(to: CGPoint(x: right - 4.5, y: centerY + 4))
        context.strokePath()
    }

    // MARK: - Scroll bar

    private func drawScrollBar(in rect: CGRect, rowCount: Int, visibleCount: Int, scrollOffset: Int) {
        fill(rect, color: theme.scrollBarTrack)
        fill(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height), color: theme.statusBarSeparator)

        let visible = visibleCount
        guard rowCount > visible else { return }
        let trackHeight = rect.height - 4
        let thumbHeight = max(8, trackHeight * CGFloat(visible) / CGFloat(rowCount))
        let maxOffset = CGFloat(rowCount - visible)
        let progress = maxOffset > 0 ? CGFloat(scrollOffset) / maxOffset : 0
        let thumbY = rect.minY + 2 + progress * (trackHeight - thumbHeight)
        fill(
            CGRect(x: rect.minX + 2, y: thumbY, width: rect.width - 4, height: thumbHeight),
            color: theme.scrollBarThumb
        )
    }

    // MARK: - Primitives

    private func setFillColor(_ color: Theme.Color, alpha: CGFloat = 1) {
        context.fillColor = Silica.CGColor(
            red: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: alpha
        )
    }

    private func setStrokeColor(_ color: Theme.Color) {
        context.strokeColor = Silica.CGColor(
            red: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: 1
        )
    }

    private func fill(_ rect: CGRect, color: Theme.Color, alpha: CGFloat = 1) {
        setFillColor(color, alpha: alpha)
        context.beginPath()
        context.addRect(rect)
        context.fillPath()
    }

    private func fillVerticalGradient(_ rect: CGRect, top: Theme.Color, bottom: Theme.Color) {
        // one band per device pixel row so gradients stay smooth when the
        // logical coordinate system is scaled up
        let steps = max(1, Int(rect.height * scale))
        let bandHeight = rect.height / CGFloat(steps)
        for step in 0 ..< steps {
            let fraction = steps > 1 ? Double(step) / Double(steps - 1) : 0
            let color = Theme.Color(
                red: top.red + (bottom.red - top.red) * fraction,
                green: top.green + (bottom.green - top.green) * fraction,
                blue: top.blue + (bottom.blue - top.blue) * fraction
            )
            fill(
                CGRect(x: rect.minX, y: rect.minY + CGFloat(step) * bandHeight, width: rect.width, height: bandHeight),
                color: color
            )
        }
    }

    /// Text origin y that vertically centers a line of text in `rect`.
    ///
    /// Silica's `textPosition` is the top of the line (it offsets by the
    /// font ascender internally), so this returns line-top, not a baseline:
    /// baseline ≈ top + 0.95·size, cap height ≈ 0.72·size, so the visual
    /// center of capital letters sits ≈ 0.59·size below line-top.
    private func textTop(in rect: CGRect) -> CGFloat {
        rect.midY - CGFloat(theme.fontSize) * 0.59
    }

    private func drawText(_ text: String, at point: CGPoint, color: Theme.Color) {
        guard !text.isEmpty else { return }
        setFillColor(color)
        context.setFont(font)
        context.fontSize = CGFloat(theme.fontSize)
        context.textPosition = point
        context.show(text: text)
    }

    private func truncated(_ text: String, width: CGFloat) -> String {
        guard width > 0 else { return "" }
        guard font.singleLineWidth(text: text, fontSize: theme.fontSize) > width else { return text }
        var result = text
        while !result.isEmpty,
              font.singleLineWidth(text: result + "…", fontSize: theme.fontSize) > width {
            result.removeLast()
        }
        return result.isEmpty ? "" : result + "…"
    }
}
