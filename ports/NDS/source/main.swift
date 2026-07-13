//---------------------------------------------------------------------------------
//
//  ClassicUI for Nintendo DS -- Embedded Swift ARM9 binary.
//
//  Both screens are 256x192. The bottom (touch) screen hosts the iPod UI
//  through the software rasterizer in Renderer.swift, drawn into a
//  double-buffered 16bpp bitmap background (map-base flip, same pattern
//  as junkbot-swift's ports/NDS). The top screen is a static banner with
//  the controls, drawn once into a second bitmap background.
//
//    D-pad up/down    rotate the click wheel
//    A                center button (select)
//    B                Menu (back), with the slide animation
//    X / Y            play/pause
//    L / R            previous / next track
//    START            exit
//
//---------------------------------------------------------------------------------

import NDS

// MARK: - Video setup

videoSetMode(MODE_5_2D.rawValue)
videoSetModeSub(MODE_5_2D.rawValue)
lcdMainOnBottom()
vramSetPrimaryBanks(
  VRAM_A_MAIN_BG_0x06000000, VRAM_B_MAIN_BG_0x06020000,
  VRAM_C_SUB_BG, VRAM_D_LCD)

let bg = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0)
/// The buffer currently being drawn into (the one NOT displayed).
var backBuffer = bgGetGfxPtr(bg)! + 256 * 256

func flipBuffers() {
  backBuffer = bgGetGfxPtr(bg)!
  // Each map base is 16KB; a 256x256x16bpp screen is 128KB = 8 bases.
  bgSetMapBase(bg, bgGetMapBase(bg) == 8 ? 0 : 8)
}

let canvasPixels = Int(iPodWidth * iPodHeight)
let renderCanvas = Canvas(
  pixels: UnsafeMutablePointer<UInt16>.allocate(capacity: canvasPixels),
  width: iPodWidth, height: iPodHeight)
let outgoingBuffer = UnsafeMutablePointer<UInt16>.allocate(capacity: canvasPixels)
let presentBuffer = UnsafeMutablePointer<UInt16>.allocate(capacity: canvasPixels)

/// Copies the composed frame into the (256-pixel-pitch) back buffer;
/// the canvas is 256 wide, so rows are contiguous halfword copies.
func uploadFrame() {
  var index = 0
  while index < canvasPixels {
    backBuffer[index] = presentBuffer[index]
    index += 1
  }
}

// MARK: - Top screen banner (drawn once into the sub background)

let topBg = bgInitSub(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0)
let topWidth: Int32 = 256
let topHeight: Int32 = 192
let topCanvas = Canvas(pixels: bgGetGfxPtr(topBg)!, width: topWidth, height: topHeight)

func drawBanner() {
  fillRect(topCanvas, x: 0, y: 0, width: topWidth, height: topHeight, color: rgb15(20, 20, 24))
  let white = rgb15(240, 240, 245)
  let gray = rgb15(140, 140, 150)
  drawText(topCanvas, "ClassicUI", x: 12, y: 20, color: white)
  drawText(topCanvas, "iPod Classic UI for Nintendo DS", x: 12, y: 40, color: gray)
  drawText(topCanvas, "Embedded Swift on the ARM9", x: 12, y: 56, color: gray)
  drawText(topCanvas, "D-PAD UP/DOWN  click wheel", x: 12, y: 92, color: white)
  drawText(topCanvas, "A  select    B  menu (back)", x: 12, y: 110, color: white)
  drawText(topCanvas, "X/Y  play/pause  L/R  track", x: 12, y: 128, color: white)
  drawText(topCanvas, "START  exit", x: 12, y: 146, color: white)
  drawText(topCanvas, "MillerTechnologyPeru/ClassicUI", x: 12, y: 172, color: gray)
}
drawBanner()

// MARK: - Player state

final class Player {
  var playing = false
  var shuffle = false
  var backlight = false
  var trackNumber: Int32 = 1
  let trackCount: Int32 = 90
  var elapsedFrames: Int32 = 0
  let durationSeconds: Int32 = 222

  var elapsedSeconds: Int32 { elapsedFrames / 60 }

  var permille: Int32 {
    (elapsedFrames &* 1000) / (durationSeconds &* 60)
  }

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

let player = Player()

// MARK: - Screens

func makeNowPlaying() -> Screen {
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

func makeSongs() -> Screen {
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

func makeAlbums(_ title: StaticString, _ albums: [StaticString]) -> Screen {
  var items = [MenuItem]()
  for album in albums {
    items.append(MenuItem(album, action: .push { makeSongs() }))
  }
  return Screen(title: title, content: .menu(items))
}

func makeArtists() -> Screen {
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

func makeMusic() -> Screen {
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

let mobyDick: StaticString = """
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

func makeNotes() -> Screen {
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
              This is the Notes reader, running as Embedded Swift on the \
              DS's ARM9.

              Rotate the click wheel (D-pad up/down) to scroll line by \
              line; press B to go back.
              """))
        }),
      MenuItem(
        "Moby-Dick",
        action: .push { Screen(title: "Moby-Dick", content: .text(mobyDick)) }),
    ]))
}

