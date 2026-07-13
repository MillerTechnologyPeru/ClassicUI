//
//  RenderSnapshot.swift
//  ClassicUITests
//
//  Renders sample screens to PNG for visual inspection when
//  CLASSICUI_SNAPSHOT_DIR is set. Skipped otherwise.
//

import Foundation
import Testing
@testable import ClassicUI

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
    }
}
