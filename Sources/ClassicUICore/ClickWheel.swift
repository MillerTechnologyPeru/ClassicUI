//
//  ClickWheel.swift
//  ClassicUI
//

/// An input event from the (emulated) iPod click wheel.
///
/// Keyboard/scroll mapping: ↑/↓ arrows and the scroll wheel rotate the wheel,
/// Return is the center button, Escape is Menu, Space is Play/Pause,
/// ←/→ are Previous/Next.
public enum ClickWheelEvent: Hashable, Sendable {

    /// Wheel rotated counter-clockwise (selection up).
    case scrollUp

    /// Wheel rotated clockwise (selection down).
    case scrollDown

    /// Center button.
    case select

    /// Menu button (navigates back).
    case menu

    /// Play/Pause button.
    case playPause

    /// Next track button.
    case nextTrack

    /// Previous track button.
    case previousTrack
}
