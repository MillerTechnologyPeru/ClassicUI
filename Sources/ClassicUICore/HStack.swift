//
//  HStack.swift
//  ClassicUICore
//

import Foundation

/// An alignment position along the vertical axis.
public struct VerticalAlignment: Equatable, Sendable {

    internal enum ID: Equatable, Sendable {
        case top
        case center
        case bottom
    }

    internal let id: ID

    /// A guide that marks the top edge of the view.
    public static let top = VerticalAlignment(id: .top)

    /// A guide that marks the vertical center of the view.
    public static let center = VerticalAlignment(id: .center)

    /// A guide that marks the bottom edge of the view.
    public static let bottom = VerticalAlignment(id: .bottom)
}

/// A view that arranges its subviews in a horizontal line.
///
/// On the iPod screen an `HStack` renders as a single row: content
/// before a `Spacer` is leading, content after it is right-aligned —
/// the classic `Text(...) / Spacer() / Text(...)` value-row idiom.
public struct HStack<Content: View>: View {

    internal let alignment: VerticalAlignment
    internal let spacing: CGFloat?
    internal let content: Content

    /// Creates a horizontal stack with the given alignment and spacing.
    public init(
        alignment: VerticalAlignment = .center,
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

/// A flexible space that expands along the major axis of its containing
/// stack layout.
public struct Spacer: View {

    /// The minimum length this spacer can be shrunk to.
    public var minLength: CGFloat?

    public init(minLength: CGFloat? = nil) {
        self.minLength = minLength
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}
