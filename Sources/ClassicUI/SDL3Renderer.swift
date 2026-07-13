//
//  SDL3Renderer.swift
//  ClassicUI
//
//  SDL3 presenter built on PureSwift SDL3Swift: window, event loop, and
//  click-wheel input mapping over a ClassicScreen. See ClassicUISpriteKit
//  for the Apple platform presenter.
//

import Foundation
import ClassicUICore
import SDL3Swift

/// Hosts a ClassicUI view hierarchy in an SDL3 window, emulating the
/// iPod Classic screen and click wheel.
///
/// ```swift
/// let renderer = SDL3Renderer {
///     NavigationStack { MainMenu() }
/// }
/// try renderer.run()
/// ```
public final class SDL3Renderer {

    /// Observes every click-wheel event, including `.playPause`,
    /// `.nextTrack` and `.previousTrack`, which the navigation runtime
    /// itself ignores.
    public var onClickWheel: ((ClickWheelEvent) -> Void)? {
        didSet { screen?.onClickWheel = onClickWheel }
    }

    /// Called once per frame with the elapsed time since the previous
    /// frame — drive playback progress and other periodic updates here.
    public var onFrame: ((TimeInterval) -> Void)? {
        didSet { screen?.onFrame = onFrame }
    }

    /// Shows the play glyph in the status bar.
    public var isPlaying: Bool = false {
        didSet { screen?.isPlaying = isPlaying }
    }

    /// Duration of the navigation slide animation; `0` disables it.
    public var transitionDuration: TimeInterval = 0.25 {
        didSet { screen?.transitionDuration = transitionDuration }
    }

    public let theme: Theme

    private let windowTitle: String
    private let root: any View
    private var screen: ClassicScreen?
    private var running = false
    private var wheelAccumulator: Float = 0
    private var gamepads = [JoystickID: SDLGamepad]()

    public init(
        theme: Theme = .classic,
        windowTitle: String = "iPod",
        @ViewBuilder root: () -> some View
    ) {
        self.theme = theme
        self.windowTitle = windowTitle
        self.root = root()
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
        try SDL.initialize(subSystems: [.video, .gamepad])
        defer {
            gamepads.removeAll()
            SDL.quit()
        }

        let window = try SDLWindow(
            title: windowTitle,
            frame: (
                x: .centered,
                y: .centered,
                width: theme.screenWidth,
                height: theme.screenHeight
            ),
            options: [.resizable, .highPixelDensity]
        )
        window.setMinimumSize(width: Int32(theme.screenWidth), height: Int32(theme.screenHeight))

        let renderer = try SDLRenderer(window: window)

        // the framebuffer matches the window's pixel size (Retina-aware);
        // the logical 320×240 UI is scaled up inside ClassicScreen
        var drawableSize = window.drawableSize

        let rootView = root
        let screen = try ClassicScreen(
            theme: theme,
            width: drawableSize.width,
            height: drawableSize.height
        ) { AnyView(rootView) }
        screen.onClickWheel = onClickWheel
        screen.onFrame = onFrame
        screen.isPlaying = isPlaying
        screen.transitionDuration = transitionDuration
        self.screen = screen
        defer { self.screen = nil }

        func makeTexture() throws(SDLError) -> SDLTexture {
            let texture = try SDLTexture(
                renderer: renderer,
                format: .argb8888,
                access: .streaming,
                width: screen.width,
                height: screen.height
            )
            try texture.setScaleMode(.nearest)
            return texture
        }

        var texture = try makeTexture()

        running = true
        var renderedFrames = 0
        var lastTicks = SDL.ticks

        while running {
            while let event = SDL.pollEvent() {
                handle(event: event, screen: screen)
            }

            // resize the framebuffer and texture with the window
            drawableSize = window.drawableSize
            if drawableSize.width != screen.width || drawableSize.height != screen.height {
                screen.resize(width: drawableSize.width, height: drawableSize.height)
                if let newTexture = try? makeTexture() {
                    texture = newTexture
                }
            }

            let ticks = SDL.ticks  // nanoseconds
            screen.frameTick(TimeInterval(ticks - lastTicks) / 1_000_000_000)
            lastTicks = ticks

            if screen.renderIfNeeded() {
                screen.withPixels { pixels, stride in
                    try? texture.update(pixels: UnsafeMutableRawPointer(pixels), pitch: stride)
                }
            }

            try? renderer.setDrawColor(red: 0, green: 0, blue: 0)
            try? renderer.clear()
            try? renderer.copy(texture, angle: 0)
            renderer.present()

            renderedFrames += 1
            if let frameLimit, renderedFrames >= frameLimit {
                running = false
            }

            SDL.delay(nanoseconds: 16_000_000)
        }
    }

    // MARK: - Input

    private func handle(event: SDLEvent, screen: ClassicScreen) {
        switch event {
        case .quit, .windowCloseRequested:
            running = false
        case .keyDown(let scancode, _):
            if let wheelEvent = Self.clickWheelEvent(scancode: scancode) {
                screen.handle(wheelEvent)
            }
        case .mouseWheel(_, _, let y):
            wheelAccumulator += y
            while wheelAccumulator >= 1 {
                wheelAccumulator -= 1
                screen.handle(.scrollUp)
            }
            while wheelAccumulator <= -1 {
                wheelAccumulator += 1
                screen.handle(.scrollDown)
            }
        case .gamepadAdded(let joystickID):
            // opening the gamepad is what makes SDL deliver its events
            gamepads[joystickID] = try? SDLGamepad(joystickID: joystickID)
        case .gamepadRemoved(let joystickID):
            gamepads[joystickID] = nil
        case .gamepadButtonDown(_, let button):
            if let wheelEvent = Self.clickWheelEvent(button: button) {
                screen.handle(wheelEvent)
            }
        default:
            break
        }
    }

    /// Gamepad mapping: A = select, B = Menu (back), D-pad up/down = wheel,
    /// D-pad left/right and shoulders = previous/next track,
    /// X/Y/Start = play/pause.
    private static func clickWheelEvent(button: SDLGamepad.Button) -> ClickWheelEvent? {
        switch button {
        case .south: return .select            // A
        case .east: return .menu               // B
        case .dpadUp: return .scrollUp
        case .dpadDown: return .scrollDown
        case .dpadLeft, .leftShoulder: return .previousTrack
        case .dpadRight, .rightShoulder: return .nextTrack
        case .west, .north, .start: return .playPause
        default: return nil
        }
    }

    private static func clickWheelEvent(scancode: Scancode) -> ClickWheelEvent? {
        switch scancode {
        case .up: return .scrollUp
        case .down: return .scrollDown
        case .return, .keypadEnter: return .select
        case .escape: return .menu
        case .space: return .playPause
        case .right: return .nextTrack
        case .left: return .previousTrack
        default: return nil
        }
    }
}
