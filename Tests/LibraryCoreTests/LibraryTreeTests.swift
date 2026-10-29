import XCTest
@testable import LibraryCore

@MainActor
final class LibraryTreeTests: XCTestCase {
    func testLazyLoadingAndRootIdentity() throws {
        let demo = URL(fileURLWithPath: "docs/demo-library")
        let tmp = FileManager.default.temporaryDirectory
        let tree = LibraryTree(); tree.setRoots([demo])
        let root = tree.roots[0]
        XCTAssertNil(root.children)
        XCTAssertTrue(tree.loadedDirectoryPaths.isEmpty)
        root.loadChildren()
        XCTAssertEqual(root.children?.map(\.name), ["Drafts", "Notes", "Welcome.md"])
        XCTAssertNil(root.children?[1].children)
        XCTAssertEqual(root.children?[2].children?.isEmpty, true)
        XCTAssertEqual(root.children?[0].path, root.path + "/Drafts")
        XCTAssertTrue(root.children?[0].parent === root)
        tree.setRoots([demo, tmp])
        XCTAssertTrue(tree.roots[0] === root)
        XCTAssertEqual(tree.roots.count, 2)
    }

    func testNodeAtPath() throws {
        let demo = URL(fileURLWithPath: "docs/demo-library")
        let t = LibraryTree(); t.setRoots([demo])
        let rootPath = LibraryListing.canonicalPath(demo)
        XCTAssertEqual(t.node(atPath: rootPath + "/Notes/Archive/Old note.md")?.name, "Old note.md")
        XCTAssertNotNil(t.roots[0].children?.first { $0.name == "Notes" }?.children)
        XCTAssertNil(t.node(atPath: rootPath + "/Notes/data.json"))
        XCTAssertNil(t.node(atPath: "/elsewhere/x.md"))
        t.setRoots([demo, demo.appending(path: "Notes")])
        XCTAssertTrue(t.node(atPath: rootPath + "/Notes/Meeting.txt")?.parent === t.roots[1])
    }
}
