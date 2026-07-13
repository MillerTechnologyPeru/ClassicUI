//
//  Resolver.swift
//  ClassicUI
//
//  Walks a view hierarchy down to primitives and flattens list content
//  into the rows the iPod renderer understands. Along the way it assigns
//  each custom view a structural identity path and reconnects its @State
//  properties to the screen's persisted storage.
//

/// A fully resolved screen: a status bar title plus its content.
internal struct ResolvedScreen {

    enum Content {
        /// A menu of selectable rows (`List`).
        case menu([ResolvedRow])
        /// A scrollable page of wrapped text (a bare `Text` screen,
        /// like iPod Notes).
        case text(String)
        /// Non-interactive stacked content (a `VStack` screen, like
        /// Now Playing).
        case stack([ResolvedRow], alignment: HorizontalAlignment, spacing: Double)
    }

    var title: String?
    var content: Content

    /// Screen lifecycle handlers collected from `.onAppear`,
    /// `.onDisappear` and `.task` modifiers.
    struct Lifecycle {
        var onAppear: [() -> Void] = []
        var onDisappear: [() -> Void] = []
        var tasks: [(priority: TaskPriority, action: @Sendable () async -> Void)] = []
    }

    var lifecycle = Lifecycle()

    /// Actions fired once when the screen appears (first render, push,
    /// or navigating back to it).
    var onAppear: [() -> Void] { lifecycle.onAppear }

    /// Actions fired when the screen disappears (covered by a push or
    /// removed by a pop).
    var onDisappear: [() -> Void] { lifecycle.onDisappear }

    /// Async tasks started on appearance and cancelled on disappearance.
    var tasks: [(priority: TaskPriority, action: @Sendable () async -> Void)] { lifecycle.tasks }

    init(title: String? = nil, content: Content, lifecycle: Lifecycle = Lifecycle()) {
        self.title = title
        self.content = content
        self.lifecycle = lifecycle
    }

    init(title: String? = nil, rows: [ResolvedRow], lifecycle: Lifecycle = Lifecycle()) {
        self.title = title
        self.content = .menu(rows)
        self.lifecycle = lifecycle
    }

    /// Menu rows; empty for text screens.
    var rows: [ResolvedRow] {
        if case .menu(let rows) = content { return rows }
        return []
    }
}

/// One selectable menu row.
internal struct ResolvedRow {

    enum Kind {
        /// Non-interactive row (e.g. `Text`); selectable but select is a no-op.
        case inert
        /// Runs an action on select (`Button`, `Toggle`).
        case button(() -> Void)
        /// Pushes a destination on select (`NavigationLink`).
        case navigation(any View)
    }

    var text: String
    var kind: Kind

    /// Right-aligned value text (e.g. a `Toggle`'s "On"/"Off").
    var detail: String?

    /// Completed fraction of a `ProgressView` row.
    var progress: Double?

    /// Marks a `Spacer`, used by `HStack` to split leading/trailing text.
    var isSpacer = false

    var isNavigation: Bool {
        if case .navigation = kind { return true }
        return false
    }
}

/// State threaded through a resolve pass: the screen's state storage and
/// the structural identity path of the view being visited.
internal struct ResolveContext {

    let storage: StateStorage
    var path: String
    var depth: Int

    init(storage: StateStorage = StateStorage(), path: String = "", depth: Int = 0) {
        self.storage = storage
        self.path = path
        self.depth = depth
    }

    /// Context for a child at a structurally stable position.
    func descending(_ component: String) -> ResolveContext {
        var context = self
        context.path += "/" + component
        context.depth += 1
        return context
    }
}

// MARK: - Internal dispatch protocols

/// Views that flatten into menu rows.
internal protocol _RowConvertible {
    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext)
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

/// The `.onAppear` modifier wrapper.
internal protocol _AppearView {
    var _appearAction: (() -> Void)? { get }
    var _appearContent: any View { get }
}

/// The `.onDisappear` modifier wrapper.
internal protocol _DisappearView {
    var _disappearAction: (() -> Void)? { get }
    var _disappearContent: any View { get }
}

/// The `.task` modifier wrapper.
internal protocol _TaskModifierView {
    var _taskPriority: TaskPriority { get }
    var _taskAction: @Sendable () async -> Void { get }
    var _taskContent: any View { get }
}

/// `NavigationStack` container.
internal protocol _NavigationStackView {
    var _root: any View { get }
}

