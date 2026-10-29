import Foundation

/// A folder or file in the library tree. Directory children load lazily, one level at a time.
@MainActor
public final class LibraryNode {
    public let url: URL
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public private(set) weak var parent: LibraryNode?
    /// Directories: nil until loaded. Files: empty from init.
    public private(set) var children: [LibraryNode]?

    init(url: URL, path: String, name: String, isDirectory: Bool, parent: LibraryNode?) {
        self.url = url
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.parent = parent
        self.children = isDirectory ? nil : []
    }

    /// Enumerates this folder's children once; later calls do nothing.
    public func loadChildren() {
        guard isDirectory, children == nil else { return }
        applyListing(LibraryListing.entries(in: url))
    }

    /// Sets children to match `entries`, reusing existing nodes whose entry is unchanged.
    func applyListing(_ entries: [LibraryEntry]) {
        let existing = Dictionary((children ?? []).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        children = entries.map { entry in
            if let node = existing[entry.name], node.isDirectory == entry.isDirectory { return node }
            return LibraryNode(url: url.appending(path: entry.name), path: path + "/" + entry.name,
                               name: entry.name, isDirectory: entry.isDirectory, parent: self)
        }
    }
}

/// The library's root locations and everything loaded below them.
@MainActor
public final class LibraryTree {
    public private(set) var roots: [LibraryNode] = []

    public init() {}

    /// Keeps existing root nodes whose canonical path is unchanged, in the given order.
    public func setRoots(_ urls: [URL]) {
        let existing = Dictionary(roots.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        roots = urls.map { url in
            let path = LibraryListing.canonicalPath(url)
            return existing[path] ?? LibraryNode(url: url, path: path, name: url.lastPathComponent,
                                                 isDirectory: true, parent: nil)
        }
    }

    /// The node at canonical `path`, loading its ancestors on the way down. The root with
    /// the longest matching prefix wins (a location nested in another). Nil if the path is
    /// outside every root or filtered out of the listing.
    public func node(atPath path: String) -> LibraryNode? {
        let candidates = roots.filter { path == $0.path || path.hasPrefix($0.path + "/") }
        guard var node = candidates.max(by: { $0.path.count < $1.path.count }) else { return nil }
        for name in path.dropFirst(node.path.count).split(separator: "/") {
            node.loadChildren()
            guard let child = node.children?.first(where: { $0.name == name }) else { return nil }
            node = child
        }
        return node
    }

    /// Re-lists the loaded folders named by `changes` (never loading new ones) and edits
    /// their children in place: unchanged child nodes keep identity and their loaded
    /// subtrees. Returns one change per folder whose listing differs, parents first.
    public func refresh(_ changes: [FolderChange]) -> [TreeChange] {
        var result: [TreeChange] = []
        for path in RefreshPlan.directories(for: changes, loaded: loadedDirectoryPaths) {
            // Looked up fresh each time: an earlier change may have detached this folder.
            guard let node = loadedNode(atPath: path), let old = node.children else { continue }
            // A folder that can't be read keeps its children: a transient failure must not empty it,
            // and a folder that is gone is removed by its parent's refresh.
            guard let new = LibraryListing.read(node.url) else { continue }
            let diff = ChildDiff.diff(old: old.map { LibraryEntry(name: $0.name, isDirectory: $0.isDirectory) }, new: new)
            guard !diff.removed.isEmpty || !diff.inserted.isEmpty else { continue }
            node.applyListing(new)
            result.append(TreeChange(parent: node, removed: diff.removed, inserted: diff.inserted))
        }
        return result
    }

    /// Walks only already-loaded nodes; nil if any step is unloaded or missing.
    private func loadedNode(atPath path: String) -> LibraryNode? {
        let candidates = roots.filter { path == $0.path || path.hasPrefix($0.path + "/") }
        guard var node = candidates.max(by: { $0.path.count < $1.path.count }) else { return nil }
        for name in path.dropFirst(node.path.count).split(separator: "/") {
            guard let child = node.children?.first(where: { $0.name == name }) else { return nil }
            node = child
        }
        return node
    }

    /// Paths of every directory whose children have been enumerated.
    public var loadedDirectoryPaths: Set<String> {
        var paths = Set<String>()
        func walk(_ node: LibraryNode) {
            guard node.isDirectory, let children = node.children else { return }
            paths.insert(node.path)
            children.forEach(walk)
        }
        roots.forEach(walk)
        return paths
    }
}
