//
//  ClassicApp.swift
//  ClassicUI
//
//  SDL3 bootstrap: window, renderer, event loop, and click-wheel input
//  mapping. This is the only ClassicUI-specific entry point; everything
//  presented inside is the SwiftUI-subset view layer.
//

import Foundation
import CSDL3

/// Hosts a ClassicUI view hierarchy in an SDL3 window, emulating the
/// iPod Classic screen and click wheel.
///
/// ```swift
/// let app = try ClassicApp {
///     NavigationStack { MainMenu() }
/// }
/// try app.run()
/// ```
public final class ClassicApp {

    /// Observes every click-wheel event, including `.playPause`,
    /// `.nextTrack` and `.previousTrack`, which the navigation runtime
    /// itself ignores.
    public var onClickWheel: ((ClickWheelEvent) -> Void)?

    /// Shows the play glyph in the status bar.
    public var isPlaying: Bool = false {
        didSet { needsDisplay = true }
    }

    public let theme: Theme

    private let windowTitle: String
    private var navigation: NavigationModel
    private var needsDisplay = true
    private var running = false
    private var wheelAccumulator: Float = 0

    public init(
        theme: Theme = .classic,
        windowTitle: String = "iPod",
        @ViewBuilder root: () -> some View
    ) {
        self.theme = theme
        self.windowTitle = windowTitle
        self.navigation = NavigationModel(root: root())
    }

    /// Stops the run loop after the current iteration.
    public func quit() {
        running = false
    }

    /// Runs the blocking main loop. Must be called from the main thread.
    ///
    /// - Parameter frameLimit: Render at most this many frames, then return
    ///   (useful for headless smoke tests with `SDL_VIDEO_DRIVER=dummy`).
    public func run(frameLimit: Int? = nil) throws {
        let screenRenderer = try ClassicRenderer(theme: theme)

        guard SDL_Init(SDL_INIT_VIDEO) else {
            throw ClassicUIError.sdlError(sdlErrorMessage())
        }
        defer { SDL_Quit() }

        let width = Int32(theme.screenWidth)
        let height = Int32(theme.screenHeight)

        // SDL_WINDOW_* are SDL_UINT64_C macros, which don't import into Swift
        let windowResizable: SDL_WindowFlags = 0x0000000000000020
        let windowHighPixelDensity: SDL_WindowFlags = 0x0000000000002000

        guard let window = SDL_CreateWindow(
            windowTitle,
            width * 2,
            height * 2,
            windowResizable | windowHighPixelDensity
        ) else {
            throw ClassicUIError.sdlError(sdlErrorMessage())
        }
        defer { SDL_DestroyWindow(window) }

        guard let renderer = SDL_CreateRenderer(window, nil) else {
            throw ClassicUIError.sdlError(sdlErrorMessage())
        }
        defer { SDL_DestroyRenderer(renderer) }

        SDL_SetRenderLogicalPresentation(renderer, width, height, SDL_LOGICAL_PRESENTATION_LETTERBOX)

        guard let texture = SDL_CreateTexture(
            renderer,
            SDL_PIXELFORMAT_ARGB8888,
            SDL_TEXTUREACCESS_STREAMING,
            width,
            height
        ) else {
            throw ClassicUIError.sdlError(sdlErrorMessage())
        }
        defer { SDL_DestroyTexture(texture) }
        SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)

        running = true
        needsDisplay = true
        var renderedFrames = 0

        while running {
            var event = SDL_Event()
            while SDL_PollEvent(&event) {
                handle(event: &event)
            }

            if needsDisplay {
                needsDisplay = false
                renderScreen(into: screenRenderer, texture: texture)
            }

            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
            SDL_RenderClear(renderer)
            SDL_RenderTexture(renderer, texture, nil, nil)
            SDL_RenderPresent(renderer)

            renderedFrames += 1
            if let frameLimit, renderedFrames >= frameLimit {
                running = false
            }

            SDL_Delay(16)
        }
    }

    // MARK: - Rendering

    private func renderScreen(into screenRenderer: ClassicRenderer, texture: UnsafeMutablePointer<SDL_Texture>) {
        let screen = Resolver.resolveScreen(navigation.top.view, storage: navigation.top.stateStorage)
        navigation.clampSelection(rowCount: screen.rows.count, visibleRows: theme.visibleRows)
        screenRenderer.render(
            screen: screen,
            selection: navigation.top.selection,
            scrollOffset: navigation.top.scrollOffset,
            isPlaying: isPlaying
        )
        screenRenderer.withPixels { pixels, stride in
            SDL_UpdateTexture(texture, nil, pixels, Int32(stride))
        }
    }

    // MARK: - Input

    private func handle(event: inout SDL_Event) {
        switch SDL_EventType(rawValue: event.type) {
        case SDL_EVENT_QUIT:
            running = false
        case SDL_EVENT_KEY_DOWN:
            if let wheelEvent = Self.clickWheelEvent(scancode: event.key.scancode) {
                handle(wheelEvent)
            }
        case SDL_EVENT_MOUSE_WHEEL:
            wheelAccumulator += event.wheel.y
            while wheelAccumulator >= 1 {
                wheelAccumulator -= 1
                handle(.scrollUp)
            }
            while wheelAccumulator <= -1 {
                wheelAccumulator += 1
                handle(.scrollDown)
            }
        default:
            break
        }
    }

    private static func clickWheelEvent(scancode: SDL_Scancode) -> ClickWheelEvent? {
        switch scancode {
        case SDL_SCANCODE_UP: return .scrollUp
        case SDL_SCANCODE_DOWN: return .scrollDown
        case SDL_SCANCODE_RETURN, SDL_SCANCODE_KP_ENTER: return .select
        case SDL_SCANCODE_ESCAPE: return .menu
        case SDL_SCANCODE_SPACE: return .playPause
        case SDL_SCANCODE_RIGHT: return .nextTrack
        case SDL_SCANCODE_LEFT: return .previousTrack
        default: return nil
        }
    }

    /// Applies a click-wheel event to the navigation stack.
    private func handle(_ wheelEvent: ClickWheelEvent) {
        switch wheelEvent {
        case .scrollUp, .scrollDown:
            let screen = Resolver.resolveScreen(navigation.top.view, storage: navigation.top.stateStorage)
            navigation.moveSelection(
                by: wheelEvent == .scrollDown ? 1 : -1,
                rowCount: screen.rows.count,
                visibleRows: theme.visibleRows
            )
        case .select:
            let screen = Resolver.resolveScreen(navigation.top.view, storage: navigation.top.stateStorage)
            let selection = navigation.top.selection
            guard screen.rows.indices.contains(selection) else { break }
            switch screen.rows[selection].kind {
            case .inert:
                break
            case .button(let action):
                action()
            case .navigation(let destination):
                navigation.push(destination)
            }
        case .menu:
            navigation.pop()
        case .playPause, .nextTrack, .previousTrack:
            break
        }
        needsDisplay = true
        onClickWheel?(wheelEvent)
    }

    private func sdlErrorMessage() -> String {
        guard let error = SDL_GetError() else { return "unknown SDL error" }
        return String(cString: error)
    }
}
