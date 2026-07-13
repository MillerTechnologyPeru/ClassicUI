//
//  NavigationModel.swift
//  ClassicUI
//
//  Pure navigation state: the stack of screens, plus per-screen selection
//  and scroll position, exactly like the real iPod (selection is restored
//  when navigating back with the Menu button).
//

/// Holds the running `.task` handles of one screen.
internal final class TaskStorage {

    private var tasks: [Task<Void, Never>] = []

    func add(_ task: Task<Void, Never>) {
        tasks.append(task)
    }

    func cancelAll() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
}

internal struct NavigationModel {

    struct Entry {
        var view: any View
        var selection: Int = 0
        var scrollOffset: Int = 0
        /// Whether `.onAppear` actions have fired for the current
        /// appearance; reset when the screen is revealed again by a pop.
        var hasAppeared = false
        /// @State storage for views resolved within this screen; discarded
        /// when the screen is popped, like SwiftUI.
        let stateStorage = StateStorage()
        /// Running `.task` modifiers, cancelled when the screen disappears.
        let taskStorage = TaskStorage()
    }

    private(set) var stack: [Entry]

    init(root: any View) {
        self.stack = [Entry(view: root)]
    }

    var top: Entry { stack[stack.count - 1] }

    var depth: Int { stack.count }

    /// Rotates the click wheel by `delta` detents (positive = clockwise = down).
    mutating func moveSelection(by delta: Int, rowCount: Int, visibleRows: Int) {
        guard rowCount > 0 else { return }
        var entry = stack[stack.count - 1]
        entry.selection = min(max(entry.selection + delta, 0), rowCount - 1)
        entry.scrollOffset = Self.scrollOffset(
            selection: entry.selection,
            current: entry.scrollOffset,
            rowCount: rowCount,
            visibleRows: visibleRows
        )
        stack[stack.count - 1] = entry
    }

    /// Re-clamps selection after the row count changed (dynamic content).
    mutating func clampSelection(rowCount: Int, visibleRows: Int) {
        var entry = stack[stack.count - 1]
        entry.selection = min(max(entry.selection, 0), max(0, rowCount - 1))
        entry.scrollOffset = Self.scrollOffset(
            selection: entry.selection,
            current: entry.scrollOffset,
            rowCount: rowCount,
            visibleRows: visibleRows
        )
        stack[stack.count - 1] = entry
    }

    mutating func push(_ view: any View) {
        stack.append(Entry(view: view))
    }

    /// Pops the top screen. Returns `false` when already at the root.
    @discardableResult
    mutating func pop() -> Bool {
        guard stack.count > 1 else { return false }
        stack.removeLast()
        // the revealed screen appears again, like SwiftUI's NavigationStack
        stack[stack.count - 1].hasAppeared = false
        return true
    }

    mutating func markTopAppeared() {
        stack[stack.count - 1].hasAppeared = true
    }

    /// Scroll window so the selection is always visible and the offset never
    /// leaves blank space at the bottom.
    static func scrollOffset(selection: Int, current: Int, rowCount: Int, visibleRows: Int) -> Int {
        var offset = current
        if selection < offset {
            offset = selection
        }
        if selection >= offset + visibleRows {
            offset = selection - visibleRows + 1
        }
        return min(max(offset, 0), max(0, rowCount - visibleRows))
    }
}
