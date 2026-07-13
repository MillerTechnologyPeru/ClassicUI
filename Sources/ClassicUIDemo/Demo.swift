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
import Observation
import ClassicUI

// MARK: - Model

struct Artist: Identifiable, Sendable {
    let name: String
    let albums: [String]
    var id: String { name }
}

// MARK: - View models

/// Playback state. `@Observable` mutations re-render the visible screen
/// automatically — the run loop tracks reads during body evaluation.
@Observable
final class PlayerViewModel {

    var isPlaying = false
    var shuffle = false
    var repeatEnabled = false
    var currentTrack: String?
    var artist = "Daft Punk"
    var album = "Discovery"
    var trackNumber = 1
    let trackCount = 90

    /// Playback position in seconds, advanced from the frame tick.
    var elapsed: TimeInterval = 0
    let duration: TimeInterval = 222

    func playPause() {
        isPlaying.toggle()
        if currentTrack == nil {
            currentTrack = "Harder, Better, Faster, Stronger"
        }
    }

    func shuffleAll() {
        shuffle = true
        isPlaying = true
        currentTrack = "Harder, Better, Faster, Stronger"
    }

    func nextTrack() {
        guard isPlaying else { return }
        trackNumber = trackNumber % trackCount + 1
        elapsed = 0
    }

    func previousTrack() {
        guard isPlaying else { return }
        trackNumber = trackNumber == 1 ? trackCount : trackNumber - 1
        elapsed = 0
    }

    func play(track number: Int, title: String) {
        trackNumber = number
        currentTrack = title
        elapsed = 0
        isPlaying = true
    }

    /// Simulates playback; call once per frame.
    func tick(_ delta: TimeInterval) {
        guard isPlaying else { return }
        elapsed += delta
        if elapsed >= duration {
            elapsed = 0
            nextTrack()
        }
    }
}

/// A pretend remote music library, for demonstrating async loading
/// with `.task`.
enum MusicDatabase {

    static func fetchArtists() async -> [Artist] {
        try? await Task.sleep(nanoseconds: 600_000_000)
        return [
            Artist(name: "Daft Punk", albums: ["Homework", "Discovery", "Random Access Memories"]),
            Artist(name: "Gorillaz", albums: ["Gorillaz", "Demon Days", "Plastic Beach"]),
            Artist(name: "Kraftwerk", albums: ["Autobahn", "The Man-Machine", "Computer World"]),
            Artist(name: "Radiohead", albums: ["OK Computer", "Kid A", "In Rainbows"]),
            Artist(name: "Stevie Wonder", albums: ["Talking Book", "Innervisions", "Songs in the Key of Life"])
        ]
    }

    static func fetchAlbums() async -> [String] {
        await fetchArtists().flatMap(\.albums)
    }
}

// MARK: - Menus

struct MainMenu: View {
    let player: PlayerViewModel
    var body: some View {
        List {
            NavigationLink("Music") { MusicMenu(player: player) }
            NavigationLink("Extras") { ExtrasMenu() }
            NavigationLink("Settings") { SettingsMenu(player: player) }
            Button("Shuffle Songs") { player.shuffleAll() }
            if player.isPlaying {
                NavigationLink("Now Playing") { NowPlayingView(player: player) }
            }
        }
        .navigationTitle("iPod")
    }
}

struct MusicMenu: View {
    let player: PlayerViewModel
    var body: some View {
        List {
            NavigationLink("Artists") { ArtistsMenu() }
            NavigationLink("Albums") { AlbumsMenu() }
            NavigationLink("Songs") { SongsMenu(player: player) }
            NavigationLink("Playlists") { PlaylistsMenu() }
        }
        .navigationTitle("Music")
    }
}

/// Async loading with `.task`: shows "Loading…" until the fetch lands,
/// then re-renders. The task is cancelled if the screen is left early
/// and restarts when it appears again.
struct ArtistsMenu: View {
    @State private var artists: [Artist] = []
    var body: some View {
        List {
            if artists.isEmpty {
                Text("Loading…")
            }
            ForEach(artists) { artist in
                NavigationLink(artist.name) { ArtistAlbumsMenu(artist: artist) }
            }
        }
        .navigationTitle("Artists")
        .task {
            artists = await MusicDatabase.fetchArtists()
        }
    }
}

struct ArtistAlbumsMenu: View {
    let artist: Artist
    var body: some View {
        List {
            NavigationLink("All") { PlaceholderMenu(title: artist.name) }
            ForEach(artist.albums, id: \.self) { album in
                NavigationLink(album) { PlaceholderMenu(title: album) }
            }
        }
        .navigationTitle(artist.name)
    }
}

struct AlbumsMenu: View {
    @State private var albums: [String] = []
    var body: some View {
        List {
            if albums.isEmpty {
                Text("Loading…")
            }
            ForEach(albums, id: \.self) { album in
                NavigationLink(album) { PlaceholderMenu(title: album) }
            }
        }
        .navigationTitle("Albums")
        .task {
            albums = await MusicDatabase.fetchAlbums()
        }
    }
}

