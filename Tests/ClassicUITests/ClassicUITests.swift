import Testing
@testable import ClassicUI

// MARK: - Helpers

private func rows(@ViewBuilder of content: () -> some View) -> [ResolvedRow] {
    var rows = [ResolvedRow]()
    Resolver.flattenRows(content(), into: &rows, context: ResolveContext())
    return rows
}

// MARK: - ViewBuilder / row flattening

@Suite struct ViewBuilderTests {

    @Test func emptyBlock() {
        #expect(rows { }.isEmpty)
    }

    @Test func singleText() {
        let result = rows { Text("Music") }
        #expect(result.count == 1)
        #expect(result[0].text == "Music")
    }

    @Test func tupleFlattening() {
        let result = rows {
            Text("A")
            Text("B")
            Text("C")
        }
        #expect(result.map(\.text) == ["A", "B", "C"])
    }

    @Test func conditionalTrueBranch() {
        let flag = true
        let result = rows {
            Text("Always")
            if flag {
                Text("True")
            } else {
                Text("False")
            }
        }
        #expect(result.map(\.text) == ["Always", "True"])
    }

    @Test func conditionalFalseBranch() {
        let flag = false
        let result = rows {
            if flag {
                Text("True")
            } else {
                Text("False")
            }
        }
        #expect(result.map(\.text) == ["False"])
    }

    @Test func optionalIf() {
        let flag = false
        let result = rows {
            Text("First")
            if flag {
                Text("Hidden")
            }
        }
        #expect(result.map(\.text) == ["First"])
    }

    @Test func forEachRange() {
        let result = rows {
            ForEach(0 ..< 3) { index in
                Text("Row \(index)")
            }
        }
        #expect(result.map(\.text) == ["Row 0", "Row 1", "Row 2"])
    }

    @Test func forEachIdentifiable() {
        struct Song: Identifiable {
            let id: Int
            let title: String
        }
        let songs = [Song(id: 1, title: "One"), Song(id: 2, title: "Two")]
        let result = rows {
            ForEach(songs) { song in
                Text(song.title)
            }
        }
        #expect(result.map(\.text) == ["One", "Two"])
    }

    @Test func forEachKeyPathID() {
        let names = ["Alpha", "Beta"]
        let result = rows {
            ForEach(names, id: \.self) { name in
                Text(name)
            }
        }
        #expect(result.map(\.text) == ["Alpha", "Beta"])
    }

    @Test func nestedForEach() {
        let result = rows {
            ForEach(0 ..< 2) { outer in
                ForEach(0 ..< 2) { inner in
                    Text("\(outer)-\(inner)")
                }
            }
        }
        #expect(result.map(\.text) == ["0-0", "0-1", "1-0", "1-1"])
    }

    @Test func customViewBodyIsWalked() {
        struct SongRow: View {
            let title: String
            var body: some View {
                Text(title)
            }
        }
        let result = rows {
            SongRow(title: "Custom")
            Text("Plain")
        }
        #expect(result.map(\.text) == ["Custom", "Plain"])
    }

    @Test func anyViewUnwraps() {
        let result = rows {
            AnyView(Text("Erased"))
        }
        #expect(result.map(\.text) == ["Erased"])
    }
}

// MARK: - Row kinds

@Suite struct RowKindTests {

    @Test func textRowIsInert() {
        let result = rows { Text("About") }
        guard case .inert = result[0].kind else {
            Issue.record("expected inert row")
            return
        }
    }

    @Test func buttonRowRunsAction() {
        var fired = false
        let result = rows {
            Button("Play") { fired = true }
        }
        #expect(result[0].text == "Play")
        guard case .button(let action) = result[0].kind else {
            Issue.record("expected button row")
            return
        }
        action()
        #expect(fired)
    }

    @Test func navigationRowCarriesDestination() {
        let result = rows {
            NavigationLink("Music") { Text("Destination") }
        }
        #expect(result[0].text == "Music")
        #expect(result[0].isNavigation)
        guard case .navigation(let destination) = result[0].kind else {
            Issue.record("expected navigation row")
            return
        }
        let screen = Resolver.resolveScreen(destination)
        #expect(screen.rows.map(\.text) == ["Destination"])
    }

    @Test func customButtonLabelText() {
        let result = rows {
            Button(action: { }) { Text("Custom Label") }
        }
        #expect(result[0].text == "Custom Label")
    }
}

// MARK: - Screen resolution

@Suite struct ResolverTests {

    @Test func listWithTitle() {
        struct Menu: View {
            var body: some View {
                List {
                    Text("A")
                    Text("B")
                }
                .navigationTitle("iPod")
            }
        }
        let screen = Resolver.resolveScreen(Menu())
        #expect(screen.title == "iPod")
        #expect(screen.rows.map(\.text) == ["A", "B"])
    }

