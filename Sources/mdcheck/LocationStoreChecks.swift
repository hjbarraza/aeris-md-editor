import Foundation
import LibraryCore

func runLocationStoreChecks() throws {
    let fm = FileManager.default
    let tmp = fm.temporaryDirectory.appending(path: "mdcheck-store-\(UUID().uuidString)")
    let folder = tmp.appending(path: "Notes")
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tmp) }
    let file = tmp.appending(path: "sub/Locations.plist")  // parent created on demand

    let s = LocationStore(fileURL: file); s.load()
    check(s.locations.isEmpty, "store: missing file loads empty")
    let first = try s.add(folder), second = try s.add(folder)
    check(first == true && second == false, "store: second add of same folder is a no-op")
    let s2 = LocationStore(fileURL: file); s2.load()
    check(s2.locations.count == 1 && s2.resolve(at: 0).map(LibraryListing.canonicalPath) == LibraryListing.canonicalPath(folder),
          "store: bookmark resolves after reload")
    try fm.moveItem(at: folder, to: tmp.appending(path: "Renamed"))
    let s3 = LocationStore(fileURL: file); s3.load()
    check(s3.resolve(at: 0)?.lastPathComponent == "Renamed" && s3.locations[0].path.hasSuffix("/Renamed"),
          "store: renamed folder still resolves, path updated")
    let s3b = LocationStore(fileURL: file); s3b.load()
    check(s3b.locations[0].path.hasSuffix("/Renamed"), "store: updated path was saved")
    try fm.removeItem(at: tmp.appending(path: "Renamed"))
    let s4 = LocationStore(fileURL: file); s4.load()
    check(s4.resolve(at: 0) == nil && s4.locations.count == 1, "store: deleted folder unresolvable but kept")
    try s4.remove(at: 0)
    let s5 = LocationStore(fileURL: file); s5.load()
    check(s5.locations.isEmpty, "store: remove persists")
    // A folder trashed in Finder still "exists" (in ~/.Trash) but counts as missing; putting it back restores it.
    let trashFile = tmp.appending(path: "trash.plist"), victim = tmp.appending(path: "Trashed-\(UUID().uuidString)")
    try fm.createDirectory(at: victim, withIntermediateDirectories: true)
    let t = LocationStore(fileURL: trashFile); t.load()
    _ = try t.add(victim)
    let original = t.locations[0]
    var trashed: NSURL?
    try fm.trashItem(at: victim, resultingItemURL: &trashed)
    let t2 = LocationStore(fileURL: trashFile); t2.load()
    check(t2.resolve(at: 0) == nil, "store: trashed folder is unresolvable")
    check(t2.locations[0] == original, "store: trashed folder keeps its path and bookmark")
    if let back = trashed as URL? {
        try fm.moveItem(at: back, to: victim)
        let t3 = LocationStore(fileURL: trashFile); t3.load()
        check(t3.resolve(at: 0).map(LibraryListing.canonicalPath) == LibraryListing.canonicalPath(victim),
              "store: folder put back from the Trash resolves again")
    }
    try Data("garbage".utf8).write(to: file)
    let s6 = LocationStore(fileURL: file); s6.load()
    check(s6.locations.isEmpty, "store: corrupt file loads empty, no crash")
    check(s6.resolve(at: 3) == nil, "store: resolve out of range is nil")
}
