//
//  VStack.swift
//  ClassicUICore
//

import Foundation

/// An alignment position along the horizontal axis.
public struct HorizontalAlignment: Equatable, Sendable {

    internal enum ID: Equatable, Sendable {
        case leading
        case center
        case trailing
    }

    internal let id: ID

    /// A guide that marks the leading edge of the view.
    public static let leading = HorizontalAlignment(id: .leading)

    /// A guide that marks the horizontal center of the view.
    public static let center = HorizontalAlignment(id: .center)

    /// A guide that marks the trailing edge of the view.
    public static let trailing = HorizontalAlignment(id: .trailing)
}

/// A view that arranges its subviews in a vertical line.
///
/// Pushed as a screen, a `VStack` renders as non-interactive stacked
/// content — no selection bar — which is how player screens like
/// Now Playing are built. Inside a `List` it flattens into rows.
public struct VStack<Content: View>: View {

    internal let alignment: HorizontalAlignment
    internal let spacing: CGFloat?
    internal let content: Content

    /// Creates an instance with the given alignment and spacing.
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}
