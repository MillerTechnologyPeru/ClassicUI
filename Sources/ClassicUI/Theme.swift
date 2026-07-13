//
//  Theme.swift
//  ClassicUI
//

/// Visual configuration of the iPod screen.
///
/// The default theme reproduces the 6th-generation iPod Classic look:
/// 320×240 screen, glossy gray status bar, blue gradient selection.
public struct Theme: Sendable {

    /// An RGB color (components in 0...1).
    public struct Color: Hashable, Sendable {

        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        public static let white = Color(red: 1, green: 1, blue: 1)
        public static let black = Color(red: 0, green: 0, blue: 0)
    }

    // MARK: Screen

    /// Logical screen size in pixels (the real device is 320×240).
    public var screenWidth: Int = 320
    public var screenHeight: Int = 240

    // MARK: Metrics

    public var statusBarHeight: Double = 20
    public var rowHeight: Double = 24
    public var fontSize: Double = 13
    public var horizontalPadding: Double = 6

    /// Number of fully visible menu rows.
    public var visibleRows: Int {
        Int((Double(screenHeight) - statusBarHeight) / rowHeight)
    }

    // MARK: Colors

    public var background: Color = .white
    public var text: Color = .black
    public var selectedText: Color = .white

    /// Selection bar vertical gradient (6g glossy blue).
    public var selectionGradientTop = Color(red: 0.42, green: 0.68, blue: 0.95)
    public var selectionGradientBottom = Color(red: 0.05, green: 0.35, blue: 0.85)

    /// Status bar vertical gradient (glossy gray).
    public var statusBarGradientTop = Color(red: 0.98, green: 0.98, blue: 0.98)
    public var statusBarGradientBottom = Color(red: 0.75, green: 0.75, blue: 0.77)
    public var statusBarText: Color = .black
    public var statusBarSeparator = Color(red: 0.45, green: 0.45, blue: 0.47)

    public var scrollBarTrack = Color(red: 0.85, green: 0.85, blue: 0.87)
    public var scrollBarThumb = Color(red: 0.45, green: 0.45, blue: 0.5)

    // MARK: Fonts

    /// Font family candidates, tried in order against FontConfig.
    public var fontNames: [String] = ["Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans", "Liberation Sans"]

    /// The classic 6th-generation color look.
    public static let classic = Theme()

    public init() { }
}
