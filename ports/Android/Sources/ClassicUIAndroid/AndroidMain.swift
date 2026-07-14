//---------------------------------------------------------------------------------
//
//  AndroidMain.swift -- Android entry point for the ClassicUI shared library.
//
//  Lifecycle: MainActivity (a Java SDLActivity subclass, see AndroidApp/) calls
//  `System.loadLibrary("ClassicUIAndroid")`, which SDL's Java side loads on a
//  dedicated native thread before invoking the exported `SDL_main` below --
//  the Android equivalent of the desktop SDL3Renderer's `run()`. No JNI
//  bootstrap and no bundled assets are needed (unlike a typical SDL Android
//  port): the UI font is compiled in as Swift arrays (tools/gen_font.py),
//  same as the ports/3DS and ports/NDS console builds.
//
//  Everything below the video-setup block is close to a plain SDL3Swift
//  app: create a window, a streaming ARGB8888 texture sized to the iPod's
//  320x240 logical canvas, and run an SDL_PollEvent loop -- SDL itself
//  handles binding the window to the Activity's Android surface.
//
//    D-pad / gamepad     rotate the click wheel, A = select, B = menu
//    tap upper/lower third of the screen   scroll wheel
//    tap the middle third                  select
//    system Back gesture/button            Menu (back)
//
//---------------------------------------------------------------------------------

import SDL3Swift
import CSDL3

/// SDL3Swift's `Scancode` doesn't expose this constant; the Android system
/// Back gesture/button arrives as this scancode.
private let scancodeACBack = Scancode(rawValue: SDL_SCANCODE_AC_BACK.rawValue)

private nonisolated(unsafe) var screen: Canvas!
private nonisolated(unsafe) var outgoingBuffer: UnsafeMutablePointer<UInt32>!
private nonisolated(unsafe) var presentBuffer: UnsafeMutablePointer<UInt32>!
private nonisolated(unsafe) var canvasPixelCount = 0

private nonisolated(unsafe) var slideProgress: Int32 = -1  // -1 = idle, else 0...64
private nonisolated(unsafe) var slidePush = true
private nonisolated(unsafe) var frameDirty = true

private func beginSlide(push: Bool) {
  var i = 0
  while i < canvasPixelCount {
    outgoingBuffer[i] = presentBuffer[i]
    i += 1
  }
  slidePush = push
  slideProgress = 0
  frameDirty = true
}

// MARK: - Player state (demo content, mirrors ports/3DS and ports/NDS)

private final class Player {
  var playing = false
  var shuffle = false
  var trackNumber: Int32 = 1
  let trackCount: Int32 = 90
  var elapsedFrames: Int32 = 0
  let durationSeconds: Int32 = 222

  var elapsedSeconds: Int32 { elapsedFrames / 60 }
  var permille: Int32 { (elapsedFrames &* 1000) / (durationSeconds &* 60) }

  func play(track: Int32) {
    trackNumber = track
    elapsedFrames = 0
    playing = true
  }

  /// Advances one 60Hz frame of playback.
  func tick() {
    guard playing else { return }
    elapsedFrames &+= 1
    if elapsedSeconds >= durationSeconds {
      trackNumber = trackNumber % trackCount &+ 1
      elapsedFrames = 0
    }
  }
}

private nonisolated(unsafe) let player = Player()

// MARK: - Screens (same demo content as ports/3DS and ports/NDS)

private func makeNowPlaying() -> Screen {
  Screen(
    title: "Now Playing",
    content: .stack([
      StackLine(content: .trackOf { (player.trackNumber, player.trackCount) }),
      StackLine(content: .text { "Harder, Better, Faster, Stronger" }),
      StackLine(content: .text { "Daft Punk - Discovery" }),
      StackLine(content: .progress { player.permille }),
      StackLine(
        content: .times {
          (player.elapsedSeconds, player.durationSeconds - player.elapsedSeconds)
        }),
    ]))
}

private func makeSongs() -> Screen {
  var items = [MenuItem]()
  var track: Int32 = 1
  while track <= 30 {
    let number = track
    items.append(
      MenuItem(
        "Track ", number: number,
        action: .push {
          player.play(track: number)
          return makeNowPlaying()
        }))
    track &+= 1
  }
  return Screen(title: "Songs", content: .menu(items))
}

private func makeAlbums(_ title: StaticString, _ albums: [StaticString]) -> Screen {
  var items = [MenuItem]()
  for album in albums {
    items.append(MenuItem(album, action: .push { makeSongs() }))
  }
  return Screen(title: title, content: .menu(items))
}

private func makeArtists() -> Screen {
  Screen(
    title: "Artists",
    content: .menu([
      MenuItem(
        "Daft Punk",
        action: .push {
          makeAlbums("Daft Punk", ["Homework", "Discovery", "Random Access Memories"])
        }),
      MenuItem(
        "Gorillaz",
        action: .push { makeAlbums("Gorillaz", ["Gorillaz", "Demon Days", "Plastic Beach"]) }),
      MenuItem(
        "Kraftwerk",
        action: .push {
          makeAlbums("Kraftwerk", ["Autobahn", "The Man-Machine", "Computer World"])
        }),
      MenuItem(
        "Radiohead",
        action: .push { makeAlbums("Radiohead", ["OK Computer", "Kid A", "In Rainbows"]) }),
    ]))
}

