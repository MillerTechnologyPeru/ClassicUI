//
//  AppMain.swift
//  ClassicUIDarwin
//
//  macOS host for the SpriteKit presenter: an NSWindow with an SKView
//  presenting ClassicScene. Same click-wheel controls as the SDL demo:
//  ↑/↓/scroll = wheel, Return = select, Escape = Menu, Space = Play/Pause,
//  ←/→ = Previous/Next.
//

import AppKit
import SpriteKit
import Observation
import ClassicUISpriteKit

// MARK: - View models

@Observable
final class PlayerViewModel {

    var isPlaying = false
    var shuffle = false
    var currentTrack: String?
    var trackNumber = 1
    let trackCount = 90
    var elapsed: TimeInterval = 0
    let duration: TimeInterval = 222

    func playPause() {
        isPlaying.toggle()
        if currentTrack == nil {
            currentTrack = "Harder, Better, Faster, Stronger"
        }
    }

    func tick(_ delta: TimeInterval) {
        guard isPlaying else { return }
        elapsed += delta
        if elapsed >= duration {
            elapsed = 0
            trackNumber = trackNumber % trackCount + 1
        }
    }
}

// MARK: - Menus

struct MainMenu: View {
    let player: PlayerViewModel
    var body: some View {
        List {
            NavigationLink("Music") { MusicMenu() }
            NavigationLink("Notes") { NotesMenu() }
            NavigationLink("Settings") { SettingsMenu(player: player) }
            Button("Shuffle Songs") {
                player.shuffle = true
                player.playPause()
            }
            if player.isPlaying {
                NavigationLink("Now Playing") { NowPlayingView(player: player) }
            }
        }
        .navigationTitle("iPod")
    }
}

struct MusicMenu: View {
    var body: some View {
        List {
            ForEach(["Daft Punk", "Gorillaz", "Kraftwerk", "Radiohead"], id: \.self) { artist in
                NavigationLink(artist) {
                    List {
                        ForEach(1 ..< 13) { index in
                            Button("Track \(index)") { }
                        }
                    }
                    .navigationTitle(artist)
                }
            }
        }
        .navigationTitle("Artists")
    }
}

struct NotesMenu: View {
    var body: some View {
        List {
            NavigationLink("Moby-Dick") {
                Text("""
                Call me Ishmael. Some years ago—never mind how long \
                precisely—having little or no money in my purse, and nothing \
                particular to interest me on shore, I thought I would sail \
                about a little and see the watery part of the world. It is a \
                way I have of driving off the spleen and regulating the \
                circulation.

                Whenever I find myself growing grim about the mouth; whenever \
                it is a damp, drizzly November in my soul; whenever I find \
                myself involuntarily pausing before coffin warehouses, and \
                bringing up the rear of every funeral I meet, I account it \
                high time to get to sea as soon as I can.
                """)
                .navigationTitle("Moby-Dick")
            }
        }
        .navigationTitle("Notes")
    }
}

struct SettingsMenu: View {
    let player: PlayerViewModel
    @State private var backlight = false
    var body: some View {
        List {
            Toggle("Shuffle", isOn: Binding(
                get: { player.shuffle },
                set: { player.shuffle = $0 }
            ))
            Toggle("Backlight", isOn: $backlight)
        }
        .navigationTitle("Settings")
    }
}

struct NowPlayingView: View {
    let player: PlayerViewModel
    var body: some View {
        VStack {
            Text("\(player.trackNumber) of \(player.trackCount)")
            Text(player.currentTrack ?? "Nothing Playing")
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

// MARK: - App bootstrap

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct ClassicUIDarwinApp {

    @MainActor
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate

        let player = PlayerViewModel()
        let scene = try ClassicScene {
            NavigationStack {
                MainMenu(player: player)
            }
        }
        scene.screen.onClickWheel = { event in
            switch event {
            case .playPause: player.playPause()
            default: break
            }
            scene.screen.isPlaying = player.isPlaying
        }
        scene.screen.onFrame = { delta in
            player.tick(delta)
        }

        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 480)
        let view = SKView(frame: contentRect)
        view.presentScene(scene)

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "iPod"
        window.contentMinSize = NSSize(width: 320, height: 240)
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(scene)

        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(title: "Quit iPod", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        appMenuItem.submenu = appMenu
        app.mainMenu = mainMenu

        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