struct SongsMenu: View {
    let player: PlayerViewModel
    var body: some View {
        // long list to exercise scrolling and the scroll bar; selecting a
        // track pushes Now Playing and starts playback, like the real iPod
        List {
            ForEach(1 ..< 31) { index in
                NavigationLink("Track \(index)") {
                    NowPlayingView(player: player)
                        .onAppear {
                            player.play(track: index, title: "Track \(index)")
                        }
                }
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
            NavigationLink("Notes") { NotesMenu() }
        }
        .navigationTitle("Extras")
    }
}

/// Multiline text screens: a bare `Text` destination renders as a
/// scrollable page of wrapped text, like the iPod Notes app.
struct NotesMenu: View {
    var body: some View {
        List {
            NavigationLink("About Notes") {
                Text(Note.about).navigationTitle("About Notes")
            }
            NavigationLink("Moby-Dick") {
                Text(Note.mobyDick).navigationTitle("Moby-Dick")
            }
        }
        .navigationTitle("Notes")
    }
}

enum Note {

    static let about = """
    This is the Notes reader.

    Push a note from the menu and it renders as a page of word-wrapped \
    text instead of a list. Rotate the click wheel to scroll line by \
    line; press Menu to go back.

    Long documents get a proportional scroll bar on the right, just \
    like menus do.
    """

    static let mobyDick = """
    CHAPTER 1. Loomings.

    Call me Ishmael. Some years ago—never mind how long precisely—having \
    little or no money in my purse, and nothing particular to interest me \
    on shore, I thought I would sail about a little and see the watery \
    part of the world. It is a way I have of driving off the spleen and \
    regulating the circulation.

    Whenever I find myself growing grim about the mouth; whenever it is \
    a damp, drizzly November in my soul; whenever I find myself \
    involuntarily pausing before coffin warehouses, and bringing up the \
    rear of every funeral I meet; and especially whenever my hypos get \
    such an upper hand of me, that it requires a strong moral principle \
    to prevent me from deliberately stepping into the street, and \
    methodically knocking people's hats off—then, I account it high time \
    to get to sea as soon as I can.

    This is my substitute for pistol and ball. With a philosophical \
    flourish Cato throws himself upon his sword; I quietly take to the \
    ship. There is nothing surprising in this. If they but knew it, \
    almost all men in their degree, some time or other, cherish very \
    nearly the same feelings towards the ocean with me.
    """
}

struct SettingsMenu: View {
    let player: PlayerViewModel

    // screen-local state: resets when the screen is popped, like SwiftUI
    @State private var backlight = false
    @State private var clicks = 0

    var body: some View {
        List {
            NavigationLink("About") { AboutMenu(player: player) }
            // bindings into the observable view model
            Toggle("Shuffle", isOn: Binding(
                get: { player.shuffle },
                set: { player.shuffle = $0 }
            ))
            Toggle("Repeat", isOn: Binding(
                get: { player.repeatEnabled },
                set: { player.repeatEnabled = $0 }
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
    let player: PlayerViewModel
    var body: some View {
        List {
            Text("ClassicUI")
            Text("Songs: \(player.trackCount)")
            Text("Capacity: 160 GB")
            Text("Version: 0.1")
        }
        .navigationTitle("About")
    }
}

/// The music player screen: a VStack renders as non-interactive stacked
/// content (no selection bar), with track info and a live progress bar
/// driven by the observable view model (updates every frame while
/// playing, with no input events).
struct NowPlayingView: View {
    let player: PlayerViewModel
    var body: some View {
        VStack {
            Text("\(player.trackNumber) of \(player.trackCount)")
            Text(player.currentTrack ?? "Nothing Playing")
            Text("\(player.artist) — \(player.album)")
            ProgressView(value: player.elapsed, total: player.duration)
            HStack {
                Text(Self.timestamp(player.elapsed))
                Spacer()
                Text("-" + Self.timestamp(player.duration - player.elapsed))
            }
        }
        .navigationTitle("Now Playing")
    }

    static func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return "\(total / 60):" + String(format: "%02d", total % 60)
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
        let player = PlayerViewModel()
        let app = SDL3Renderer {
            NavigationStack {
                MainMenu(player: player)
            }
        }
        app.onClickWheel = { event in
            switch event {
            case .playPause: player.playPause()
            case .nextTrack: player.nextTrack()
            case .previousTrack: player.previousTrack()
            default: break
            }
        }
        // simulated playback progress, rendered live via @Observable tracking;
        // also keeps the status-bar play glyph in sync
        app.onFrame = { delta in
            player.tick(delta)
            app.isPlaying = player.isPlaying
        }
        // headless smoke testing: CLASSICUI_FRAME_LIMIT=10 SDL_VIDEO_DRIVER=dummy
        let frameLimit = ProcessInfo.processInfo.environment["CLASSICUI_FRAME_LIMIT"].flatMap(Int.init)
        try app.run(frameLimit: frameLimit)
    }
}
