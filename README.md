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
let app = ClassicApp {
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
`Button`, `Text`, `ForEach` (`Identifiable`, `id:` key path, and ranges),
`EmptyView`, `AnyView`, and `.navigationTitle(_:)`.

Navigation behaves like the real device: selecting a `NavigationLink` pushes
its destination, the Menu button pops, and each screen's selection and scroll
position are restored when navigating back. Screens are re-resolved on every
input event, so dynamic content stays fresh.

## Click wheel controls

| Input | Click wheel |
|---|---|
| ↑ / ↓ or scroll wheel | Rotate wheel |
| Return | Center button (select) |
| Escape | Menu (back) |
| Space | Play/Pause |
| ← / → | Previous / Next track |

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
