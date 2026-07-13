//
//  Demo.swift
//  ClassicUIDemo
//
//  iPod Classic demo menu. Controls:
//    ↑/↓ or scroll wheel — rotate the click wheel
//    Return — center button   Escape — Menu (back)
//    Space — Play/Pause       ←/→ — Previous/Next track
//

import Foundation
import ClassicUI

// MARK: - Model

final class Player {
    var isPlaying = false
    var shuffle = false
}

struct Artist: Identifiable, Sendable {
    let name: String
    let albums: [String]
    var id: String { name }
}

let sampleArtists = [
    Artist(name: "Daft Punk", albums: ["Homework", "Discovery", "Random Access Memories"]),
    Artist(name: "Gorillaz", albums: ["Gorillaz", "Demon Days", "Plastic Beach"]),
    Artist(name: "Kraftwerk", albums: ["Autobahn", "The Man-Machine", "Computer World"]),
    Artist(name: "Radiohead", albums: ["OK Computer", "Kid A", "In Rainbows"]),
    Artist(name: "Stevie Wonder", albums: ["Talking Book", "Innervisions", "Songs in the Key of Life"])
]

// MARK: - Menus

struct MainMenu: View {
    let player: Player
    var body: some View {
        List {
            NavigationLink("Music") { MusicMenu(player: player) }
            NavigationLink("Extras") { ExtrasMenu() }
            NavigationLink("Settings") { SettingsMenu(player: player) }
            Button("Shuffle Songs") {
                player.shuffle = true
                player.isPlaying = true
            }
            if player.isPlaying {
                NavigationLink("Now Playing") { NowPlayingMenu(player: player) }
            }
        }
        .navigationTitle("iPod")
    }
}

struct MusicMenu: View {
    let player: Player
    var body: some View {
        List {
            NavigationLink("Artists") { ArtistsMenu() }
            NavigationLink("Albums") { AlbumsMenu() }
            NavigationLink("Songs") { SongsMenu() }
            NavigationLink("Playlists") { PlaylistsMenu() }
        }
        .navigationTitle("Music")
    }
}

struct ArtistsMenu: View {
    var body: some View {
        List(sampleArtists) { artist in
            NavigationLink(artist.name) { ArtistAlbumsMenu(artist: artist) }
        }
        .navigationTitle("Artists")
    }
}

struct ArtistAlbumsMenu: View {
    let artist: Artist
    var body: some View {
        List {
            NavigationLink("All") { SongsMenu() }
            ForEach(artist.albums, id: \.self) { album in
                NavigationLink(album) { SongsMenu() }
            }
        }
        .navigationTitle(artist.name)
    }
}

struct AlbumsMenu: View {
    var body: some View {
        List {
            ForEach(sampleArtists) { artist in
                ForEach(artist.albums, id: \.self) { album in
                    NavigationLink(album) { SongsMenu() }
                }
            }
        }
        .navigationTitle("Albums")
    }
}

struct SongsMenu: View {
    var body: some View {
        // long list to exercise scrolling and the scroll bar
        List {
            ForEach(1 ..< 31) { index in
                Button("Track \(index)") { }
            }
        }
        .navigationTitle("Songs")
    }
}

struct PlaylistsMenu: View {
    var body: some View {
        List {
            Text("No Playlists")
        }
        .navigationTitle("Playlists")
    }
}

struct ExtrasMenu: View {
    var body: some View {
        List {
            NavigationLink("Clock") { PlaceholderMenu(title: "Clock") }
            NavigationLink("Games") { PlaceholderMenu(title: "Games") }
            NavigationLink("Notes") { PlaceholderMenu(title: "Notes") }
        }
        .navigationTitle("Extras")
    }
}

struct SettingsMenu: View {
    let player: Player

    // screen-local state: resets when the screen is popped, like SwiftUI
    @State private var backlight = false
    @State private var clicks = 0

    var body: some View {
        List {
            NavigationLink("About") { AboutMenu() }
            // binding into external model state
            Toggle("Shuffle", isOn: Binding(
                get: { player.shuffle },
                set: { player.shuffle = $0 }
            ))
            // @State + projected $ binding
            Toggle("Backlight", isOn: $backlight)
            if backlight {
                Button("Clicker: \(clicks)") { clicks += 1 }
            }
        }
        .navigationTitle("Settings")
    }
}

struct AboutMenu: View {
    var body: some View {
        List {
            Text("ClassicUI")
            Text("Songs: 90")
            Text("Capacity: 160 GB")
            Text("Version: 0.1")
        }
        .navigationTitle("About")
    }
}

struct NowPlayingMenu: View {
    let player: Player
    var body: some View {
        List {
            Text("1 of 90")
            Text("Harder, Better, Faster, Stronger")
            Text("Daft Punk — Discovery")
        }
        .navigationTitle("Now Playing")
    }
}

struct PlaceholderMenu: View {
    let title: String
    var body: some View {
        List {
            Text(title)
        }
        .navigationTitle(title)
    }
}

// MARK: - Entry point

@main
struct ClassicUIDemo {

    static func main() throws {
        let player = Player()
        let app = ClassicApp {
            NavigationStack {
                MainMenu(player: player)
            }
        }
        app.onClickWheel = { event in
            if event == .playPause {
                player.isPlaying.toggle()
            }
            app.isPlaying = player.isPlaying
        }
        // headless smoke testing: CLASSICUI_FRAME_LIMIT=10 SDL_VIDEO_DRIVER=dummy
        let frameLimit = ProcessInfo.processInfo.environment["CLASSICUI_FRAME_LIMIT"].flatMap(Int.init)
        try app.run(frameLimit: frameLimit)
    }
}
