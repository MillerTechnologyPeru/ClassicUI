//
//  NavigationStack.swift
//  ClassicUI
//

/// A type-erased list of data representing the content of a navigation stack.
public struct NavigationPath {

    public init() { }
}

/// A view that displays a root view and enables you to present additional
/// views over the root view.
public struct NavigationStack<Data, Root: View>: View {

    internal let root: Root

    /// Creates a navigation stack that manages its own navigation state.
    public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {
        self.root = root()
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}
