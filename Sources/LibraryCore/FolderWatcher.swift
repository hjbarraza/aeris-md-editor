import CoreServices
import Foundation

/// Watches folders with one directory-level FSEvents stream and reports changes on the main
/// actor. Pass canonical (`realpath`) paths: FSEvents reports them in that form.
@MainActor
public final class FolderWatcher {
    private let onChange: @MainActor ([FolderChange]) -> Void
    // Only touched in init, `stop` and deinit.
    nonisolated(unsafe) private var stream: FSEventStreamRef?

    public init(paths: [String], latency: TimeInterval = 0.25,
                onChange: @escaping @MainActor ([FolderChange]) -> Void) {
        self.onChange = onChange
        guard !paths.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, _ in
            guard let info else { return }
            let reported = unsafeBitCast(eventPaths, to: CFArray.self) as? [String] ?? []
            let flags = (0..<count).map { eventFlags[$0] }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            // The stream runs on the main queue, and is invalidated before the watcher goes away.
            MainActor.assumeIsolated { watcher.deliver(paths: reported, flags: flags) }
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot)
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags)
        else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    deinit { Self.tearDown(stream) }

    /// Stops reporting. Safe to call more than once.
    public func stop() {
        Self.tearDown(stream)
        stream = nil
    }

    nonisolated private static func tearDown(_ stream: FSEventStreamRef?) {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    private func deliver(paths: [String], flags: [FSEventStreamEventFlags]) {
        let scanFlags = FSEventStreamEventFlags(
            kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped)
        let rootFlag = FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged)
        let changes = zip(paths, flags).map { path, flag in
            FolderChange(path: path, mustScanSubDirs: flag & scanFlags != 0, rootChanged: flag & rootFlag != 0)
        }
        if !changes.isEmpty { onChange(changes) }
    }
}
