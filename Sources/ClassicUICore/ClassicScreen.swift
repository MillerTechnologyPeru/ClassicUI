//
//  ClassicScreen.swift
//  ClassicUICore
//
//  Platform-agnostic iPod screen controller: owns the navigation stack,
//  handles click-wheel events, and renders into an offscreen surface.
//  Presenters (SDL3, SpriteKit, …) feed it input and blit its pixels.
//

import Foundation
import Observation

/// Thread-safe invalidation flag set by Observation's change callback,
/// which is `@Sendable` and may fire off the main thread.
private final class InvalidationFlag: @unchecked Sendable {

    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    /// Returns the current value and clears it.
    func consume() -> Bool {
        lock.lock()
        defer {
            value = false
            lock.unlock()
        }
        return value
    }
}

/// The iPod Classic screen: a view hierarchy, click-wheel navigation and
/// an offscreen ARGB32 framebuffer.
///
/// Presenters drive it with three calls per frame:
/// `frameTick(_:)`, `renderIfNeeded()`, and — when it returns `true` —
/// `withPixels(_:)` to upload the framebuffer. Input arrives via
/// `handle(_:)`.
public final class ClassicScreen {

    public let theme: Theme

    /// Observes every click-wheel event, including `.playPause`,
    /// `.nextTrack` and `.previousTrack`, which the navigation runtime
    /// itself ignores.
    public var onClickWheel: ((ClickWheelEvent) -> Void)?

    /// Called once per presenter frame with the elapsed time since the
    /// previous frame — drive playback progress and other periodic
    /// updates from here.
    public var onFrame: ((TimeInterval) -> Void)?

    /// Shows the play glyph in the status bar.
    public var isPlaying: Bool = false {
        didSet {
            if isPlaying != oldValue {
                needsDisplay = true
            }
        }
    }

    /// Framebuffer width in device pixels.
    public var width: Int { renderer.pixelWidth }

    /// Framebuffer height in device pixels.
    public var height: Int { renderer.pixelHeight }

    /// Duration of the slide animation when navigating (push slides in
    /// from the right, Menu/pop from the left, like the real iPod).
    /// Set to `0` to disable.
    public var transitionDuration: TimeInterval = 0.25

    private enum TransitionDirection {
        case push
        case pop
    }

    private struct Transition {
        var progress: Double
        let direction: TransitionDirection
        let outgoing: [UInt8]
    }

    private var navigation: NavigationModel
    private let renderer: ClassicRenderer
    private var needsDisplay = true
    private let observationInvalidation = InvalidationFlag()
    private var transition: Transition?
    private var presentBuffer = [UInt8]()

    /// Whether a navigation slide is currently animating.
    internal var isTransitioning: Bool { transition != nil }

    /// Creates a screen.
    ///
    /// - Parameters:
    ///   - width: Framebuffer width in device pixels (defaults to the
    ///     theme's logical width). The logical 320×240 UI is scaled up to
    ///     fill the framebuffer, so pass the window's pixel size (points ×
    ///     backing scale factor) for crisp Retina rendering.
    ///   - height: Framebuffer height in device pixels.
    public init(
        theme: Theme = .classic,
        width: Int? = nil,
        height: Int? = nil,
        @ViewBuilder root: () -> some View
    ) throws {
        self.theme = theme
        self.navigation = NavigationModel(root: root())
        self.renderer = try ClassicRenderer(theme: theme, width: width, height: height)
        attachInvalidation(to: navigation.top)
    }

    deinit {
        for entry in navigation.stack {
            entry.taskStorage.cancelAll()
        }
    }

    /// Redraw when a screen's @State is written, including from `.task`s.
    private func attachInvalidation(to entry: NavigationModel.Entry) {
        let flag = observationInvalidation
        entry.stateStorage.onChange = {
            flag.set()
        }
    }

    /// Resizes the framebuffer to a new device-pixel size (call when the
    /// window size or display scale changes). Cancels any navigation
    /// slide in progress.
    public func resize(width: Int, height: Int) {
        guard width != self.width || height != self.height else { return }
        try? renderer.resize(width: width, height: height)
        transition = nil
        presentBuffer = []
        needsDisplay = true
    }

