//
//  ForEach.swift
//  ClassicUI
//

/// A structure that computes views on demand from an underlying collection
/// of identified data.
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {

    /// The collection of underlying identified data.
    public var data: Data

    /// A function to create content on demand using the underlying data.
    public var content: (Data.Element) -> Content

    public typealias Body = Never
    public var body: Never { neverBody }
}

public extension ForEach where ID == Data.Element.ID, Data.Element: Identifiable {

    /// Creates an instance that uniquely identifies and creates views across
    /// updates based on the identity of the underlying data.
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
}

public extension ForEach {

    /// Creates an instance that uniquely identifies and creates views across
    /// updates based on the provided key path to the underlying data's identifier.
    init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
}

public extension ForEach where Data == Range<Int>, ID == Int {

    /// Creates an instance that computes views on demand over a given constant range.
    init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.data = data
        self.content = content
    }
}
