//---------------------------------------------------------------------------------
//
//  ClassicCore.swift -- portable mini-core of the iPod Classic UI.
//
//  PureSwift/Cairo and PureSwift/FontConfig (which the desktop SwiftUI-subset
//  resolver ClassicUICore/Silica renders through) have no Android build --
//  there is no prebuilt libcairo/libfontconfig for the Android NDK, and
//  cross-building the whole Cairo/FreeType/FontConfig/libpng stack from
//  source is out of scope for this port. So, like the ports/3DS and
//  ports/NDS console ports (which have the same problem under Embedded
//  Swift, for different reasons -- no Mirror, no existentials, no
//  Foundation there), this port carries its own small screen model that
//  reproduces ClassicUICore's semantics -- menu rows, settings values,
//  Notes-style text pages, Now Playing stacks, and iPod navigation with
//  per-screen selection restore and scroll windowing (the window math is
//  copied from ClassicUICore/NavigationModel.swift). This file is
//  byte-for-byte identical to ports/3DS's.
//
//  Windowing, input, and presentation are PureSwift/SDL's SDL3Swift --
//  the same library ClassicUI's desktop SDL3Renderer uses, cross-compiled
//  against SDL3's official Android prebuilts (scripts/fetch-sdl.sh) via
//  the Swift Android SDK. Unlike the desktop build this produces a shared
//  library, not an executable: SDL's Java glue (SDLActivity, see
//  AndroidApp/) loads it and calls its exported `SDL_main`
//  (source/AndroidMain.swift) on a dedicated thread.
//
//---------------------------------------------------------------------------------

/// One selectable menu row.
struct MenuItem {

  enum Action {
    /// Non-interactive row.
    case none
    /// Pushes a screen built on demand.
    case push(() -> Screen)
    /// Runs an action on select.
    case run(() -> Void)
  }

  var title: StaticString
  /// Drawn after the title (menu titles are StaticString; Embedded Swift
  /// has no string interpolation to build "Track 7" at runtime).
  var numberSuffix: Int32?
  var action: Action
  /// Right-aligned value text, recomputed on every redraw (Toggle-style).
  var detail: (() -> StaticString)?

  var isNavigation: Bool {
    if case .push = action { return true }
    return false
  }

  init(
    _ title: StaticString, number: Int32? = nil, action: Action = .none,
    detail: (() -> StaticString)? = nil
  ) {
    self.title = title
    self.numberSuffix = number
    self.action = action
    self.detail = detail
  }
}

/// A stacked (non-selectable) line on a Now Playing-style screen.
struct StackLine {

  enum Content {
    case text(() -> StaticString)
    /// "N of M" centered line (track position).
    case trackOf(() -> (number: Int32, count: Int32))
    /// Progress bar; returns completed fraction as 0...1000 permille.
    case progress(() -> Int32)
    /// Elapsed/remaining seconds drawn at the screen edges.
    case times(() -> (elapsed: Int32, remaining: Int32))
  }

  var content: Content
}

/// A full screen: an iPod menu, a wrapped text page, or stacked content.
final class Screen {

  enum Content {
    case menu([MenuItem])
    case text(StaticString)
    case stack([StackLine])
  }

  var title: StaticString
  var content: Content
  var selection: Int32 = 0
  var scrollOffset: Int32 = 0

  init(title: StaticString, content: Content) {
    self.title = title
    self.content = content
  }
}

/// The navigation stack: select pushes, B/Menu pops, and each screen's
/// selection and scroll position are restored when navigating back.
final class Navigator {

  private(set) var stack: [Screen]

  init(root: Screen) {
    stack = [root]
  }

  var top: Screen { stack[stack.count - 1] }

  /// Scroll window so the selection is always visible and the offset never
  /// leaves blank space at the bottom (ClassicUICore/NavigationModel.swift).
  static func scrollOffset(selection: Int32, current: Int32, rowCount: Int32, visibleRows: Int32)
    -> Int32
  {
    var offset = current
    if selection < offset {
      offset = selection
    }
    if selection >= offset + visibleRows {
      offset = selection - visibleRows + 1
    }
    let maxOffset = rowCount > visibleRows ? rowCount - visibleRows : 0
    return min(max(offset, 0), maxOffset)
  }

  /// Rotates the click wheel by `delta` detents (positive = down).
  func moveSelection(by delta: Int32, rowCount: Int32, visibleRows: Int32) {
    guard rowCount > 0 else { return }
    let screen = top
    screen.selection = min(max(screen.selection + delta, 0), rowCount - 1)
    screen.scrollOffset = Self.scrollOffset(
      selection: screen.selection,
      current: screen.scrollOffset,
      rowCount: rowCount,
      visibleRows: visibleRows)
  }

  func push(_ screen: Screen) {
    stack.append(screen)
  }

  /// Pops the top screen. Returns `false` when already at the root.
  func pop() -> Bool {
    guard stack.count > 1 else { return false }
    stack.removeLast()
    return true
  }
}
