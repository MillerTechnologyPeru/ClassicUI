import Testing
@testable import ClassicUICore

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
        // a bare Text destination resolves as a text page
        let screen = Resolver.resolveScreen(destination)
        guard case .text(let content) = screen.content else {
            Issue.record("expected text page content")
            return
        }
        #expect(content == "Destination")
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

    @Test func anyViewWrappedNavigationStackResolves() {
        // regression: ClassicApp wraps the root in AnyView
        let root: any View = NavigationStack {
            List { Text("Root") }.navigationTitle("iPod")
        }
        let screen = Resolver.resolveScreen(AnyView(root))
        #expect(screen.title == "iPod")
        #expect(screen.rows.map(\.text) == ["Root"])
    }

    @Test func bareTextScreenBecomesTextPage() {
        let screen = Resolver.resolveScreen(Text("Call me Ishmael."))
        #expect(screen.title == nil)
        guard case .text(let content) = screen.content else {
            Issue.record("expected text page content")
            return
        }
        #expect(content == "Call me Ishmael.")
        #expect(screen.rows.isEmpty)
    }

    @Test func titledTextScreen() {
        struct Note: View {
            var body: some View {
                Text("Some long note").navigationTitle("Notes")
            }
        }
        let screen = Resolver.resolveScreen(Note())
        #expect(screen.title == "Notes")
        guard case .text(let content) = screen.content else {
            Issue.record("expected text page content")
            return
        }
        #expect(content == "Some long note")
    }

    @Test func vStackScreenBecomesStack() {
        struct NowPlaying: View {
            var body: some View {
                VStack {
                    Text("Track 1")
                    ProgressView(value: 0.5)
                }
                .navigationTitle("Now Playing")
            }
        }
        let screen = Resolver.resolveScreen(NowPlaying())
        #expect(screen.title == "Now Playing")
        guard case .stack(let rows, let alignment, let spacing) = screen.content else {
            Issue.record("expected stack content")
            return
        }
        #expect(rows.map(\.text) == ["Track 1", ""])
        #expect(rows[1].progress == 0.5)
        #expect(alignment == .center)
        #expect(spacing == 0)
    }

    @Test func vStackAlignmentAndSpacingCarried() {
        let screen = Resolver.resolveScreen(
            VStack(alignment: .leading, spacing: 4) {
                Text("A")
            }
        )
        guard case .stack(_, let alignment, let spacing) = screen.content else {
            Issue.record("expected stack content")
            return
        }
        #expect(alignment == .leading)
        #expect(spacing == 4)
    }

    @Test func vStackInsideListFlattensToRows() {
        let screen = Resolver.resolveScreen(
            List {
                Text("Header")
                VStack {
                    Text("A")
                    Text("B")
                }
            }
        )
        #expect(screen.rows.map(\.text) == ["Header", "A", "B"])
    }

    @Test func hStackSplitsOnSpacer() {
        let result = rows {
            HStack {
                Text("Shuffle")
                Spacer()
                Text("Off")
            }
        }
        #expect(result.count == 1)
        #expect(result[0].text == "Shuffle")
        #expect(result[0].detail == "Off")
    }

    @Test func hStackWithoutSpacerJoinsText() {
        let result = rows {
            HStack {
                Text("Daft Punk")
                Text("—")
                Text("Discovery")
            }
        }
        #expect(result.count == 1)
        #expect(result[0].text == "Daft Punk — Discovery")
        #expect(result[0].detail == nil)
    }

    @Test func hStackLeadingSpacerRightAligns() {
        let result = rows {
            HStack {
                Spacer()
                Text("Right")
            }
        }
        #expect(result[0].text == "")
        #expect(result[0].detail == "Right")
    }

    @Test func hStackDonatesInteractiveKind() {
        var fired = false
        let result = rows {
            HStack {
                Button("Play") { fired = true }
                Spacer()
                Text("2:11")
            }
        }
        #expect(result[0].text == "Play")
        #expect(result[0].detail == "2:11")
        guard case .button(let action) = result[0].kind else {
            Issue.record("expected button row")
            return
        }
        action()
        #expect(fired)
    }

    @Test func hStackCarriesProgress() {
        let result = rows {
            HStack {
                Text("1:03")
                ProgressView(value: 0.25)
                Text("-2:39")
            }
        }
        #expect(result.count == 1)
        #expect(result[0].progress == 0.25)
    }

    @Test func progressViewRow() {
        let result = rows {
            ProgressView(value: 55.5, total: 222.0)
        }
        #expect(result.count == 1)
        #expect(result[0].progress == 0.25)
        guard case .inert = result[0].kind else {
            Issue.record("expected inert row")
            return
        }
    }

    @Test func progressViewClampsFraction() {
        let over = rows { ProgressView(value: 5.0, total: 2.0) }
        #expect(over[0].progress == 1)
        let indeterminate = rows { ProgressView(value: Optional<Double>.none) }
        #expect(indeterminate[0].progress == 0)
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
