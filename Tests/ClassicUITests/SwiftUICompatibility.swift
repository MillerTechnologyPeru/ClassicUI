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
#endif
