//
//  Text.swift
//  ClassicUI
//

/// A view that displays one or more lines of read-only text.
public struct Text: View {

    internal let content: String

    /// Creates a text view that displays a string literal without localization.
    public init(verbatim content: String) {
        self.content = content
    }

    /// Creates a text view that displays a stored string without localization.
    public init<S: StringProtocol>(_ content: S) {
        self.content = String(content)
    }

    public typealias Body = Never
    public var body: Never { neverBody }
}
