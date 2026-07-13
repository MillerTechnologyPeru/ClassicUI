import Testing
@testable import ClassicUICore

// MARK: - Binding

@Suite struct BindingTests {

    @Test func getAndSet() {
        var value = 1
        let binding = Binding(get: { value }, set: { value = $0 })
        #expect(binding.wrappedValue == 1)
        binding.wrappedValue = 5
        #expect(value == 5)
    }

    @Test func constant() {
        let binding = Binding.constant(3)
        binding.wrappedValue = 9
        #expect(binding.wrappedValue == 3)
    }

    @Test func dynamicMemberLookup() {
        struct Settings {
            var shuffle = false
        }
        var settings = Settings()
        let binding = Binding(get: { settings }, set: { settings = $0 })
        let shuffle = binding.shuffle
        #expect(shuffle.wrappedValue == false)
        shuffle.wrappedValue = true
        #expect(settings.shuffle == true)
    }

    @Test func projectedValueIsSelf() {
        var value = "a"
        let binding = Binding(get: { value }, set: { value = $0 })
        binding.projectedValue.wrappedValue = "b"
        #expect(value == "b")
    }
}

// MARK: - State

@Suite struct StateTests {

    struct Counter: View {
        @State private var count = 0
        var body: some View {
            List {
                Button("Count: \(count)") { count += 1 }
            }
            .navigationTitle("Counter")
        }
    }

    private func selectFirstRow(_ screen: ResolvedScreen) {
        guard case .button(let action) = screen.rows[0].kind else {
            Issue.record("expected button row")
            return
        }
        action()
    }

    @Test func statePersistsAcrossResolves() {
        let storage = StateStorage()
        let view = Counter()

        var screen = Resolver.resolveScreen(view, storage: storage)
        #expect(screen.rows[0].text == "Count: 0")
        selectFirstRow(screen)

        // rebuild the view from scratch, like the runtime does per event
        screen = Resolver.resolveScreen(Counter(), storage: storage)
        #expect(screen.rows[0].text == "Count: 1")
        selectFirstRow(screen)

        screen = Resolver.resolveScreen(Counter(), storage: storage)
        #expect(screen.rows[0].text == "Count: 2")
    }

    @Test func freshStorageResetsState() {
        let storage = StateStorage()
        var screen = Resolver.resolveScreen(Counter(), storage: storage)
        selectFirstRow(screen)
        screen = Resolver.resolveScreen(Counter(), storage: storage)
        #expect(screen.rows[0].text == "Count: 1")

        // a new screen (e.g. re-pushed after popping) starts over
        let fresh = Resolver.resolveScreen(Counter(), storage: StateStorage())
        #expect(fresh.rows[0].text == "Count: 0")
    }

    @Test func statePersistsInRowLevelCustomView() {
        struct RowCounter: View {
            @State private var taps = 0
            var body: some View {
                Button("Taps: \(taps)") { taps += 1 }
            }
        }
        struct Menu: View {
            var body: some View {
                List {
                    Text("Header")
                    RowCounter()
                }
            }
        }
        let storage = StateStorage()
        var screen = Resolver.resolveScreen(Menu(), storage: storage)
        #expect(screen.rows[1].text == "Taps: 0")
        guard case .button(let action) = screen.rows[1].kind else {
            Issue.record("expected button row")
            return
        }
        action()
        screen = Resolver.resolveScreen(Menu(), storage: storage)
        #expect(screen.rows[1].text == "Taps: 1")
    }

    @Test func siblingsOfSameTypeHaveIndependentState() {
        struct RowCounter: View {
            let label: String
            @State private var taps = 0
            var body: some View {
                Button("\(label): \(taps)") { taps += 1 }
            }
        }
        struct Menu: View {
            var body: some View {
                List {
                    RowCounter(label: "A")
                    RowCounter(label: "B")
                }
            }
        }
        let storage = StateStorage()
        var screen = Resolver.resolveScreen(Menu(), storage: storage)
        guard case .button(let tapFirst) = screen.rows[0].kind else {
            Issue.record("expected button row")
            return
        }
        tapFirst()
        tapFirst()
        screen = Resolver.resolveScreen(Menu(), storage: storage)
        #expect(screen.rows[0].text == "A: 2")
        #expect(screen.rows[1].text == "B: 0")
    }

    @Test func projectedValueBindingWritesState() {
        struct Menu: View {
            @State private var enabled = false
            var body: some View {
                List {
                    Toggle("Backlight", isOn: $enabled)
                }
            }
        }
        let storage = StateStorage()
        var screen = Resolver.resolveScreen(Menu(), storage: storage)
        #expect(screen.rows[0].detail == "Off")
        guard case .button(let toggle) = screen.rows[0].kind else {
            Issue.record("expected button row")
            return
        }
        toggle()
        screen = Resolver.resolveScreen(Menu(), storage: storage)
        #expect(screen.rows[0].detail == "On")
    }
}

// MARK: - Toggle

@Suite struct ToggleTests {

    @Test func rowShowsLabelAndValue() {
        var isOn = true
        let binding = Binding(get: { isOn }, set: { isOn = $0 })
        var resolved = [ResolvedRow]()
        Resolver.flattenRows(Toggle("Shuffle", isOn: binding), into: &resolved, context: ResolveContext())
        #expect(resolved.count == 1)
        #expect(resolved[0].text == "Shuffle")
        #expect(resolved[0].detail == "On")
    }

    @Test func selectTogglesBinding() {
        var isOn = false
        let binding = Binding(get: { isOn }, set: { isOn = $0 })
        var resolved = [ResolvedRow]()
        Resolver.flattenRows(Toggle("Shuffle", isOn: binding), into: &resolved, context: ResolveContext())
        guard case .button(let action) = resolved[0].kind else {
            Issue.record("expected button row")
            return
        }
        action()
        #expect(isOn == true)
        action()
        #expect(isOn == false)
    }
}
