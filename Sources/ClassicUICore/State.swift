//
//  State.swift
//  ClassicUI
//

/// An interface for a stored variable that updates an external property
/// of a view.
public protocol DynamicProperty {

    /// Updates the underlying value of the stored value.
    mutating func update()
}

public extension DynamicProperty {

    mutating func update() { }
}

/// A property wrapper type that can read and write a value managed by
/// ClassicUI.
///
/// Views are value types rebuilt on every update, so `State` stores its
/// value in a reference box. The runtime persists the box per screen,
/// keyed by the view's structural identity, and reconnects fresh view
/// values to their persisted storage before each `body` evaluation —
/// mirroring SwiftUI's behavior (state lives as long as the screen; a
/// popped screen's state is discarded).
@propertyWrapper
public struct State<Value>: DynamicProperty {

    internal let box: StateBox<Value>

    /// Creates a state property that stores an initial wrapped value.
    public init(wrappedValue value: Value) {
        self.box = StateBox(value)
    }

    /// Creates a state property that stores an initial value.
    public init(initialValue value: Value) {
        self.init(wrappedValue: value)
    }

    /// The underlying value referenced by the state variable.
    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    /// A binding to the state value.
    public var projectedValue: Binding<Value> {
        Binding(get: { box.value }, set: { box.value = $0 })
    }
}

// MARK: - Storage

/// Type-erased access to a state box, used by the resolver to reconnect
/// freshly built views to persisted storage.
internal protocol _AnyStateBox: AnyObject {

    /// Redirects reads and writes to a persisted box of the same value type.
    func _link(to box: AnyObject)

    /// Called after every write to the persisted value, so async
    /// mutations (e.g. from `.task`) invalidate the display.
    func _setOnChange(_ handler: (@Sendable () -> Void)?)
}

/// Views expose their `State` properties through this protocol via Mirror.
internal protocol _StateProperty {
    var _box: _AnyStateBox { get }
}

extension State: _StateProperty {
    var _box: _AnyStateBox { box }
}

// matches SwiftUI's conditional conformance, so views holding @State can
// be captured by @Sendable .task closures; the box is only mutated from
// value writes, which the host app is responsible for serializing
extension State: @unchecked Sendable where Value: Sendable { }

internal final class StateBox<Value>: _AnyStateBox {

    private var stored: Value
    private var target: StateBox<Value>?
    private var onChange: (@Sendable () -> Void)?

    init(_ value: Value) {
        self.stored = value
    }

    var value: Value {
        get { target?.value ?? stored }
        set {
            if let target {
                target.value = newValue
            } else {
                stored = newValue
                onChange?()
            }
        }
    }

    func _link(to box: AnyObject) {
        guard box !== self, let box = box as? StateBox<Value> else { return }
        target = box
    }

    func _setOnChange(_ handler: (@Sendable () -> Void)?) {
        onChange = handler
    }
}

/// Per-screen storage of state boxes, keyed by structural identity.
/// Lives on a navigation stack entry, so popping a screen discards its state.
internal final class StateStorage {

    private var boxes: [String: _AnyStateBox] = [:]

    /// Invalidation hook fired after every state write; the runtime uses
    /// it to redraw the screen (including writes from async `.task`s).
    var onChange: (@Sendable () -> Void)?

    init() { }

    /// Registers the properties of a freshly built view: on first sight a
    /// property's box becomes the persisted source of truth, afterwards
    /// fresh boxes are linked to it.
    func install(in view: any View, path: String) {
        var index = 0
        for child in Mirror(reflecting: view).children {
            guard let property = child.value as? _StateProperty else { continue }
            let key = "\(path).\(child.label ?? "_\(index)")"
            if let persisted = boxes[key] {
                if persisted !== property._box {
                    property._box._link(to: persisted)
                }
            } else {
                boxes[key] = property._box
                property._box._setOnChange(onChange)
            }
            index += 1
        }
    }
}