/// `VStack` container.
internal protocol _StackView {
    var _stackAlignment: HorizontalAlignment { get }
    var _stackSpacing: Double { get }
    var _stackContent: any View { get }
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
    static func resolveScreen(_ view: any View, storage: StateStorage = StateStorage()) -> ResolvedScreen {
        var title: String?
        var lifecycle = ResolvedScreen.Lifecycle()
        var current: any View = view
        var context = ResolveContext(storage: storage)
        for _ in 0 ..< maximumDepth {
            switch current {
            case let titled as _TitledView:
                // outermost title wins, matching SwiftUI where the modifier
                // closest to the navigation stack takes effect
                if title == nil { title = titled._title }
                current = titled._titledContent
                context = context.descending("title")
            case let appear as _AppearView:
                if let action = appear._appearAction {
                    lifecycle.onAppear.append(action)
                }
                current = appear._appearContent
                context = context.descending("appear")
            case let disappear as _DisappearView:
                if let action = disappear._disappearAction {
                    lifecycle.onDisappear.append(action)
                }
                current = disappear._disappearContent
                context = context.descending("disappear")
            case let task as _TaskModifierView:
                lifecycle.tasks.append((priority: task._taskPriority, action: task._taskAction))
                current = task._taskContent
                context = context.descending("task")
            case let stack as _NavigationStackView:
                current = stack._root
                context = context.descending("root")
            case let list as _ListView:
                var rows = [ResolvedRow]()
                flattenRows(list._listContent, into: &rows, context: context.descending("list"))
                return ResolvedScreen(title: title, rows: rows, lifecycle: lifecycle)
            case let text as Text:
                // a bare Text screen renders as a scrollable page of
                // wrapped text, like iPod Notes
                return ResolvedScreen(title: title, content: .text(text.content), lifecycle: lifecycle)
            case let anyView as AnyView:
                // unwrap type erasure before deciding the screen kind
                current = anyView.storage
                context = context.descending("any")
            case let stack as _StackView:
                var rows = [ResolvedRow]()
                flattenRows(stack._stackContent, into: &rows, context: context.descending("stack"))
                return ResolvedScreen(
                    title: title,
                    content: .stack(rows, alignment: stack._stackAlignment, spacing: stack._stackSpacing),
                    lifecycle: lifecycle
                )
            case let rowConvertible as _RowConvertible:
                // A screen without a List (e.g. a lone Text) still renders
                // as a menu of its rows.
                var rows = [ResolvedRow]()
                rowConvertible._appendRows(to: &rows, context: context)
                return ResolvedScreen(title: title, rows: rows, lifecycle: lifecycle)
            default:
                context = context.descending("\(type(of: current))")
                context.storage.install(in: current, path: context.path)
                current = body(of: current)
            }
        }
        assertionFailure("View \(type(of: view)) never resolved to a List; possible self-referential body")
        return ResolvedScreen(title: title, rows: [])
    }

    /// Flattens arbitrary view content into menu rows, evaluating the bodies
    /// of custom (non-primitive) views along the way.
    static func flattenRows(_ view: any View, into rows: inout [ResolvedRow], context: ResolveContext) {
        guard context.depth < maximumDepth else {
            assertionFailure("View \(type(of: view)) exceeded maximum row resolution depth")
            return
        }
        switch view {
        case let rowConvertible as _RowConvertible:
            rowConvertible._appendRows(to: &rows, context: context)
        case let titled as _TitledView:
            // row-level navigationTitle has no effect on rows
            flattenRows(titled._titledContent, into: &rows, context: context.descending("title"))
        case let appear as _AppearView:
            // row-level onAppear is not supported in v1; unwrap the content
            flattenRows(appear._appearContent, into: &rows, context: context.descending("appear"))
        case let disappear as _DisappearView:
            flattenRows(disappear._disappearContent, into: &rows, context: context.descending("disappear"))
        case let task as _TaskModifierView:
            flattenRows(task._taskContent, into: &rows, context: context.descending("task"))
        default:
            let child = context.descending("\(type(of: view))")
            child.storage.install(in: view, path: child.path)
            flattenRows(body(of: view), into: &rows, context: child)
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
            rowConvertible._appendRows(to: &rows, context: ResolveContext())
            return rows.first?.text ?? ""
        }
        return primaryText(of: body(of: view), depth: depth + 1)
    }
}

// MARK: - Row conformances

extension Text: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        rows.append(ResolvedRow(text: content, kind: .inert))
    }
}

