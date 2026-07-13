//
//  List.swift
//  ClassicUI
//

/// A container that presents rows of data arranged in a single column.
///
/// On the iPod Classic screen a `List` is a full-screen menu; each
/// top-level element of its content becomes one selectable row.
public struct List<SelectionValue: Hashable, Content: View>: View {

    internal let content: Content

    public typealias Body = Never
    public var body: Never { neverBody }
}

public extension List where SelectionValue == Never {

    /// Creates a list with the given content.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

public extension List where SelectionValue == Never {

    /// Creates a list that computes its rows on demand from an underlying
    /// collection of identifiable data.
    init<Data: RandomAccessCollection, RowContent: View>(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.content = ForEach(data, content: rowContent)
    }

    /// Creates a list that identifies its rows based on a key path to the
    /// identifier of the underlying data.
    init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, ID, RowContent> {
        self.content = ForEach(data, id: id, content: rowContent)
    }
}
