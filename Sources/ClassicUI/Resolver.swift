//
//  Resolver.swift
//  ClassicUI
//
//  Walks a view hierarchy down to primitives and flattens list content
//  into the rows the iPod renderer understands.
//

/// A fully resolved screen: a status bar title plus selectable rows.
internal struct ResolvedScreen {

    var title: String?
    var rows: [ResolvedRow]
}

/// One selectable menu row.
internal struct ResolvedRow {

    enum Kind {
        /// Non-interactive row (e.g. `Text`); selectable but select is a no-op.
        case inert
        /// Runs an action on select (`Button`).
        case button(() -> Void)
        /// Pushes a destination on select (`NavigationLink`).
        case navigation(any View)
    }

    var text: String
    var kind: Kind

    var isNavigation: Bool {
        if case .navigation = kind { return true }
        return false
    }
}

// MARK: - Internal dispatch protocols

/// Views that flatten into menu rows.
internal protocol _RowConvertible {
    func _appendRows(to rows: inout [ResolvedRow])
}

/// Views that represent a full screen of rows (`List`).
internal protocol _ListView {
    var _listContent: any View { get }
}

/// The `.navigationTitle` modifier wrapper.
internal protocol _TitledView {
    var _title: String { get }
    var _titledContent: any View { get }
}

/// `NavigationStack` container.
internal protocol _NavigationStackView {
    var _root: any View { get }
}

// MARK: - Resolver

internal enum Resolver {

    /// Maximum `body` unwrapping depth, to catch self-referential views.
    static let maximumDepth = 1000

    /// Evaluates the `body` of a type-erased view.
    static func body(of view: any View) -> any View {
        func open<V: View>(_ view: V) -> any View { view.body }
        return open(view)
    }

    /// Resolves a view to a full screen (title + rows) by walking `body`
    /// until a `List` is found.
    static func resolveScreen(_ view: any View) -> ResolvedScreen {
        var title: String?
        var current: any View = view
        for _ in 0 ..< maximumDepth {
            switch current {
            case let titled as _TitledView:
                // outermost title wins, matching SwiftUI where the modifier
                // closest to the navigation stack takes effect
                if title == nil { title = titled._title }
                current = titled._titledContent
            case let stack as _NavigationStackView:
                current = stack._root
            case let list as _ListView:
                var rows = [ResolvedRow]()
                flattenRows(list._listContent, into: &rows)
                return ResolvedScreen(title: title, rows: rows)
            case let rowConvertible as _RowConvertible:
                // A screen without a List (e.g. a lone Text) still renders
                // as a menu of its rows.
                var rows = [ResolvedRow]()
                rowConvertible._appendRows(to: &rows)
                return ResolvedScreen(title: title, rows: rows)
            default:
                current = body(of: current)
            }
        }
        assertionFailure("View \(type(of: view)) never resolved to a List; possible self-referential body")
        return ResolvedScreen(title: title, rows: [])
    }

    /// Flattens arbitrary view content into menu rows, evaluating the bodies
    /// of custom (non-primitive) views along the way.
    static func flattenRows(_ view: any View, into rows: inout [ResolvedRow], depth: Int = 0) {
        guard depth < maximumDepth else {
            assertionFailure("View \(type(of: view)) exceeded maximum row resolution depth")
            return
        }
        switch view {
        case let rowConvertible as _RowConvertible:
            rowConvertible._appendRows(to: &rows)
        case let titled as _TitledView:
            // row-level navigationTitle has no effect on rows
            flattenRows(titled._titledContent, into: &rows, depth: depth + 1)
        default:
            flattenRows(body(of: view), into: &rows, depth: depth + 1)
        }
    }

    /// Extracts the display text of a row label (e.g. a `Button` or
    /// `NavigationLink` label), walking custom views down to their first `Text`.
    static func primaryText(of view: any View, depth: Int = 0) -> String {
        guard depth < maximumDepth else { return "" }
        if let text = view as? Text {
            return text.content
        }
        if let rowConvertible = view as? _RowConvertible {
            var rows = [ResolvedRow]()
            rowConvertible._appendRows(to: &rows)
            return rows.first?.text ?? ""
        }
        return primaryText(of: body(of: view), depth: depth + 1)
    }
}

// MARK: - Row conformances

extension Text: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) {
        rows.append(ResolvedRow(text: content, kind: .inert))
    }
}

extension Button: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) {
        rows.append(ResolvedRow(text: Resolver.primaryText(of: label), kind: .button(action)))
    }
}

extension NavigationLink: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) {
        rows.append(ResolvedRow(text: Resolver.primaryText(of: label), kind: .navigation(destination)))
    }
}

extension ForEach: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) {
        for element in data {
            Resolver.flattenRows(content(element), into: &rows, depth: 1)
        }
    }
}

extension TupleView: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) {
        for child in Mirror(reflecting: value).children {
            guard let view = child.value as? any View else {
                assertionFailure("TupleView element \(type(of: child.value)) is not a View")
                continue
            }
            Resolver.flattenRows(view, into: &rows, depth: 1)
        }
        // A TupleView of a single element is not a tuple; Mirror reports
        // the element's stored properties instead, so handle it directly.
        if Mirror(reflecting: value).displayStyle != .tuple, let view = value as? any View {
            Resolver.flattenRows(view, into: &rows, depth: 1)
        }
    }
}

extension _ConditionalContent: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) {
        switch storage {
        case .trueContent(let view):
            Resolver.flattenRows(view, into: &rows, depth: 1)
        case .falseContent(let view):
            Resolver.flattenRows(view, into: &rows, depth: 1)
        }
    }
}

extension Optional: _RowConvertible where Wrapped: View {

    func _appendRows(to rows: inout [ResolvedRow]) {
        guard let view = self else { return }
        Resolver.flattenRows(view, into: &rows, depth: 1)
    }
}

extension EmptyView: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) { }
}

extension AnyView: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow]) {
        Resolver.flattenRows(storage, into: &rows, depth: 1)
    }
}

// MARK: - Container conformances

extension List: _ListView {

    var _listContent: any View { content }
}

extension _NavigationTitleView: _TitledView {

    var _title: String { title }
    var _titledContent: any View { content }
}

extension NavigationStack: _NavigationStackView {

    var _root: any View { root }
}
