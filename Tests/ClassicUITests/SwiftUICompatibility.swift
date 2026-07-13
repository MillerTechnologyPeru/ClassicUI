//
//  SwiftUICompatibility.swift
//  ClassicUITests
//
//  Compile-time proof that ClassicUI's API is a valid subset of SwiftUI:
//  this file deliberately imports ONLY SwiftUI (never ClassicUI) and
//  declares views using exactly the API shapes ClassicUI provides.
//  If it compiles, view code written for ClassicUI also compiles
//  against real SwiftUI.
//

#if canImport(SwiftUI)
import SwiftUI

private struct CompatArtist: Identifiable {
    let name: String
    var id: String { name }
}

private struct CompatArtistsMenu: SwiftUI.View {
    let artists: [CompatArtist]
    var body: some SwiftUI.View {
        List(artists) { artist in
            NavigationLink(artist.name) { CompatSongsMenu() }
        }
        .navigationTitle("Artists")
    }
}

private struct CompatSongsMenu: SwiftUI.View {
    var showsExtras = false
    var body: some SwiftUI.View {
        List {
            NavigationLink("All Songs") { Text("Songs") }
            Button("Shuffle Songs") { }
            ForEach(0 ..< 3) { index in
                Text("Track \(index)")
            }
            ForEach(["A", "B"], id: \.self) { name in
                Text(name)
            }
            if showsExtras {
                Text("Extras")
            } else {
                Text("No Extras")
            }
        }
        .navigationTitle("Songs")
    }
}

private struct CompatRoot: SwiftUI.View {
    var body: some SwiftUI.View {
        NavigationStack {
            CompatArtistsMenu(artists: [CompatArtist(name: "Daft Punk")])
        }
    }
}

private struct CompatSettingsMenu: SwiftUI.View {
    @State private var backlight = false
    @State private var count = 0
    var body: some SwiftUI.View {
        List {
            Toggle("Backlight", isOn: $backlight)
            CompatShuffleRow(isOn: $backlight)
            Button("Count: \(count)") { count += 1 }
        }
        .navigationTitle("Settings")
    }
}

private struct CompatShuffleRow: SwiftUI.View {
    @Binding var isOn: Bool
    var body: some SwiftUI.View {
        Toggle(isOn: $isOn) { Text("Shuffle") }
    }
}

private struct CompatBindingShapes {
    func exercise() {
        var flag = false
        let binding = Binding(get: { flag }, set: { flag = $0 })
        _ = binding.wrappedValue
        _ = binding.projectedValue
        _ = Binding.constant(1)
        struct Settings { var shuffle = false }
        var settings = Settings()
        let settingsBinding = Binding(get: { settings }, set: { settings = $0 })
        let _: Binding<Bool> = settingsBinding.shuffle
    }
}
#endif
