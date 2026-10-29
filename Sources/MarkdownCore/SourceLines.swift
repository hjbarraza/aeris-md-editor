import Foundation

/// Maps UTF-16 offsets (NSString/NSTextView units) to 1-based source line
/// numbers, using cmark's line endings (LF, CRLF, CR) so the numbers agree
/// with the `data-line` anchors in `MarkdownCore.html(_:sourceLines:)`.
/// Build once per text version; each lookup is a binary search.
public struct SourceLines: Sendable {
    /// UTF-16 offset of the start of each line.
    private var starts: [Int] = [0]

    public init(_ text: String) {
        let units = Array(text.utf16)
        for (i, u) in units.enumerated() {
            if u == 0x0A || (u == 0x0D && (i + 1 == units.count || units[i + 1] != 0x0A)) {
                starts.append(i + 1)
            }
        }
    }

    /// The 1-based line containing `offset` (clamped to the text).
    public func line(at offset: Int) -> Int {
        var lo = 0, hi = starts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return lo + 1
    }
}