    /// Marks the screen as needing a redraw on the next frame.
    public func setNeedsDisplay() {
        needsDisplay = true
    }

    /// Advances animations and reports elapsed frame time to the host
    /// app (`onFrame`).
    public func frameTick(_ delta: TimeInterval) {
        if var active = transition {
            active.progress += transitionDuration > 0 ? delta / transitionDuration : 1
            transition = active.progress >= 1 ? nil : active
            needsDisplay = true
        }
        onFrame?(delta)
    }

    // MARK: - Input

    /// Applies a click-wheel event to the navigation stack.
    public func handle(_ event: ClickWheelEvent) {
        switch event {
        case .scrollUp, .scrollDown:
            scroll(by: event == .scrollDown ? 1 : -1)
        case .select:
            select()
        case .menu:
            let outgoing = captureFramebuffer()
            let outgoingScreen = resolveTop()
            let outgoingTasks = navigation.top.taskStorage
            let hadAppeared = navigation.top.hasAppeared
            if navigation.pop() {
                if hadAppeared {
                    outgoingScreen.onDisappear.forEach { $0() }
                    outgoingTasks.cancelAll()
                }
                beginTransition(.pop, outgoing: outgoing)
            }
        case .playPause, .nextTrack, .previousTrack:
            break
        }
        needsDisplay = true
        onClickWheel?(event)
    }

    private func scroll(by delta: Int) {
        let screen = resolveTop()
        switch screen.content {
        case .menu(let rows):
            navigation.moveSelection(
                by: delta,
                rowCount: rows.count,
                visibleRows: renderer.visibleRows
            )
        case .text(let text):
            // scrolling a text page moves the top line; reuse the selection
            // slot as the line offset with a 1-line window
            let maxOffset = max(0, renderer.lineCount(for: text) - renderer.visibleTextLines)
            navigation.moveSelection(by: delta, rowCount: maxOffset + 1, visibleRows: 1)
        case .stack:
            // stacked screens (Now Playing) have nothing to select
            break
        }
    }

    private func select() {
        let screen = resolveTop()
        guard case .menu(let rows) = screen.content else { return }
        let selection = navigation.top.selection
        guard rows.indices.contains(selection) else { return }
        switch rows[selection].kind {
        case .inert:
            break
        case .button(let action):
            action()
        case .navigation(let destination):
            let outgoing = captureFramebuffer()
            // the current screen is covered by the push: it disappears
            if navigation.top.hasAppeared {
                screen.onDisappear.forEach { $0() }
                navigation.top.taskStorage.cancelAll()
            }
            navigation.push(destination)
            attachInvalidation(to: navigation.top)
            beginTransition(.push, outgoing: outgoing)
        }
    }

    // MARK: - Rendering

    private func resolveTop() -> ResolvedScreen {
        Resolver.resolveScreen(navigation.top.view, storage: navigation.top.stateStorage)
    }

    /// Re-renders the framebuffer when input or observable state changed
    /// it. Returns `true` when new pixels are available.
    @discardableResult
    public func renderIfNeeded() -> Bool {
        if observationInvalidation.consume() {
            needsDisplay = true
        }
        guard needsDisplay else { return false }
        needsDisplay = false

        // Track @Observable reads during body evaluation so view model
        // mutations re-render the screen, even without an input event.
        let flag = observationInvalidation
        var screen = withObservationTracking {
            resolveTop()
        } onChange: {
            flag.set()
        }

        // fire .onAppear actions and start .task work once per appearance,
        // then re-resolve so the first visible frame reflects any state
        // the appear actions changed
        if !navigation.top.hasAppeared {
            navigation.markTopAppeared()
            let taskStorage = navigation.top.taskStorage
            for task in screen.tasks {
                taskStorage.add(Task(priority: task.priority) { await task.action() })
            }
            if !screen.onAppear.isEmpty {
                screen.onAppear.forEach { $0() }
                screen = withObservationTracking {
                    resolveTop()
                } onChange: {
                    flag.set()
                }
            }
        }

        switch screen.content {
        case .menu(let rows):
            navigation.clampSelection(rowCount: rows.count, visibleRows: renderer.visibleRows)
        case .text(let text):
            let maxOffset = max(0, renderer.lineCount(for: text) - renderer.visibleTextLines)
            navigation.clampSelection(rowCount: maxOffset + 1, visibleRows: 1)
        case .stack:
            break
        }

        renderer.render(
            screen: screen,
            selection: navigation.top.selection,
            scrollOffset: navigation.top.scrollOffset,
            isPlaying: isPlaying
        )

        if let transition {
            composite(transition)
        }
        return true
    }

