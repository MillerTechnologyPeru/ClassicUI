//
//  NavigationLink.swift
//  ClassicUI
//

/// A view that controls a navigation presentation.
///
/// Selecting a `NavigationLink` row pushes its destination onto the
/// navigation stack; the Menu button pops back.
public struct NavigationLink<Label: View, Destination: View>: View {

    internal let destination: Destination
    internal let label: Label

    /// Creates a navigation link that presents the destination view.
    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination()
        self.label = label()
    }

    /// Creates a navigation link that presents the destination view, with a text label.
    public init<S: StringProtocol>(_ title: S, @ViewBuilder destination: () -> Destination) where Label == Text {
        self.init(destination: destination) { Text(title) }
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}
