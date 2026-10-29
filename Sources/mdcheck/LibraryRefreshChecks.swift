import Foundation
import LibraryCore

@MainActor func runLibraryRefreshChecks() {
    func fc(_ p: String, scan: Bool = false) -> FolderChange { FolderChange(path: p, mustScanSubDirs: scan, rootChanged: false) }
    check(RefreshPlan.directories(for: [fc("/r/a/")], loaded: ["/r", "/r/a"]) == ["/r/a"], "plan: trailing slash stripped")
    check(RefreshPlan.directories(for: [fc("/")], loaded: ["/"]) == ["/"], "plan: bare / kept")
    check(RefreshPlan.directories(for: [fc("/r/x")], loaded: ["/r"]).isEmpty, "plan: unloaded folder ignored")
    check(RefreshPlan.directories(for: [fc("/r/a"), fc("/r/a"), fc("/r")], loaded: ["/r", "/r/a"]) == ["/r", "/r/a"], "plan: deduped, parents first")
    check(RefreshPlan.directories(for: [fc("/r", scan: true)], loaded: ["/r", "/r/a", "/r/a/b", "/rr"]) == ["/r", "/r/a", "/r/a/b"],
          "plan: must-scan covers loaded descendants only (not /rr)")
    check(RefreshPlan.directories(for: [FolderChange(path: "/r", mustScanSubDirs: false, rootChanged: true)], loaded: ["/r"]).isEmpty,
          "plan: root-changed handled elsewhere")
    check(RefreshPlan.directories(for: [fc("/big/unloaded/deep", scan: true)], loaded: ["/r"]).isEmpty,
          "plan: events in unloaded folders plan nothing")

    func f(_ n: String) -> LibraryEntry { LibraryEntry(name: n, isDirectory: false) }
    let d = ChildDiff.diff(old: [f("a.md"), f("b.md"), f("c.md")], new: [f("a.md"), f("bb.md"), f("c.md"), f("d.md")])
    check(d.removed == IndexSet([1]) && d.inserted == IndexSet([1, 3]), "diff: rename + add")
    check(ChildDiff.diff(old: [], new: [f("a.md")]).inserted == IndexSet([0]), "diff: into empty")
    check(ChildDiff.diff(old: [f("a.md")], new: []).removed == IndexSet([0]), "diff: to empty")
    check(ChildDiff.diff(old: [f("a.md")], new: [f("a.md")]) == (IndexSet(), IndexSet()), "diff: identical is empty")
    check(ChildDiff.diff(old: [f("x.md")], new: [LibraryEntry(name: "x.md", isDirectory: true)]) == (IndexSet([0]), IndexSet([0])),
          "diff: file replaced by folder of same name")

    let fm = FileManager.default
    let tmp = fm.temporaryDirectory.appending(path: "mdcheck-refresh-\(UUID().uuidString)")
    try? fm.createDirectory(at: tmp.appending(path: "sub"), withIntermediateDirectories: true)
    fm.createFile(atPath: tmp.appending(path: "a.md").path, contents: Data())
    fm.createFile(atPath: tmp.appending(path: "sub/s.md").path, contents: Data())
    defer { try? fm.removeItem(at: tmp) }
    let rootPath = LibraryListing.canonicalPath(tmp)
    let tree = LibraryTree(); tree.setRoots([tmp])
    tree.roots[0].loadChildren()
    let subNode = tree.roots[0].children![1]
    subNode.loadChildren()
    let aNode = tree.roots[0].children![0]
    fm.createFile(atPath: tmp.appending(path: "b.md").path, contents: Data())
    try? fm.removeItem(at: tmp.appending(path: "a.md"))
    fm.createFile(atPath: tmp.appending(path: "sub/t.md").path, contents: Data())
    let changes = tree.refresh([fc(rootPath), fc(rootPath + "/sub")])
    check(tree.roots[0].children?.map(\.name) == ["b.md", "sub"], "refresh: root re-listed")
    check(tree.roots[0].children?[1] === subNode && subNode.children?.map(\.name) == ["s.md", "t.md"],
          "refresh: unchanged folder keeps identity and its loaded children")
    check(changes.count == 2 && changes[0].parent === tree.roots[0], "refresh: one change per affected folder, parents first")
    check(changes[0].removed == IndexSet([0]) && changes[0].inserted == IndexSet([0]) && changes[1].inserted == IndexSet([1]),
          "refresh: change indexes")
    check(!(tree.roots[0].children?.contains { $0 === aNode } ?? false), "refresh: removed node gone")
    check(tree.refresh([fc(rootPath)]).isEmpty, "refresh: unchanged folder yields no change")

    // folder deleted: removed by the root refresh, the later planned refresh of it is skipped
    try? fm.removeItem(at: tmp.appending(path: "sub"))
    let c2 = tree.refresh([fc(rootPath), fc(rootPath + "/sub")])
    check(c2.count == 1 && tree.roots[0].children?.map(\.name) == ["b.md"], "refresh: deleted folder detached, later change skipped")

    // unloaded folder: no enumeration
    try? fm.createDirectory(at: tmp.appending(path: "cold"), withIntermediateDirectories: true)
    fm.createFile(atPath: tmp.appending(path: "cold/z.md").path, contents: Data())
    _ = tree.refresh([fc(rootPath)])
    let cold = tree.roots[0].children!.first { $0.name == "cold" }!
    _ = tree.refresh([fc(rootPath + "/cold", scan: true)])
    check(cold.children == nil, "refresh: unloaded folder stays unloaded")
}
