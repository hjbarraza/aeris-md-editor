import Foundation

/// One child of a library folder.
public struct LibraryEntry: Equatable, Sendable {
    public let name: String
    public let isDirectory: Bool

    public init(name: String, isDirectory: Bool) {
        self.name = name
        self.isDirectory = isDirectory
    }
}

/// What the library sidebar shows for a folder: subfolders plus Markdown/text files.
public enum LibraryListing {
    public static let fileExtensions: Set<String> = ["md", "markdown", "txt"]

    /// Folders always pass (unless hidden or a package); files need a listed extension.
    public static func includes(name: String, isDirectory: Bool, isPackage: Bool, isHidden: Bool) -> Bool {
        if isHidden || isPackage { return false }
        if isDirectory { return true }
        return fileExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// Numeric-aware, locale-aware order; names equal ignoring case (e.g. "a" vs "A") fall back to plain `<`.
    /// (`localizedStandardCompare` alone does not return `.orderedSame` for case-only differences.)
    public static func sorted(_ entries: [LibraryEntry]) -> [LibraryEntry] {
        entries.sorted(by: precedes)
    }

    /// The `sorted` order as a predicate.
    public static func precedes(_ a: LibraryEntry, _ b: LibraryEntry) -> Bool {
        switch a.name.lowercased().localizedStandardCompare(b.name.lowercased()) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return a.name < b.name
        }
    }

    /// Filtered, sorted children of `directory`; empty if it can't be read.
    public static func entries(in directory: URL) -> [LibraryEntry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: []) else { return [] }
        let all: [LibraryEntry] = urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = url.lastPathComponent
            let isDirectory = values?.isDirectory ?? false
            guard includes(name: name, isDirectory: isDirectory,
                           isPackage: values?.isPackage ?? false, isHidden: values?.isHidden ?? false)
            else { return nil }
            return LibraryEntry(name: name, isDirectory: isDirectory)
        }
        return sorted(all)
    }

    /// `realpath(3)` form (keeps `/private`); falls back to the standardized path if it doesn't exist.
    public static func canonicalPath(_ url: URL) -> String {
        guard let resolved = realpath(url.path, nil) else { return url.standardizedFileURL.path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
