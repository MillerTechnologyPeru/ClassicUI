//
//  Toggle.swift
//  ClassicUI
//

/// A control that toggles between on and off states.
///
/// On the iPod screen a toggle renders as a settings-style row with its
/// value ("On"/"Off") right-aligned; the center button flips it.
public struct Toggle<Label: View>: View {

    internal let isOn: Binding<Bool>
    internal let label: Label

    /// Creates a toggle that displays a custom label.
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.isOn = isOn
        self.label = label()
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}

public extension Toggle where Label == Text {

    /// Creates a toggle that generates its label from a string.
    init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
    }
}
