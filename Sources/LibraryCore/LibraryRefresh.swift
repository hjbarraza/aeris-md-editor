import Foundation

/// One filesystem change report, already reduced to a folder path (from FSEvents).
public struct FolderChange: Equatable, Sendable {
    public let path: String
    public let mustScanSubDirs: Bool
    public let rootChanged: Bool

    public init(path: String, mustScanSubDirs: Bool, rootChanged: Bool) {
        self.path = path
        self.mustScanSubDirs = mustScanSubDirs
        self.rootChanged = rootChanged
    }
}

/// Decides which loaded folders to re-list. Never names an unloaded folder, so a burst of
/// events deep in a big location causes no enumeration.
public enum RefreshPlan {
    public static func directories(for changes: [FolderChange], loaded: Set<String>) -> [String] {
        var planned = Set<String>()
        for change in changes where !change.rootChanged {
            var path = change.path
            if path.count > 1, path.hasSuffix("/") { path.removeLast() }
            if change.mustScanSubDirs {
                let prefix = path == "/" ? "/" : path + "/"
                planned.formUnion(loaded.filter { $0 == path || $0.hasPrefix(prefix) })
            } else if loaded.contains(path) {
                planned.insert(path)
            }
        }
        func depth(_ p: String) -> Int { p.split(separator: "/").count }
        return planned.sorted { (depth($0), $0) < (depth($1), $1) }
    }
}

/// Minimal remove/insert sets that turn one sorted child list into another.
public enum ChildDiff {
    /// `removed` indexes into `old`, `inserted` into `new`; both inputs are in `LibraryListing.sorted` order.
    public static func diff(old: [LibraryEntry], new: [LibraryEntry]) -> (removed: IndexSet, inserted: IndexSet) {
        var removed = IndexSet(), inserted = IndexSet()
        var i = 0, j = 0
        while i < old.count, j < new.count {
            if old[i] == new[j] {
                i += 1; j += 1
            } else if LibraryListing.precedes(old[i], new[j]) {
                removed.insert(i); i += 1
            } else if LibraryListing.precedes(new[j], old[i]) {
                inserted.insert(j); j += 1
            } else {  // same name, different kind
                removed.insert(i); inserted.insert(j); i += 1; j += 1
            }
        }
        while i < old.count { removed.insert(i); i += 1 }
        while j < new.count { inserted.insert(j); j += 1 }
        return (removed, inserted)
    }
}

/// What `LibraryTree.refresh` changed under one folder, for the outline view to animate.
@MainActor
public struct TreeChange {
    public let parent: LibraryNode
    public let removed: IndexSet
    public let inserted: IndexSet
}
