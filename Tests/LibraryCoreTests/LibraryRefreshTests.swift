import XCTest
@testable import LibraryCore

@MainActor
final class LibraryRefreshTests: XCTestCase {
    private func fc(_ p: String, scan: Bool = false) -> FolderChange {
        FolderChange(path: p, mustScanSubDirs: scan, rootChanged: false)
    }
    private func f(_ n: String) -> LibraryEntry { LibraryEntry(name: n, isDirectory: false) }

    func testPlan() {
        XCTAssertEqual(RefreshPlan.directories(for: [fc("/r/a/")], loaded: ["/r", "/r/a"]), ["/r/a"])
        XCTAssertEqual(RefreshPlan.directories(for: [fc("/")], loaded: ["/"]), ["/"])
        XCTAssertTrue(RefreshPlan.directories(for: [fc("/r/x")], loaded: ["/r"]).isEmpty)
        XCTAssertEqual(RefreshPlan.directories(for: [fc("/r/a"), fc("/r/a"), fc("/r")], loaded: ["/r", "/r/a"]), ["/r", "/r/a"])
        XCTAssertEqual(RefreshPlan.directories(for: [fc("/r", scan: true)], loaded: ["/r", "/r/a", "/r/a/b", "/rr"]),
                       ["/r", "/r/a", "/r/a/b"])
        XCTAssertTrue(RefreshPlan.directories(for: [FolderChange(path: "/r", mustScanSubDirs: false, rootChanged: true)], loaded: ["/r"]).isEmpty)
        XCTAssertTrue(RefreshPlan.directories(for: [fc("/big/unloaded/deep", scan: true)], loaded: ["/r"]).isEmpty)
    }

    func testDiff() {
        let d = ChildDiff.diff(old: [f("a.md"), f("b.md"), f("c.md")], new: [f("a.md"), f("bb.md"), f("c.md"), f("d.md")])
        XCTAssertEqual(d.removed, IndexSet([1]))
        XCTAssertEqual(d.inserted, IndexSet([1, 3]))
        XCTAssertEqual(ChildDiff.diff(old: [], new: [f("a.md")]).inserted, IndexSet([0]))
        XCTAssertEqual(ChildDiff.diff(old: [f("a.md")], new: []).removed, IndexSet([0]))
        let same = ChildDiff.diff(old: [f("a.md")], new: [f("a.md")])
        XCTAssertTrue(same.removed.isEmpty && same.inserted.isEmpty)
        let kind = ChildDiff.diff(old: [f("x.md")], new: [LibraryEntry(name: "x.md", isDirectory: true)])
        XCTAssertEqual(kind.removed, IndexSet([0]))
        XCTAssertEqual(kind.inserted, IndexSet([0]))
    }

    func testRefreshKeepsIdentityAndSkipsDetached() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appending(path: "refresh-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp.appending(path: "sub"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        fm.createFile(atPath: tmp.appending(path: "a.md").path, contents: Data())
        fm.createFile(atPath: tmp.appending(path: "sub/s.md").path, contents: Data())
        let rootPath = LibraryListing.canonicalPath(tmp)
        let tree = LibraryTree(); tree.setRoots([tmp])
        tree.roots[0].loadChildren()
        let subNode = tree.roots[0].children![1]
        subNode.loadChildren()
        fm.createFile(atPath: tmp.appending(path: "b.md").path, contents: Data())
        try fm.removeItem(at: tmp.appending(path: "a.md"))
        fm.createFile(atPath: tmp.appending(path: "sub/t.md").path, contents: Data())
        let changes = tree.refresh([fc(rootPath), fc(rootPath + "/sub")])
        XCTAssertEqual(tree.roots[0].children?.map(\.name), ["b.md", "sub"])
        XCTAssertTrue(tree.roots[0].children?[1] === subNode)
        XCTAssertEqual(subNode.children?.map(\.name), ["s.md", "t.md"])
        XCTAssertEqual(changes.count, 2)
        XCTAssertTrue(changes[0].parent === tree.roots[0])
        XCTAssertTrue(tree.refresh([fc(rootPath)]).isEmpty)

        try fm.removeItem(at: tmp.appending(path: "sub"))
        let c2 = tree.refresh([fc(rootPath), fc(rootPath + "/sub")])
        XCTAssertEqual(c2.count, 1)
        XCTAssertEqual(tree.roots[0].children?.map(\.name), ["b.md"])

        try fm.createDirectory(at: tmp.appending(path: "cold"), withIntermediateDirectories: true)
        _ = tree.refresh([fc(rootPath)])
        let cold = try XCTUnwrap(tree.roots[0].children?.first { $0.name == "cold" })
        _ = tree.refresh([fc(rootPath + "/cold", scan: true)])
        XCTAssertNil(cold.children)
    }

    func testUnreadableFolderKeepsItsChildren() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appending(path: "unreadable-\(UUID().uuidString)")
        let locked = tmp.appending(path: "locked")
        try fm.createDirectory(at: locked, withIntermediateDirectories: true)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? fm.removeItem(at: tmp)
        }
        fm.createFile(atPath: locked.appending(path: "l.md").path, contents: Data())
        let tree = LibraryTree(); tree.setRoots([tmp])
        tree.roots[0].loadChildren()
        let node = try XCTUnwrap(tree.roots[0].children?.first)
        node.loadChildren()
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        XCTAssertNil(LibraryListing.read(locked))
        XCTAssertTrue(tree.refresh([fc(LibraryListing.canonicalPath(locked))]).isEmpty)
        XCTAssertEqual(node.children?.map(\.name), ["l.md"])
    }
}
