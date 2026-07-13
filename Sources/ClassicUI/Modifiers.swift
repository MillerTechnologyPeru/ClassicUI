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