private func makeMusic() -> Screen {
  Screen(
    title: "Music",
    content: .menu([
      MenuItem("Artists", action: .push { makeArtists() }),
      MenuItem(
        "Albums",
        action: .push {
          makeAlbums(
            "Albums",
            [
              "Homework", "Discovery", "Random Access Memories",
              "Gorillaz", "Demon Days", "Plastic Beach",
              "Autobahn", "The Man-Machine", "Computer World",
            ])
        }),
      MenuItem("Songs", action: .push { makeSongs() }),
      MenuItem(
        "Playlists",
        action: .push {
          Screen(title: "Playlists", content: .menu([MenuItem("No Playlists")]))
        }),
    ]))
}

private let mobyDick: StaticString = """
  CHAPTER 1. Loomings.

  Call me Ishmael. Some years ago - never mind how long precisely - having \
  little or no money in my purse, and nothing particular to interest me on \
  shore, I thought I would sail about a little and see the watery part of \
  the world. It is a way I have of driving off the spleen and regulating \
  the circulation.

  Whenever I find myself growing grim about the mouth; whenever it is a \
  damp, drizzly November in my soul; whenever I find myself involuntarily \
  pausing before coffin warehouses, and bringing up the rear of every \
  funeral I meet, I account it high time to get to sea as soon as I can.
  """

private func makeNotes() -> Screen {
  Screen(
    title: "Notes",
    content: .menu([
      MenuItem(
        "About Notes",
        action: .push {
          Screen(
            title: "About Notes",
            content: .text(
              """
              This is the Notes reader, running as a native Swift shared \
              library on Android.

              Rotate the click wheel (D-pad, or drag) to scroll line by \
              line; press Menu (or the system Back gesture) to go back.
              """))
        }),
      MenuItem(
        "Moby-Dick",
        action: .push { Screen(title: "Moby-Dick", content: .text(mobyDick)) }),
    ]))
}

private func makeExtras() -> Screen {
  Screen(
    title: "Extras",
    content: .menu([
      MenuItem("Clock", action: .push { Screen(title: "Clock", content: .menu([MenuItem("Clock")])) }),
      MenuItem("Games", action: .push { Screen(title: "Games", content: .menu([MenuItem("Games")])) }),
      MenuItem("Notes", action: .push { makeNotes() }),
    ]))
}

private func makeSettings() -> Screen {
  Screen(
    title: "Settings",
    content: .menu([
      MenuItem(
        "About",
        action: .push {
          Screen(
            title: "About",
            content: .menu([
              MenuItem("ClassicUI"),
              MenuItem("Songs: ", number: 90),
              MenuItem("Native Swift on Android"),
              MenuItem("Version 0.1"),
            ]))
        }),
      MenuItem(
        "Shuffle", action: .run { player.shuffle = !player.shuffle },
        detail: { player.shuffle ? "On" : "Off" }),
    ]))
}

private nonisolated(unsafe) let rootScreen = Screen(
  title: "iPod",
  content: .menu([
    MenuItem("Music", action: .push { makeMusic() }),
    MenuItem("Extras", action: .push { makeExtras() }),
    MenuItem("Settings", action: .push { makeSettings() }),
    MenuItem(
      "Shuffle Songs",
      action: .run {
        player.shuffle = true
        player.play(track: 1)
      }),
    MenuItem("Now Playing", action: .push { makeNowPlaying() }),
  ]))

private nonisolated(unsafe) let navigator = Navigator(root: rootScreen)

// MARK: - Input helpers (shared with the console ports' logic)

private func scroll(_ delta: Int32) {
  let top = navigator.top
  switch top.content {
  case .menu(let items):
    navigator.moveSelection(by: delta, rowCount: Int32(items.count), visibleRows: visibleRows)
  case .text(let text):
    let lineCount = textPageLineCount(text)
    let maxOffset = lineCount > visibleTextLines ? lineCount - visibleTextLines : 0
    navigator.moveSelection(by: delta, rowCount: maxOffset + 1, visibleRows: 1)
  case .stack:
    break
  }
  frameDirty = true
}

private func select() {
  guard case .menu(let items) = navigator.top.content else { return }
  let index = Int(navigator.top.selection)
  guard index >= 0, index < items.count else { return }
  switch items[index].action {
  case .none:
    break
  case .run(let action):
    action()
    frameDirty = true
  case .push(let makeScreen):
    beginSlide(push: true)
    navigator.push(makeScreen())
  }
}

private func back() {
  if navigator.pop() {
    beginSlide(push: false)
  }
}

