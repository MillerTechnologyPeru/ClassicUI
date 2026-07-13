//
//  Binding.swift
//  ClassicUI
//

/// A property wrapper type that can read and write a value owned by a
/// source of truth.
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {

    private let getter: () -> Value
    private let setter: (Value) -> Void

    /// Creates a binding with closures that read and write the binding value.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    /// Creates a binding by projecting the base value to itself.
    public init(projectedValue: Binding<Value>) {
        self = projectedValue
    }

    /// Creates a binding with an immutable value.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }

    /// The underlying value referenced by the binding variable.
    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    /// A projection of the binding value that returns a binding.
    public var projectedValue: Binding<Value> { self }

    /// Returns a binding to the resulting value of a given key path.
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding<Subject>(
            get: { wrappedValue[keyPath: keyPath] },
            set: { newValue in
                var value = wrappedValue
                value[keyPath: keyPath] = newValue
                wrappedValue = value
            }
        )
    }
}

// matches SwiftUI's conditional conformance, so bindings can travel into
// @Sendable .task closures; the host app serializes actual writes
extension Binding: @unchecked Sendable where Value: Sendable { }