extension Button: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        rows.append(ResolvedRow(text: Resolver.primaryText(of: label), kind: .button(action)))
    }
}

extension Toggle: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        let isOn = self.isOn
        rows.append(
            ResolvedRow(
                text: Resolver.primaryText(of: label),
                kind: .button { isOn.wrappedValue.toggle() },
                detail: isOn.wrappedValue ? "On" : "Off"
            )
        )
    }
}

extension NavigationLink: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        rows.append(ResolvedRow(text: Resolver.primaryText(of: label), kind: .navigation(destination)))
    }
}

extension ForEach: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        for (offset, element) in data.enumerated() {
            Resolver.flattenRows(content(element), into: &rows, context: context.descending("#\(offset)"))
        }
    }
}

extension TupleView: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        let mirror = Mirror(reflecting: value)
        // A TupleView of a single element is not a tuple; Mirror reports
        // the element's stored properties instead, so handle it directly.
        guard mirror.displayStyle == .tuple else {
            if let view = value as? any View {
                Resolver.flattenRows(view, into: &rows, context: context.descending("0"))
            } else {
                assertionFailure("TupleView value \(type(of: value)) is not a View")
            }
            return
        }
        for (offset, child) in mirror.children.enumerated() {
            guard let view = child.value as? any View else {
                assertionFailure("TupleView element \(type(of: child.value)) is not a View")
                continue
            }
            Resolver.flattenRows(view, into: &rows, context: context.descending("\(offset)"))
        }
    }
}

extension _ConditionalContent: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        // distinct path components so switching branches resets state,
        // matching SwiftUI's structural identity
        switch storage {
        case .trueContent(let view):
            Resolver.flattenRows(view, into: &rows, context: context.descending("true"))
        case .falseContent(let view):
            Resolver.flattenRows(view, into: &rows, context: context.descending("false"))
        }
    }
}

extension Optional: _RowConvertible where Wrapped: View {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        guard let view = self else { return }
        Resolver.flattenRows(view, into: &rows, context: context.descending("some"))
    }
}

extension EmptyView: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) { }
}

extension AnyView: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        Resolver.flattenRows(storage, into: &rows, context: context.descending("any"))
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

extension _OnAppearView: _AppearView {

    var _appearAction: (() -> Void)? { action }
    var _appearContent: any View { content }
}

extension _OnDisappearView: _DisappearView {

    var _disappearAction: (() -> Void)? { action }
    var _disappearContent: any View { content }
}

extension _TaskView: _TaskModifierView {

    var _taskPriority: TaskPriority { priority }
    var _taskAction: @Sendable () async -> Void { action }
    var _taskContent: any View { content }
}

extension NavigationStack: _NavigationStackView {

    var _root: any View { root }
}

extension VStack: _StackView {

    var _stackAlignment: HorizontalAlignment { alignment }
    var _stackSpacing: Double { Double(spacing ?? 0) }
    var _stackContent: any View { content }
}

extension VStack: _RowConvertible {

    // inside a List, a VStack flattens into rows
    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        Resolver.flattenRows(content, into: &rows, context: context.descending("stack"))
    }
}

extension Spacer: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        rows.append(ResolvedRow(text: "", kind: .inert, isSpacer: true))
    }
}

extension HStack: _RowConvertible {

    /// An HStack collapses into a single row: content before the first
    /// `Spacer` is the leading text, content after it the right-aligned
    /// trailing text. An interactive child (Button, NavigationLink)
    /// donates its behavior to the row; a `ProgressView` child renders
    /// the row as a progress bar.
    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        var segments = [ResolvedRow]()
        Resolver.flattenRows(content, into: &segments, context: context.descending("hstack"))

        var leading = [String]()
        var trailing = [String]()
        var seenSpacer = false
        var kind = ResolvedRow.Kind.inert
        var progress: Double?

        for segment in segments {
            if segment.isSpacer {
                seenSpacer = true
                continue
            }
            if let segmentProgress = segment.progress {
                progress = segmentProgress
                continue
            }
            if case .inert = kind {
                kind = segment.kind
            }
            if !segment.text.isEmpty {
                if seenSpacer {
                    trailing.append(segment.text)
                } else {
                    leading.append(segment.text)
                }
            }
        }

        rows.append(
            ResolvedRow(
                text: leading.joined(separator: " "),
                kind: kind,
                detail: trailing.isEmpty ? nil : trailing.joined(separator: " "),
                progress: progress
            )
        )
    }
}
