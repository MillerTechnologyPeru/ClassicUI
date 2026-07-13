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

    /// SDL could not be initialized; contains the SDL error message.
    case sdlError(String)

    /// None of the theme's font candidates could be resolved by FontConfig.
    case fontNotFound([String])

    /// The drawing surface could not be created.
    case surfaceCreationFailed
}

internal final class ClassicRenderer {

    let theme: Theme
    let surface: Cairo.Surface.Image
    let context: Silica.CGContext
    let font: Silica.CGFont

    init(theme: Theme) throws {
        self.theme = theme
        do {
            self.surface = try Cairo.Surface.Image(
                format: .argb32,
                width: theme.screenWidth,
                height: theme.screenHeight
            )
            self.context = try Silica.CGContext(
                surface: surface,
                size: CGSize(width: theme.screenWidth, height: theme.screenHeight)
            )
        } catch {
            throw ClassicUIError.surfaceCreationFailed
        }
        guard let font = theme.fontNames.lazy.compactMap({ Silica.CGFont(name: $0) }).first else {
            throw ClassicUIError.fontNotFound(theme.fontNames)
        }
        self.font = font
    }

    // MARK: - Frame

    func render(screen: ResolvedScreen, selection: Int, scrollOffset: Int, isPlaying: Bool) {
        let width = CGFloat(theme.screenWidth)
        let height = CGFloat(theme.screenHeight)

        fill(CGRect(x: 0, y: 0, width: width, height: height), color: theme.background)

        drawStatusBar(title: screen.title, isPlaying: isPlaying)

        let showsScrollBar = screen.rows.count > theme.visibleRows
        let scrollBarWidth: CGFloat = showsScrollBar ? 8 : 0
        let rowWidth = width - scrollBarWidth

        let visibleRange = scrollOffset ..< min(screen.rows.count, scrollOffset + theme.visibleRows)
        for index in visibleRange {
            let y = theme.statusBarHeight + Double(index - scrollOffset) * theme.rowHeight
            drawRow(
                screen.rows[index],
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
                rowCount: screen.rows.count,
                scrollOffset: scrollOffset
            )
        }
    }

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
        let width = CGFloat(theme.screenWidth)
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

    private func drawScrollBar(in rect: CGRect, rowCount: Int, scrollOffset: Int) {
        fill(rect, color: theme.scrollBarTrack)
        fill(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height), color: theme.statusBarSeparator)

        let visible = theme.visibleRows
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
        let steps = max(1, Int(rect.height))
        for step in 0 ..< steps {
            let fraction = steps > 1 ? Double(step) / Double(steps - 1) : 0
            let color = Theme.Color(
                red: top.red + (bottom.red - top.red) * fraction,
                green: top.green + (bottom.green - top.green) * fraction,
                blue: top.blue + (bottom.blue - top.blue) * fraction
            )
            fill(CGRect(x: rect.minX, y: rect.minY + CGFloat(step), width: rect.width, height: 1), color: color)
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
