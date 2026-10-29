import XCTest
@testable import LibraryCore

@MainActor
final class FolderWatcherTests: XCTestCase {
    func testChangeReportedWithinOneSecondOnAliasedTempDir() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "aeris-watch-\(UUID())")  // /var alias of /private/var
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = LibraryListing.canonicalPath(dir)
        var got: [FolderChange] = []
        let w = FolderWatcher(paths: [path]) { got += $0 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let t0 = Date()
        FileManager.default.createFile(atPath: dir.appending(path: "new.md").path, contents: Data())
        while got.isEmpty && Date().timeIntervalSince(t0) < 1 { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertFalse(got.isEmpty)
        XCTAssertLessThan(Date().timeIntervalSince(t0), 1)
        XCTAssertEqual(RefreshPlan.directories(for: got, loaded: [path]), [path])
        XCTAssertTrue(got.allSatisfy { !$0.rootChanged })
        w.stop()
        got = []
        FileManager.default.createFile(atPath: dir.appending(path: "after-stop.md").path, contents: Data())
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        XCTAssertTrue(got.isEmpty)
    }
}
