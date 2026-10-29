import Foundation
import LibraryCore

@MainActor func runFolderWatcherChecks() {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appending(path: "aeris-watch-\(UUID())")  // /var alias of /private/var
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }
    let path = LibraryListing.canonicalPath(dir)
    check(path.hasPrefix("/private/") && dir.path != path, "watch: temp dir is a path alias")
    var got: [FolderChange] = []
    let w = FolderWatcher(paths: [path]) { got += $0 }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))  // let the stream start
    let t0 = Date()
    fm.createFile(atPath: dir.appending(path: "new.md").path, contents: Data())
    while got.isEmpty && Date().timeIntervalSince(t0) < 1 { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    check(!got.isEmpty && Date().timeIntervalSince(t0) < 1, "watch: change reported within 1 s")
    check(RefreshPlan.directories(for: got, loaded: [path]) == [path],
          "watch: reported path matches the canonical location path")
    check(got.allSatisfy { !$0.rootChanged }, "watch: a file change is not a root change")

    w.stop()
    got = []
    fm.createFile(atPath: dir.appending(path: "after-stop.md").path, contents: Data())
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    check(got.isEmpty, "watch: nothing reported after stop")

    // renaming the watched folder is reported as a root change
    var rootChanges: [FolderChange] = []
    let w2 = FolderWatcher(paths: [path]) { rootChanges += $0 }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    let moved = fm.temporaryDirectory.appending(path: "aeris-watch-moved-\(UUID())")
    defer { try? fm.removeItem(at: moved) }
    try? fm.moveItem(at: dir, to: moved)
    let t1 = Date()
    while !rootChanges.contains(where: \.rootChanged) && Date().timeIntervalSince(t1) < 1 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
    check(rootChanges.contains(where: \.rootChanged), "watch: renamed root reported as root-changed")
    w2.stop()
}
