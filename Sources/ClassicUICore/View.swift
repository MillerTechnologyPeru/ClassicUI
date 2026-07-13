//
//  View.swift
//  ClassicUI
//

/// A type that represents part of your app's user interface.
///
/// This protocol matches `SwiftUI.View`: code written against it
/// compiles unchanged against SwiftUI.
public protocol View {

    /// The type of view representing the body of this view.
    associatedtype Body: View

    /// The content and behavior of the view.
    @ViewBuilder var body: Body { get }
}

extension Never: View {

    public var body: Never {
        fatalError("Never has no instances")
    }
}

extension View where Body == Never {

    /// Primitive views have no body; the runtime resolves them directly.
    internal var neverBody: Never {
        fatalError("body of primitive view \(Self.self) should never be evaluated")
    }
}

/// A view that doesn't contain any content.
public struct EmptyView: View {

    public init() { }

    public typealias Body = Never
    public var body: Never { neverBody }
}

/// A type-erased view.
public struct AnyView: View {

    internal let storage: any View

    public init<V: View>(_ view: V) {
        self.storage = view
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}

extension Optional: View where Wrapped: View {

    public typealias Body = Never
    public var body: Never {
        fatalError("body of primitive view \(Self.self) should never be evaluated")
    }
}
