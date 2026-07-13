# ClassicUI

A reimplementation of the iPod Classic (6th generation) UI in Swift, rendered
with SDL3 and [Silica](https://github.com/PureSwift/Silica), exposing a
**SwiftUI-compatible API** for building menus with click-wheel navigation.
Intended as the UI foundation for an open source Apple Music client.

The public view API is a valid subset of SwiftUI — the same view code
compiles unchanged against real SwiftUI:

```swift
import ClassicUI   // or: import SwiftUI

struct MainMenu: View {
    var body: some View {
        List {
            NavigationLink("Music") { MusicMenu() }
            NavigationLink("Settings") { SettingsMenu() }
            Button("Shuffle Songs") { player.shuffleAll() }
            ForEach(playlists) { playlist in
                NavigationLink(playlist.name) { PlaylistView(playlist) }
            }
        }
        .navigationTitle("iPod")
    }
}
```

Only the bootstrap is ClassicUI-specific:

```swift
let app = SDL3Renderer {
    NavigationStack { MainMenu() }
}
app.onClickWheel = { event in
    if event == .playPause { /* toggle playback */ }
}
try app.run()
```

## Supported SwiftUI subset (v1)

`View`, `@ViewBuilder` (including `if`/`else` and optionals), `List`
(content and data-driven initializers), `NavigationStack`, `NavigationLink`,
`Button`, `Text`, `Toggle`, `VStack(alignment:spacing:)` (pushed as a screen
it renders non-interactive stacked content with no selection bar — how
Now Playing screens are built; inside a `List` it flattens into rows),
`HStack(alignment:spacing:)` and `Spacer` (an `HStack` collapses into one
row: content before a `Spacer` is leading, after it right-aligned — the
`Text / Spacer / Text` value-row idiom; an interactive child donates its
behavior to the row), `ProgressView(value:total:)`, `ForEach`
(`Identifiable`, `id:` key path, and ranges), `EmptyView`, `AnyView`,
`.navigationTitle(_:)`, `.onAppear(perform:)` (fires when a screen is first
rendered, pushed, or revealed again by a pop — use it to start playback when
a Now Playing screen appears), `.onDisappear(perform:)` (fires when a screen
is covered by a push or removed by a pop), `.task(priority:_:)` (starts an
async task on appearance, cancels it on disappearance, restarts on
reappearance — `@State` writes and `@Observable` mutations from tasks
re-render the screen), and state management with `@State` and `@Binding`
(including `Binding.constant`, `init(get:set:)`, and key-path bindings via
dynamic member lookup).

A **bare `Text` pushed as a screen** (not inside a `List`) renders as a
scrollable page of word-wrapped text, like the iPod Notes app — the click
wheel scrolls line by line. A determinate `ProgressView` renders as the
classic Now Playing progress bar.

`@State` matches SwiftUI semantics: views are value types rebuilt on every
update, while state is persisted per screen keyed by the view's structural
identity — switching an `if`/`else` branch resets state, sibling views of the
same type keep independent state, and popping a screen discards its state.
`Toggle` renders as an iPod settings row with a right-aligned "On"/"Off"
value; the center button flips it.

`@Observable` view models are supported: the run loop tracks observable
reads during body evaluation (via `withObservationTracking`), so mutating a
view model re-renders the visible screen even without an input event. The
Observation module ships with the Swift toolchain itself, so this works on
Linux too — it is not an Apple-only framework.

Navigation behaves like the real device: selecting a `NavigationLink` pushes
its destination with an ease-out slide from the right (Menu pops with a slide
from the left; `transitionDuration` configures or disables it), and each
screen's selection and scroll position are restored when navigating back. Screens are re-resolved on every
input event, so dynamic content stays fresh.

The UI uses a logical 320×240 coordinate system (the real device screen) as
its minimum size but renders at the window's native pixel size, Retina
included: the framebuffer tracks the window and the logical UI scales through
the Cairo transform, so text and vector chrome stay crisp at any size. The
layout adapts to any aspect ratio — wider windows get wider rows, taller
windows show more rows. Navigation slides animate only the content area; the
status bar stays pinned.

## Click wheel controls

| Input | Click wheel |
|---|---|
| ↑ / ↓ or scroll wheel | Rotate wheel |
| Return | Center button (select) |
| Escape | Menu (back) |
| Space | Play/Pause |
| ← / → | Previous / Next track |

## Package layout

- **ClassicUICore** — the SwiftUI-subset view layer, resolver, navigation
  model, and Silica/Cairo renderer, exposed through the platform-agnostic
  `ClassicScreen` controller (framebuffer + click-wheel input). No SDL.
- **ClassicUI** — the SDL3 presenter (`SDL3Renderer`, built on PureSwift/SDL's `SDL3Swift` bindings); re-exports Core.
- **ClassicUISpriteKit** — a SpriteKit presenter (`ClassicScene`, an
  `SKScene`) for Apple platforms; re-exports Core.
- **ports/Darwin** — a macOS Xcode project hosting `ClassicScene` in an
  `SKView`, no SDL dependency. Build with
  `xcodebuild -project ports/Darwin/ClassicUIDarwin.xcodeproj -scheme ClassicUIDarwin`
  or open it in Xcode.

## Requirements

- macOS 13+ (Linux support planned; system-library targets already declare apt providers)
- SDL3, Cairo, and FontConfig:

```sh
brew install sdl3 cairo fontconfig
```

## Demo

```sh
swift run ClassicUIDemo
```

## Testing

The view resolver and navigation model are pure Swift and run headless:

```sh
swift test
```

Render snapshots (PNG dumps of composed screens) can be generated with
`CLASSICUI_SNAPSHOT_DIR=/tmp/snapshots swift test --filter RenderSnapshotTests`,
and the demo can run headless with
`SDL_VIDEO_DRIVER=dummy CLASSICUI_FRAME_LIMIT=10 swift run ClassicUIDemo`.
