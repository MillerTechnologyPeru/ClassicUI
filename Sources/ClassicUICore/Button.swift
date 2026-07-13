//
//  Button.swift
//  ClassicUI
//

/// A control that initiates an action.
public struct Button<Label: View>: View {

    internal let action: () -> Void
    internal let label: Label

    /// Creates a button that displays a custom label.
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}

public extension Button where Label == Text {

    /// Creates a button that generates its label from a string.
    init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {
        self.init(action: action) { Text(title) }
    }
}
