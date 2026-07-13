import Foundation
import Testing
@testable import ClassicUICore

// serialized: each test constructs a renderer, and Cairo font teardown
// races when instances are destroyed concurrently
@Suite(.serialized) struct TransitionTests {

    struct RootMenu: View {
        var body: some View {
            List {
                NavigationLink("Music") {
                    List { Text("Song") }.navigationTitle("Music")
                }
            }
            .navigationTitle("iPod")
        }
    }

    private func makeScreen() throws -> ClassicScreen {
        let screen = try ClassicScreen {
            NavigationStack { RootMenu() }
        }
        screen.renderIfNeeded()
        return screen
    }

    @Test func pushStartsSlideAndCompletes() throws {
        let screen = try makeScreen()
        screen.handle(.select)
        #expect(screen.isTransitioning)

        // mid-transition frames render and expose composited pixels
        screen.frameTick(0.1)
        #expect(screen.renderIfNeeded())
        var strideSeen = 0
        screen.withPixels { _, stride in strideSeen = stride }
        #expect(strideSeen >= 320 * 4)

        // completes after the configured duration
        screen.frameTick(screen.transitionDuration)
        #expect(!screen.isTransitioning)
        #expect(screen.renderIfNeeded())
    }

    @Test func popSlidesBack() throws {
        let screen = try makeScreen()
        screen.handle(.select)
        screen.frameTick(1)
        screen.renderIfNeeded()
        #expect(!screen.isTransitioning)

        screen.handle(.menu)
        #expect(screen.isTransitioning)
        screen.frameTick(1)
        #expect(!screen.isTransitioning)
    }

    @Test func popAtRootDoesNotSlide() throws {
        let screen = try makeScreen()
        screen.handle(.menu)
        #expect(!screen.isTransitioning)
    }

    @Test func zeroDurationDisablesSlide() throws {
        let screen = try makeScreen()
        screen.transitionDuration = 0
        screen.handle(.select)
        #expect(!screen.isTransitioning)
        #expect(screen.renderIfNeeded())
    }

    @Test func selectOnInertRowDoesNotSlide() throws {
        let screen = try ClassicScreen {
            List { Text("About") }
        }
        screen.renderIfNeeded()
        screen.handle(.select)
        #expect(!screen.isTransitioning)
    }
}

@Suite(.serialized) struct OnAppearTests {

    final class Counter {
        var appearances = 0
    }

    private func makeScreen(counter: Counter) throws -> ClassicScreen {
        try ClassicScreen {
            NavigationStack {
                List {
                    NavigationLink("Play") {
                        List { Text("Playing") }
                            .navigationTitle("Now Playing")
                            .onAppear { counter.appearances += 1 }
                    }
                }
                .navigationTitle("Songs")
            }
        }
    }

    @Test func firesOncePerPush() throws {
        let counter = Counter()
        let screen = try makeScreen(counter: counter)
        screen.renderIfNeeded()
        #expect(counter.appearances == 0)

        screen.handle(.select)
        screen.renderIfNeeded()
        #expect(counter.appearances == 1)

        // re-renders of the same appearance do not fire again
        screen.setNeedsDisplay()
        screen.renderIfNeeded()
        #expect(counter.appearances == 1)
    }

    @Test func firesAgainAfterPopAndRepush() throws {
        let counter = Counter()
        let screen = try makeScreen(counter: counter)
        screen.renderIfNeeded()
        screen.handle(.select)
        screen.renderIfNeeded()
        screen.handle(.menu)
        screen.renderIfNeeded()
        screen.handle(.select)
        screen.renderIfNeeded()
        #expect(counter.appearances == 2)
    }

    @Test func rootOnAppearFiresOnFirstRender() throws {
        var fired = false
        let screen = try ClassicScreen {
            List { Text("Root") }.onAppear { fired = true }
        }
        #expect(!fired)
        screen.renderIfNeeded()
        #expect(fired)
    }
}

@Suite(.serialized) struct LifecycleTests {

    /// Thread-safe flag for observing @Sendable async work.
    final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false
        var value: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); _value = newValue; lock.unlock() }
        }
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        for _ in 0 ..< 200 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("timed out waiting for condition")
    }

    @Test func onDisappearFiresOnPushCoverAndPop() throws {
        var events = [String]()
        let screen = try ClassicScreen {
            NavigationStack {
                List {
                    NavigationLink("Child") {
                        List { Text("Child") }
                            .onAppear { events.append("child appear") }
                            .onDisappear { events.append("child disappear") }
                    }
                }
                .onAppear { events.append("root appear") }
                .onDisappear { events.append("root disappear") }
            }
        }
        screen.renderIfNeeded()
        #expect(events == ["root appear"])

        screen.handle(.select)          // push covers the root
        screen.renderIfNeeded()
        #expect(events == ["root appear", "root disappear", "child appear"])

        screen.handle(.menu)            // pop removes the child
        screen.renderIfNeeded()
        #expect(events == [
            "root appear", "root disappear",
            "child appear", "child disappear",
            "root appear"                // revealed screen appears again
        ])
    }

    @Test func taskStartsOnAppear() async throws {
        let started = Flag()
        let screen = try ClassicScreen {
            List { Text("Root") }
                .task { started.value = true }
        }
        #expect(!started.value)
        screen.renderIfNeeded()
        try await waitUntil { started.value }
    }

    @Test func taskCancelledOnPop() async throws {
        let started = Flag()
        let cancelled = Flag()
        let screen = try ClassicScreen {
            NavigationStack {
                List {
                    NavigationLink("Child") {
                        List { Text("Child") }
                            .task {
                                started.value = true
                                while !Task.isCancelled {
                                    try? await Task.sleep(nanoseconds: 5_000_000)
                                }
                                cancelled.value = true
                            }
                    }
                }
            }
        }
        screen.renderIfNeeded()
        screen.handle(.select)
        screen.renderIfNeeded()
        try await waitUntil { started.value }
        #expect(!cancelled.value)

        screen.handle(.menu)
        try await waitUntil { cancelled.value }
    }

    @Test func stateWriteFromTaskInvalidatesDisplay() async throws {
        struct Loader: View {
            @State private var loaded = false
            var body: some View {
                List {
                    if loaded {
                        Text("Loaded")
                    } else {
                        Text("Loading")
                    }
                }
                .task { loaded = true }
            }
        }
        let screen = try ClassicScreen { Loader() }
        screen.renderIfNeeded()
        // the task's state write must mark the screen dirty and the
        // next render must reflect it
        try await waitUntil { screen.renderIfNeeded() }
    }
}