/// Gamepad/keyboard mapping: A = select, B = Menu (back), D-pad up/down =
/// wheel, D-pad left/right and shoulders = previous/next track,
/// X/Y/Start = play/pause -- the same mapping as the desktop and
/// SpriteKit presenters.
private func handleButton(_ button: SDLGamepad.Button) {
  switch button {
  case .south: select()
  case .east: back()
  case .dpadUp: scroll(-1)
  case .dpadDown: scroll(1)
  case .dpadLeft, .leftShoulder:
    if player.playing {
      player.trackNumber = player.trackNumber == 1 ? player.trackCount : player.trackNumber - 1
      player.elapsedFrames = 0
      frameDirty = true
    }
  case .dpadRight, .rightShoulder:
    if player.playing {
      player.trackNumber = player.trackNumber % player.trackCount &+ 1
      player.elapsedFrames = 0
      frameDirty = true
    }
  case .west, .north, .start:
    player.playing.toggle()
    frameDirty = true
  default:
    break
  }
}

private func handleScancode(_ scancode: Scancode) {
  switch scancode {
  case .up: scroll(-1)
  case .down: scroll(1)
  case .return, .keypadEnter: select()
  case .escape, scancodeACBack: back()
  case .space: player.playing.toggle(); frameDirty = true
  case .left: handleButton(.leftShoulder)
  case .right: handleButton(.rightShoulder)
  default: break
  }
}

/// Touch mapping for phones without a gamepad: the screen is divided into
/// thirds top-to-bottom -- top third scrolls up, bottom third scrolls
/// down, the middle third selects.
private func handleTap(y: Float, windowHeight: Float) {
  guard windowHeight > 0 else { return }
  let fraction = y / windowHeight
  if fraction < 0.33 {
    scroll(-1)
  } else if fraction > 0.67 {
    scroll(1)
  } else {
    select()
  }
}

// MARK: - SDL entry point

@_cdecl("SDL_main")
public func classicUIAndroidMain(
  _ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
  guard (try? SDL.initialize(subSystems: [.video, .gamepad])) != nil else {
    return 1
  }
  defer { SDL.quit() }

  guard
    let window = try? SDLWindow(
      title: "ClassicUI",
      frame: (x: .centered, y: .centered, width: Int(iPodWidth), height: Int(iPodHeight)),
      options: [.resizable, .highPixelDensity]
    ),
    let renderer = try? SDLRenderer(window: window)
  else {
    return 1
  }

  try? renderer.setLogicalSize(width: iPodWidth, height: iPodHeight, presentation: .letterbox)

  guard
    let texture = try? SDLTexture(
      renderer: renderer, format: .argb8888, access: .streaming,
      width: Int(iPodWidth), height: Int(iPodHeight))
  else {
    return 1
  }
  try? texture.setScaleMode(.nearest)

  canvasPixelCount = Int(iPodWidth * iPodHeight)
  screen = Canvas(
    pixels: UnsafeMutablePointer<UInt32>.allocate(capacity: canvasPixelCount),
    width: iPodWidth, height: iPodHeight)
  outgoingBuffer = UnsafeMutablePointer<UInt32>.allocate(capacity: canvasPixelCount)
  presentBuffer = UnsafeMutablePointer<UInt32>.allocate(capacity: canvasPixelCount)

  var gamepads = [JoystickID: SDLGamepad]()
  var running = true
  var windowHeightPixels: Float = Float(iPodHeight)

  while running {
    while let event = SDL.pollEvent() {
      switch event {
      case .quit, .windowCloseRequested:
        running = false
      case .keyDown(let scancode, _):
        handleScancode(scancode)
      case .gamepadAdded(let joystickID):
        gamepads[joystickID] = try? SDLGamepad(joystickID: joystickID)
      case .gamepadRemoved(let joystickID):
        gamepads[joystickID] = nil
      case .gamepadButtonDown(_, let button):
        handleButton(button)
      case .mouseButtonDown(_, _, let y, _):
        // SDL surfaces Android touches as the primary mouse button
        windowHeightPixels = Float(window.drawableSize.height)
        handleTap(y: y, windowHeight: windowHeightPixels)
      default:
        break
      }
    }

    player.tick()
    if player.playing, case .stack = navigator.top.content {
      frameDirty = true
    }

    if slideProgress >= 0 {
      slideProgress &+= 5
      frameDirty = true
      if slideProgress >= 64 { slideProgress = -1 }
    }

    if frameDirty {
      frameDirty = false
      renderScreen(screen, screen: navigator.top, playing: player.playing)
      if slideProgress >= 0 {
        compositeSlide(
          present: presentBuffer, outgoing: outgoingBuffer, incoming: screen.pixels,
          width: iPodWidth, height: iPodHeight, p64: slideProgress, push: slidePush)
      } else {
        var i = 0
        while i < canvasPixelCount {
          presentBuffer[i] = screen.pixels[i]
          i += 1
        }
      }
      try? texture.update(pixels: UnsafeMutableRawPointer(presentBuffer), pitch: Int(iPodWidth) * 4)
    }

    try? renderer.setDrawColor(red: 0, green: 0, blue: 0)
    try? renderer.clear()
    try? renderer.copy(texture, angle: 0)
    renderer.present()

    SDL.delay(nanoseconds: 16_000_000)
  }

  return 0
}
