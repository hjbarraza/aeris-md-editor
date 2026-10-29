import Foundation
import LibraryCore

@MainActor func runLibraryChecks() {
    typealias E = LibraryEntry
    check(LibraryListing.includes(name: "a.MD", isDirectory: false, isPackage: false, isHidden: false), "lib: .MD listed")
    check(LibraryListing.includes(name: "b.markdown", isDirectory: false, isPackage: false, isHidden: false), "lib: .markdown listed")
    check(LibraryListing.includes(name: "c.txt", isDirectory: false, isPackage: false, isHidden: false), "lib: .txt listed")
    check(!LibraryListing.includes(name: "d.json", isDirectory: false, isPackage: false, isHidden: false), "lib: .json not listed")
    check(!LibraryListing.includes(name: "md", isDirectory: false, isPackage: false, isHidden: false), "lib: bare name 'md' not listed")
    check(LibraryListing.includes(name: "notes.md", isDirectory: true, isPackage: false, isHidden: false), "lib: folder listed even with .md name")
    check(!LibraryListing.includes(name: "X.app", isDirectory: true, isPackage: true, isHidden: false), "lib: package not listed")
    check(!LibraryListing.includes(name: "Library", isDirectory: true, isPackage: false, isHidden: true), "lib: hidden folder not listed")
    check(LibraryListing.sorted([E(name: "Note 10.md", isDirectory: false), E(name: "Note 2.md", isDirectory: false)]).map(\.name)
          == ["Note 2.md", "Note 10.md"], "lib: numeric-aware order")
    check(LibraryListing.sorted([E(name: "a.md", isDirectory: false), E(name: "A.md", isDirectory: false)]).map(\.name)
          == ["A.md", "a.md"], "lib: case tie broken deterministically")
    check(LibraryListing.canonicalPath(URL(fileURLWithPath: "/tmp")) == "/private/tmp", "lib: canonical path keeps /private")
    let demo = URL(fileURLWithPath: "docs/demo-library")
    check(LibraryListing.entries(in: demo).map(\.name) == ["Drafts", "Notes", "Welcome.md"], "lib: demo root listing")
    check(LibraryListing.entries(in: demo.appending(path: "Notes")).map(\.name) == ["Archive", "Meeting.txt"],
          "lib: hidden and non-Markdown files filtered")
    check(LibraryListing.entries(in: demo.appending(path: "nope")).isEmpty, "lib: missing folder lists nothing")

    let fm = FileManager.default
    let tmp = fm.temporaryDirectory.appending(path: "mdcheck-lib-\(UUID().uuidString)")
    try? fm.createDirectory(at: tmp.appending(path: "Thing.app"), withIntermediateDirectories: true)
    fm.createFile(atPath: tmp.appending(path: "visible.md").path, contents: Data())
    fm.createFile(atPath: tmp.appending(path: "flagged.md").path, contents: Data())
    var flagged = tmp.appending(path: "flagged.md")
    var hidden = URLResourceValues(); hidden.isHidden = true
    try? flagged.setResourceValues(hidden)
    check(LibraryListing.entries(in: tmp).map(\.name) == ["visible.md"], "lib: package dir and flagged-hidden file filtered")

    let tree = LibraryTree(); tree.setRoots([demo])
    let root = tree.roots[0]
    check(root.children == nil && tree.loadedDirectoryPaths.isEmpty, "tree: nothing enumerated until asked")
    root.loadChildren()
    check(root.children?.map(\.name) == ["Drafts", "Notes", "Welcome.md"] && root.children?[1].children == nil,
          "tree: one level loaded lazily")
    check(root.children?[2].children?.isEmpty == true, "tree: a file has no children")
    check(root.children?[0].path == root.path + "/Drafts" && root.children?[0].parent === root, "tree: child path and parent")
    tree.setRoots([demo, tmp])
    check(tree.roots[0] === root && tree.roots.count == 2, "tree: existing root kept on setRoots")

    let t = LibraryTree(); t.setRoots([demo])
    let rootPath = LibraryListing.canonicalPath(demo)
    check(t.node(atPath: rootPath + "/Notes/Archive/Old note.md")?.name == "Old note.md", "tree: node(atPath:) loads ancestors")
    check(t.roots[0].children?.first { $0.name == "Notes" }?.children != nil, "tree: ancestors now loaded")
    check(t.node(atPath: rootPath + "/Notes/data.json") == nil, "tree: filtered file not found")
    check(t.node(atPath: "/elsewhere/x.md") == nil, "tree: path outside roots is nil")
    t.setRoots([demo, demo.appending(path: "Notes")])
    check(t.node(atPath: rootPath + "/Notes/Meeting.txt")?.parent === t.roots[1], "tree: nested location wins (longest prefix)")
    try? fm.removeItem(at: tmp)
}
