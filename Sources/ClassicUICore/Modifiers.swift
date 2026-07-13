//
//  Modifiers.swift
//  ClassicUI
//

public extension View {

    /// Configures the view's title for purposes of navigation,
    /// using a string. Displayed in the iPod status bar.
    func navigationTitle<S: StringProtocol>(_ title: S) -> some View {
        _NavigationTitleView(content: self, title: String(title))
    }
}

internal struct _NavigationTitleView<Content: View>: View {

    let content: Content
    let title: String

    typealias Body = Never
    var body: Never { neverBody }
}

public extension View {

    /// Adds an action to perform when this view appears as a screen —
    /// on first render, when pushed, and again when navigating back to it
    /// (matching SwiftUI's `NavigationStack` behavior).
    func onAppear(perform action: (() -> Void)? = nil) -> some View {
        _OnAppearView(content: self, action: action)
    }
}

internal struct _OnAppearView<Content: View>: View {

    let content: Content
    let action: (() -> Void)?

    typealias Body = Never
    var body: Never { neverBody }
}

public extension View {

    /// Adds an action to perform when this view disappears as a screen —
    /// when it is covered by a push or removed by a pop (matching
    /// SwiftUI's `NavigationStack` behavior).
    func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        _OnDisappearView(content: self, action: action)
    }

    /// Adds an asynchronous task to perform when this view appears as a
    /// screen. The task is cancelled when the screen disappears and
    /// started again when it reappears, matching SwiftUI.
    func task(
        priority: TaskPriority = .userInitiated,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        _TaskView(content: self, priority: priority, action: action)
    }
}

internal struct _OnDisappearView<Content: View>: View {

    let content: Content
    let action: (() -> Void)?

    typealias Body = Never
    var body: Never { neverBody }
}

internal struct _TaskView<Content: View>: View {

    let content: Content
    let priority: TaskPriority
    let action: @Sendable () async -> Void

    typealias Body = Never
    var body: Never { neverBody }
}
