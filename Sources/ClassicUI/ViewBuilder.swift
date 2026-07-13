//
//  ViewBuilder.swift
//  ClassicUI
//

/// A custom parameter attribute that constructs views from closures.
///
/// Matches `SwiftUI.ViewBuilder`.
@resultBuilder
public enum ViewBuilder {

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)> {
        TupleView((repeat each content))
    }

    public static func buildExpression<Content: View>(_ content: Content) -> Content {
        content
    }

    public static func buildIf<Content: View>(_ content: Content?) -> Content? {
        content
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .trueContent(first))
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .falseContent(second))
    }

    public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView {
        AnyView(content)
    }
}

/// A view created from a swift tuple of view values.
public struct TupleView<T>: View {

    public var value: T

    public init(_ value: T) {
        self.value = value
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}

/// View content that shows one of two possible children.
public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View {

    internal enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }

    internal let storage: Storage

    public typealias Body = Never
    public var body: Never { neverBody }
}
