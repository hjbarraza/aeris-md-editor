import XCTest
@testable import LibraryCore

final class LocationStoreTests: XCTestCase {
    func testStoreLifecycle() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appending(path: "store-test-\(UUID().uuidString)")
        let folder = tmp.appending(path: "Notes")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let file = tmp.appending(path: "sub/Locations.plist")

        let s = LocationStore(fileURL: file); s.load()
        XCTAssertTrue(s.locations.isEmpty)
        XCTAssertTrue(try s.add(folder))
        XCTAssertFalse(try s.add(folder))
        let s2 = LocationStore(fileURL: file); s2.load()
        XCTAssertEqual(s2.locations.count, 1)
        XCTAssertEqual(s2.resolve(at: 0).map(LibraryListing.canonicalPath), LibraryListing.canonicalPath(folder))

        try fm.moveItem(at: folder, to: tmp.appending(path: "Renamed"))
        let s3 = LocationStore(fileURL: file); s3.load()
        XCTAssertEqual(s3.resolve(at: 0)?.lastPathComponent, "Renamed")
        XCTAssertTrue(s3.locations[0].path.hasSuffix("/Renamed"))
        let s3b = LocationStore(fileURL: file); s3b.load()
        XCTAssertTrue(s3b.locations[0].path.hasSuffix("/Renamed"))

        try fm.removeItem(at: tmp.appending(path: "Renamed"))
        let s4 = LocationStore(fileURL: file); s4.load()
        XCTAssertNil(s4.resolve(at: 0))
        XCTAssertEqual(s4.locations.count, 1)
        try s4.remove(at: 0)
        let s5 = LocationStore(fileURL: file); s5.load()
        XCTAssertTrue(s5.locations.isEmpty)

        let trashFile = tmp.appending(path: "trash.plist"), victim = tmp.appending(path: "Trashed-\(UUID().uuidString)")
        try fm.createDirectory(at: victim, withIntermediateDirectories: true)
        let t = LocationStore(fileURL: trashFile); t.load()
        _ = try t.add(victim)
        let original = t.locations[0]
        var trashed: NSURL?
        try fm.trashItem(at: victim, resultingItemURL: &trashed)
        let t2 = LocationStore(fileURL: trashFile); t2.load()
        XCTAssertNil(t2.resolve(at: 0))
        XCTAssertEqual(t2.locations[0], original)
        try fm.moveItem(at: try XCTUnwrap(trashed as URL?), to: victim)
        let t3 = LocationStore(fileURL: trashFile); t3.load()
        XCTAssertEqual(t3.resolve(at: 0).map(LibraryListing.canonicalPath), LibraryListing.canonicalPath(victim))

        try Data("garbage".utf8).write(to: file)
        let s6 = LocationStore(fileURL: file); s6.load()
        XCTAssertTrue(s6.locations.isEmpty)
        XCTAssertNil(s6.resolve(at: 3))
    }
}