    /// Exposes the rendered framebuffer: premultiplied ARGB32 pixels in
    /// native byte order (BGRA in memory on little-endian), `stride`
    /// bytes per row. During a navigation slide this is the composited
    /// transition frame.
    public func withPixels(_ body: (UnsafeMutablePointer<UInt8>, _ stride: Int) -> Void) {
        if transition != nil, !presentBuffer.isEmpty {
            let stride = renderer.stride
            presentBuffer.withUnsafeMutableBufferPointer { buffer in
                body(buffer.baseAddress!, stride)
            }
        } else {
            renderer.withPixels(body)
        }
    }

    // MARK: - Navigation slide

    private func beginTransition(_ direction: TransitionDirection, outgoing: [UInt8]) {
        guard transitionDuration > 0, !outgoing.isEmpty else {
            transition = nil
            return
        }
        transition = Transition(progress: 0, direction: direction, outgoing: outgoing)
    }

    /// Copies the pixels currently on screen (the mid-transition composite
    /// when a slide is interrupted by further navigation).
    private func captureFramebuffer() -> [UInt8] {
        if transition != nil, !presentBuffer.isEmpty {
            return presentBuffer
        }
        var buffer = [UInt8]()
        renderer.withPixels { pixels, stride in
            buffer = Array(UnsafeBufferPointer(start: pixels, count: stride * height))
        }
        return buffer
    }

    /// Slides the outgoing framebuffer out and the (just rendered)
    /// incoming screen in, writing the combined frame to `presentBuffer`.
    private func composite(_ transition: Transition) {
        let stride = renderer.stride
        let bytesPerPixel = 4
        let width = self.width
        let height = self.height
        // ease-out, like the device
        let eased = 1 - (1 - transition.progress) * (1 - transition.progress)
        let offset = min(width, max(0, Int(eased * Double(width))))

        if presentBuffer.count != stride * height {
            presentBuffer = [UInt8](repeating: 0, count: stride * height)
        }
        guard transition.outgoing.count == stride * height else { return }

        // the status bar stays fixed: only the content below it slides
        let statusBarPixels = min(height, Int(theme.statusBarHeight * Double(renderer.scale)))

        renderer.withPixels { incoming, _ in
            presentBuffer.withUnsafeMutableBufferPointer { present in
                transition.outgoing.withUnsafeBufferPointer { outgoing in
                    let presentBase = present.baseAddress!
                    let outgoingBase = outgoing.baseAddress!
                    for row in 0 ..< height {
                        let rowStart = row * stride
                        if row < statusBarPixels {
                            // pinned status bar, always the incoming screen's
                            memcpy(presentBase + rowStart, incoming + rowStart, width * bytesPerPixel)
                            continue
                        }
                        let visibleOutgoing = (width - offset) * bytesPerPixel
                        let visibleIncoming = offset * bytesPerPixel
                        switch transition.direction {
                        case .push:
                            // outgoing slides left, incoming enters from the right
                            if visibleOutgoing > 0 {
                                memcpy(
                                    presentBase + rowStart,
                                    outgoingBase + rowStart + visibleIncoming,
                                    visibleOutgoing
                                )
                            }
                            if visibleIncoming > 0 {
                                memcpy(
                                    presentBase + rowStart + visibleOutgoing,
                                    incoming + rowStart,
                                    visibleIncoming
                                )
                            }
                        case .pop:
                            // incoming enters from the left, outgoing slides right
                            if visibleIncoming > 0 {
                                memcpy(
                                    presentBase + rowStart,
                                    incoming + rowStart + visibleOutgoing,
                                    visibleIncoming
                                )
                            }
                            if visibleOutgoing > 0 {
                                memcpy(
                                    presentBase + rowStart + visibleIncoming,
                                    outgoingBase + rowStart,
                                    visibleOutgoing
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
