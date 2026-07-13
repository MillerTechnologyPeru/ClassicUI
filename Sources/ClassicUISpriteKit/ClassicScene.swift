//
//  ClassicScene.swift
//  ClassicUISpriteKit
//
//  SpriteKit presenter for Apple platforms: displays a ClassicScreen's
//  framebuffer in an SKScene and maps keyboard/scroll input to the
//  click wheel. See ports/Darwin for a macOS host app.
//

#if canImport(SpriteKit)
import Foundation
import CoreGraphics
import SpriteKit
@_exported import ClassicUICore

/// An SKScene presenting the iPod Classic screen.
///
/// Present it in any `SKView`; make the scene the first responder to
/// receive keyboard input (↑/↓/Return/Escape/Space/←/→ and scroll,
/// same mapping as the SDL presenter).
public final class ClassicScene: SKScene {

    public let screen: ClassicScreen

    private let sprite: SKSpriteNode
    private var lastTime: TimeInterval = 0
    private var scrollAccumulator: CGFloat = 0

    public init(screen: ClassicScreen) {
        self.screen = screen
        let size = CGSize(width: screen.width, height: screen.height)
        self.sprite = SKSpriteNode(color: .black, size: size)
        super.init(size: size)
        // the scene tracks the view's point size; the framebuffer is
        // resized to the matching pixel size for crisp Retina rendering
        scaleMode = .resizeFill
        backgroundColor = .black
        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(sprite)
    }

    public override func didMove(to view: SKView) {
        super.didMove(to: view)
        updateResolution()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sprite.size = size
        updateResolution()
    }

    /// Matches the framebuffer to the view's pixel size (points × backing
    /// scale factor).
    private func updateResolution() {
        guard view != nil, size.width > 0, size.height > 0 else { return }
        #if os(macOS)
        let backingScale = view?.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        #else
        let backingScale = view?.window?.screen?.scale ?? 2
        #endif
        let pixelWidth = Int(size.width * backingScale)
        let pixelHeight = Int(size.height * backingScale)
        guard pixelWidth != screen.width || pixelHeight != screen.height else { return }
        screen.resize(width: pixelWidth, height: pixelHeight)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public convenience init(
        theme: Theme = .classic,
        @ViewBuilder root: () -> some View
    ) throws {
        self.init(screen: try ClassicScreen(theme: theme, root: root))
    }

    // MARK: - Frame loop

    public override func update(_ currentTime: TimeInterval) {
        let delta = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime
        screen.frameTick(delta)
        if screen.renderIfNeeded() {
            uploadFramebuffer()
        }
    }

    /// Wraps the screen's ARGB32 framebuffer in a CGImage and swaps it
    /// into the sprite (well-defined top-left orientation, no swizzling).
    private func uploadFramebuffer() {
        let width = screen.width
        let height = screen.height
        var data = Data()
        var bytesPerRow = 0
        screen.withPixels { pixels, stride in
            bytesPerRow = stride
            data = Data(bytes: pixels, count: stride * height)
        }
        guard
            let provider = CGDataProvider(data: data as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue:
                    CGBitmapInfo.byteOrder32Little.rawValue
                        | CGImageAlphaInfo.premultipliedFirst.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else { return }
        let texture = SKTexture(cgImage: image)
        // pixels map 1:1 to the view's backing store; linear avoids
        // shimmer if the sizes are ever briefly out of sync
        texture.filteringMode = .linear
        sprite.texture = texture
        sprite.size = size
    }

    // MARK: - Input (macOS)

    #if os(macOS)
    public override var acceptsFirstResponder: Bool { true }

    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: screen.handle(.scrollUp)      // up arrow
        case 125: screen.handle(.scrollDown)    // down arrow
        case 36, 76: screen.handle(.select)     // return, keypad enter
        case 53: screen.handle(.menu)           // escape
        case 49: screen.handle(.playPause)      // space
        case 124: screen.handle(.nextTrack)     // right arrow
        case 123: screen.handle(.previousTrack) // left arrow
        default: super.keyDown(with: event)
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        scrollAccumulator += event.scrollingDeltaY
        let step: CGFloat = event.hasPreciseScrollingDeltas ? 10 : 1
        while scrollAccumulator >= step {
            scrollAccumulator -= step
            screen.handle(.scrollUp)
        }
        while scrollAccumulator <= -step {
            scrollAccumulator += step
            screen.handle(.scrollDown)
        }
    }
    #endif
}
#endif