func makeExtras() -> Screen {
  Screen(
    title: "Extras",
    content: .menu([
      MenuItem("Clock", action: .push { Screen(title: "Clock", content: .menu([MenuItem("Clock")])) }),
      MenuItem("Games", action: .push { Screen(title: "Games", content: .menu([MenuItem("Games")])) }),
      MenuItem("Notes", action: .push { makeNotes() }),
    ]))
}

func makeSettings() -> Screen {
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
              MenuItem("Embedded Swift on ARM9"),
              MenuItem("Version 0.1"),
            ]))
        }),
      MenuItem(
        "Shuffle", action: .run { player.shuffle = !player.shuffle },
        detail: { player.shuffle ? "On" : "Off" }),
      MenuItem(
        "Backlight", action: .run { player.backlight = !player.backlight },
        detail: { player.backlight ? "On" : "Off" }),
    ]))
}

let rootScreen = Screen(
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

let navigator = Navigator(root: rootScreen)

// MARK: - Navigation slide state

var slideProgress: Int32 = -1  // -1 = idle, else 0...64
var slidePush = true
var frameDirty = true

func beginSlide(push: Bool) {
  // capture what is currently on screen as the outgoing frame
  var i = 0
  while i < canvasPixels {
    outgoingBuffer[i] = presentBuffer[i]
    i += 1
  }
  slidePush = push
  slideProgress = 0
  frameDirty = true
}

// MARK: - Input helpers

func rowCount(of screen: Screen) -> Int32 {
  switch screen.content {
  case .menu(let items): return Int32(items.count)
  case .text(let text): return textPageLineCount(text)
  case .stack: return 0
  }
}

func visibleCount(of screen: Screen) -> Int32 {
  switch screen.content {
  case .menu: return visibleRows
  case .text: return 1  // scroll line by line; selection is the top line
  case .stack: return 1
  }
}

func scroll(_ delta: Int32) {
  let screen = navigator.top
  switch screen.content {
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

func select() {
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

func back() {
  if navigator.pop() {
    beginSlide(push: false)
  }
}

// MARK: - Main loop

// key repeat for wheel scrolling: 360ms delay, 60ms interval (in frames)
var heldFrames: Int32 = 0
var lastPlayingSecond: Int32 = -1

// first frame
renderScreen(renderCanvas, screen: navigator.top, playing: player.playing)
var i = 0
while i < canvasPixels {
  presentBuffer[i] = renderCanvas.pixels[i]
  i += 1
}
uploadFrame()
flipBuffers()

/// Flip on the vblank after the upload, never mid-frame.
var pendingFlip = false

while pmMainLoop() {
  threadWaitForVBlank()
  if pendingFlip {
    flipBuffers()
    pendingFlip = false
  }
  scanKeys()
  let pressed = keysDown()
  let held = keysHeld()

  if pressed & KEY_START != 0 { break }

  // wheel: pressed edges plus a simple hold-to-repeat
  var wheelDelta: Int32 = 0
  if pressed & KEY_UP != 0 { wheelDelta = -1 }
  if pressed & KEY_DOWN != 0 { wheelDelta = 1 }
  if held & (KEY_UP | KEY_DOWN) != 0 {
    heldFrames &+= 1
    if heldFrames > 21, heldFrames % 4 == 0 {
      wheelDelta = held & KEY_UP != 0 ? -1 : 1
    }
  } else {
    heldFrames = 0
  }
  if wheelDelta != 0 { scroll(wheelDelta) }

  if pressed & KEY_A != 0 { select() }
  if pressed & KEY_B != 0 { back() }
  if pressed & (KEY_X | KEY_Y) != 0 {
    player.playing = !player.playing
    frameDirty = true
  }
  if pressed & KEY_L != 0, player.playing {
    player.trackNumber = player.trackNumber == 1 ? player.trackCount : player.trackNumber - 1
    player.elapsedFrames = 0
    frameDirty = true
  }
  if pressed & KEY_R != 0, player.playing {
    player.trackNumber = player.trackNumber % player.trackCount &+ 1
    player.elapsedFrames = 0
    frameDirty = true
  }

  // simulated playback: redraw when the visible second/progress changes
  player.tick()
  if player.playing, case .stack = navigator.top.content {
    if player.elapsedSeconds != lastPlayingSecond {
      lastPlayingSecond = player.elapsedSeconds
      frameDirty = true
    }
  }

  // navigation slide
  if slideProgress >= 0 {
    slideProgress &+= 5
    frameDirty = true
    if slideProgress >= 64 {
      slideProgress = -1
    }
  }

  if frameDirty {
    frameDirty = false
    renderScreen(renderCanvas, screen: navigator.top, playing: player.playing)
    if slideProgress >= 0 {
      compositeSlide(
        present: presentBuffer,
        outgoing: outgoingBuffer,
        incoming: renderCanvas.pixels,
        width: iPodWidth, height: iPodHeight,
        p64: slideProgress, push: slidePush)
    } else {
      var pixel = 0
      while pixel < canvasPixels {
        presentBuffer[pixel] = renderCanvas.pixels[pixel]
        pixel += 1
      }
    }
    uploadFrame()
    pendingFlip = true
  }
}
