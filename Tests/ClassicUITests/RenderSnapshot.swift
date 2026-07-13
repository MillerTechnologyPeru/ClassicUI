//
//  RenderSnapshot.swift
//  ClassicUITests
//
//  Renders sample screens to PNG for visual inspection when
//  CLASSICUI_SNAPSHOT_DIR is set. Skipped otherwise.
//

import Foundation
import Testing
import Cairo
@testable import ClassicUICore

@Suite struct RenderSnapshotTests {

    @Test func snapshotMainMenu() throws {
        guard let directory = ProcessInfo.processInfo.environment["CLASSICUI_SNAPSHOT_DIR"] else {
            return
        }
        struct MainMenu: View {
            var body: some View {
                List {
                    NavigationLink("Music") { Text("Music") }
                    NavigationLink("Photos") { Text("Photos") }
                    NavigationLink("Videos") { Text("Videos") }
                    NavigationLink("Extras") { Text("Extras") }
                    NavigationLink("Settings") { Text("Settings") }
                    Button("Shuffle Songs") { }
                }
                .navigationTitle("iPod")
            }
        }
        let renderer = try ClassicRenderer(theme: .classic)
        let screen = Resolver.resolveScreen(MainMenu())
        renderer.render(screen: screen, selection: 0, scrollOffset: 0, isPlaying: true)
        renderer.surface.writePNG(atPath: directory + "/main-menu.png")

        // long list with scrolling
        struct Songs: View {
            var body: some View {
                List {
                    ForEach(1 ..< 31) { index in
                        Button("Track \(index) — A Longer Song Title That Truncates") { }
                    }
                }
                .navigationTitle("Songs")
            }
        }
        let songs = Resolver.resolveScreen(Songs())
        renderer.render(screen: songs, selection: 14, scrollOffset: 8, isPlaying: false)
        renderer.surface.writePNG(atPath: directory + "/songs.png")

        // settings screen with Toggle value text
        struct Settings: View {
            @State private var backlight = true
            var body: some View {
                List {
                    NavigationLink("About") { Text("About") }
                    Toggle("Shuffle", isOn: .constant(false))
                    Toggle("Backlight", isOn: $backlight)
                }
                .navigationTitle("Settings")
            }
        }
        let settings = Resolver.resolveScreen(Settings())
        renderer.render(screen: settings, selection: 1, scrollOffset: 0, isPlaying: false)
        renderer.surface.writePNG(atPath: directory + "/settings.png")

        // Notes-style multiline text page
        struct Note: View {
            var body: some View {
                Text("""
                Call me Ishmael. Some years ago—never mind how long precisely—having \
                little or no money in my purse, and nothing particular to interest me \
                on shore, I thought I would sail about a little and see the watery part \
                of the world. It is a way I have of driving off the spleen and \
                regulating the circulation.

                Whenever I find myself growing grim about the mouth; whenever it is a \
                damp, drizzly November in my soul; whenever I find myself involuntarily \
                pausing before coffin warehouses, and bringing up the rear of every \
                funeral I meet, I account it high time to get to sea as soon as I can.
                """)
                .navigationTitle("Moby-Dick")
            }
        }
        let note = Resolver.resolveScreen(Note())
        renderer.render(screen: note, selection: 2, scrollOffset: 0, isPlaying: false)
        renderer.surface.writePNG(atPath: directory + "/note.png")

        // Now Playing music player screen (VStack: no selection bar)
        struct NowPlaying: View {
            var body: some View {
                VStack {
                    Text("7 of 90")
                    Text("Harder, Better, Faster, Stronger")
                    Text("Daft Punk — Discovery")
                    ProgressView(value: 63.0, total: 222.0)
                    HStack {
                        Text("1:03")
                        Spacer()
                        Text("-2:39")
                    }
                }
                .navigationTitle("Now Playing")
            }
        }
        let nowPlaying = Resolver.resolveScreen(NowPlaying())
        renderer.render(screen: nowPlaying, selection: 0, scrollOffset: 0, isPlaying: true)
        renderer.surface.writePNG(atPath: directory + "/now-playing.png")

        // 2x (Retina) rendering: same logical UI, crisp at 640×480
        let retinaRenderer = try ClassicRenderer(theme: .classic, width: 640, height: 480)
        retinaRenderer.render(screen: screen, selection: 0, scrollOffset: 0, isPlaying: true)
        retinaRenderer.surface.writePNG(atPath: directory + "/main-menu-2x.png")

        // non-4:3 windows adapt: wider rows, or more visible rows
        let wideRenderer = try ClassicRenderer(theme: .classic, width: 800, height: 480)
        wideRenderer.render(screen: nowPlaying, selection: 0, scrollOffset: 0, isPlaying: true)
        wideRenderer.surface.writePNG(atPath: directory + "/now-playing-wide.png")

        let tallRenderer = try ClassicRenderer(theme: .classic, width: 640, height: 900)
        tallRenderer.render(screen: songs, selection: 14, scrollOffset: 8, isPlaying: false)
        tallRenderer.surface.writePNG(atPath: directory + "/songs-tall.png")

        // mid-slide navigation transition composite
        let classicScreen = try ClassicScreen {
            NavigationStack { MainMenu() }
        }
        classicScreen.renderIfNeeded()
        classicScreen.handle(.select)   // push "Music"
        classicScreen.frameTick(0.1)    // ~40% through the slide
        classicScreen.renderIfNeeded()
        classicScreen.withPixels { pixels, stride in
            if let composite = try? Cairo.Surface.Image(
                mutableBytes: pixels,
                format: .argb32,
                width: 320,
                height: 240,
                stride: stride
            ) {
                composite.writePNG(atPath: directory + "/transition.png")
            }
        }
    }
}
