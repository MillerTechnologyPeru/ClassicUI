//
//  ProgressView.swift
//  ClassicUICore
//

/// A view that shows the progress toward completion of a task.
///
/// On the iPod screen a determinate progress view renders as the classic
/// Now Playing progress bar.
public struct ProgressView<Label: View, CurrentValueLabel: View>: View {

    /// Completed fraction in `0...1`, or `nil` when indeterminate.
    internal let fractionCompleted: Double?

    public typealias Body = Never
    public var body: Never { neverBody }
}

public extension ProgressView where Label == EmptyView, CurrentValueLabel == EmptyView {

    /// Creates a progress view for showing determinate progress.
    init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) {
        if let value, total > 0 {
            self.fractionCompleted = min(max(Double(value) / Double(total), 0), 1)
        } else {
            self.fractionCompleted = nil
        }
    }
}

extension ProgressView: _RowConvertible {

    func _appendRows(to rows: inout [ResolvedRow], context: ResolveContext) {
        rows.append(ResolvedRow(text: "", kind: .inert, progress: fractionCompleted ?? 0))
    }
}