    @Test func navigationStackUnwrapsToRoot() {
        struct Menu: View {
            var body: some View {
                List { Text("Root") }.navigationTitle("Title")
            }
        }
        let screen = Resolver.resolveScreen(NavigationStack { Menu() })
        #expect(screen.title == "Title")
        #expect(screen.rows.map(\.text) == ["Root"])
    }

    @Test func nestedCustomViews() {
        struct Inner: View {
            var body: some View {
                List { Text("Deep") }
            }
        }
        struct Outer: View {
            var body: some View {
                Inner()
            }
        }
        let screen = Resolver.resolveScreen(Outer())
        #expect(screen.rows.map(\.text) == ["Deep"])
    }

    @Test func listIdentifiableConvenienceInit() {
        struct Album: Identifiable {
            let id: Int
            let name: String
        }
        let albums = [Album(id: 1, name: "Discovery"), Album(id: 2, name: "Homework")]
        let screen = Resolver.resolveScreen(
            List(albums) { album in
                Text(album.name)
            }
        )
        #expect(screen.rows.map(\.text) == ["Discovery", "Homework"])
    }

    @Test func listKeyPathConvenienceInit() {
        let screen = Resolver.resolveScreen(
            List(["A", "B"], id: \.self) { name in
                Text(name)
            }
        )
        #expect(screen.rows.map(\.text) == ["A", "B"])
    }

    @Test func screenWithoutListStillResolves() {
        let screen = Resolver.resolveScreen(Text("Lonely"))
        #expect(screen.title == nil)
        #expect(screen.rows.map(\.text) == ["Lonely"])
    }
}

// MARK: - Navigation model

@Suite struct NavigationModelTests {

    @Test func startsAtRoot() {
        let model = NavigationModel(root: Text("Root"))
        #expect(model.depth == 1)
        #expect(model.top.selection == 0)
    }

    @Test func pushAndPop() {
        var model = NavigationModel(root: Text("Root"))
        model.push(Text("Child"))
        #expect(model.depth == 2)
        let popped = model.pop()
        #expect(popped)
        #expect(model.depth == 1)
        let poppedRoot = model.pop()  // can't pop the root
        #expect(!poppedRoot)
        #expect(model.depth == 1)
    }

    @Test func selectionRestoredAfterPop() {
        var model = NavigationModel(root: Text("Root"))
        model.moveSelection(by: 3, rowCount: 10, visibleRows: 9)
        #expect(model.top.selection == 3)
        model.push(Text("Child"))
        #expect(model.top.selection == 0)
        model.pop()
        #expect(model.top.selection == 3)
    }

    @Test func selectionClampsAtEdges() {
        var model = NavigationModel(root: Text("Root"))
        model.moveSelection(by: -5, rowCount: 3, visibleRows: 9)
        #expect(model.top.selection == 0)
        model.moveSelection(by: 100, rowCount: 3, visibleRows: 9)
        #expect(model.top.selection == 2)
    }

    @Test func clampAfterRowCountShrinks() {
        var model = NavigationModel(root: Text("Root"))
        model.moveSelection(by: 8, rowCount: 20, visibleRows: 9)
        #expect(model.top.selection == 8)
        model.clampSelection(rowCount: 4, visibleRows: 9)
        #expect(model.top.selection == 3)
        #expect(model.top.scrollOffset == 0)
    }

    @Test func scrollFollowsSelectionDown() {
        var model = NavigationModel(root: Text("Root"))
        for _ in 0 ..< 12 {
            model.moveSelection(by: 1, rowCount: 30, visibleRows: 9)
        }
        #expect(model.top.selection == 12)
        // selection must be within the visible window
        #expect(model.top.scrollOffset == 12 - 9 + 1)
    }

    @Test func scrollFollowsSelectionUp() {
        var model = NavigationModel(root: Text("Root"))
        model.moveSelection(by: 20, rowCount: 30, visibleRows: 9)
        model.moveSelection(by: -20, rowCount: 30, visibleRows: 9)
        #expect(model.top.selection == 0)
        #expect(model.top.scrollOffset == 0)
    }

    @Test func scrollOffsetWindowMath() {
        // selection above window scrolls up to it
        #expect(NavigationModel.scrollOffset(selection: 2, current: 5, rowCount: 30, visibleRows: 9) == 2)
        // selection inside window keeps offset
        #expect(NavigationModel.scrollOffset(selection: 7, current: 5, rowCount: 30, visibleRows: 9) == 5)
        // selection below window scrolls down just enough
        #expect(NavigationModel.scrollOffset(selection: 14, current: 5, rowCount: 30, visibleRows: 9) == 6)
        // offset never exceeds rowCount - visibleRows
        #expect(NavigationModel.scrollOffset(selection: 29, current: 29, rowCount: 30, visibleRows: 9) == 21)
        // short lists never scroll
        #expect(NavigationModel.scrollOffset(selection: 2, current: 0, rowCount: 3, visibleRows: 9) == 0)
    }
}
