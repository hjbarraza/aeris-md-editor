import XCTest
@testable import LibraryCore

final class LibraryListingTests: XCTestCase {
    private func inc(_ name: String, dir: Bool = false, pkg: Bool = false, hidden: Bool = false) -> Bool {
        LibraryListing.includes(name: name, isDirectory: dir, isPackage: pkg, isHidden: hidden)
    }

    func testIncludes() {
        XCTAssertTrue(inc("a.MD"))
        XCTAssertTrue(inc("b.markdown"))
        XCTAssertTrue(inc("c.txt"))
        XCTAssertFalse(inc("d.json"))
        XCTAssertFalse(inc("md"))
        XCTAssertTrue(inc("notes.md", dir: true))
        XCTAssertFalse(inc("X.app", dir: true, pkg: true))
        XCTAssertFalse(inc("Library", dir: true, hidden: true))
    }

    func testSorted() {
        typealias E = LibraryEntry
        XCTAssertEqual(LibraryListing.sorted([E(name: "Note 10.md", isDirectory: false), E(name: "Note 2.md", isDirectory: false)]).map(\.name),
                       ["Note 2.md", "Note 10.md"])
        XCTAssertEqual(LibraryListing.sorted([E(name: "a.md", isDirectory: false), E(name: "A.md", isDirectory: false)]).map(\.name),
                       ["A.md", "a.md"])
    }

    func testCanonicalPath() {
        XCTAssertEqual(LibraryListing.canonicalPath(URL(fileURLWithPath: "/tmp")), "/private/tmp")
    }

    func testDemoLibraryListing() {
        let demo = URL(fileURLWithPath: "docs/demo-library")
        XCTAssertEqual(LibraryListing.entries(in: demo).map(\.name), ["Drafts", "Notes", "Welcome.md"])
        XCTAssertEqual(LibraryListing.entries(in: demo.appending(path: "Notes")).map(\.name), ["Archive", "Meeting.txt"])
        XCTAssertTrue(LibraryListing.entries(in: demo.appending(path: "nope")).isEmpty)
    }

    func testPackageAndFlaggedHiddenFiltered() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appending(path: "lib-test-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp.appending(path: "Thing.app"), withIntermediateDirectories: true)
        fm.createFile(atPath: tmp.appending(path: "visible.md").path, contents: Data())
        fm.createFile(atPath: tmp.appending(path: "flagged.md").path, contents: Data())
        var flagged = tmp.appending(path: "flagged.md")
        var hidden = URLResourceValues(); hidden.isHidden = true
        try flagged.setResourceValues(hidden)
        XCTAssertEqual(LibraryListing.entries(in: tmp).map(\.name), ["visible.md"])
    }
}
