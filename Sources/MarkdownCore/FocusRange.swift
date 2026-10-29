import Foundation

/// The text Focus Mode keeps at full contrast around the selection. UTF-16 offsets.
public enum FocusRange {
    public enum Scope: Int, Sendable { case sentence, paragraph }

    /// Paragraph: the run of non-blank lines around the selection (a Markdown
    /// paragraph may be hard-wrapped over several lines); on a blank line, that line.
    /// Sentence: from the sentence holding the selection's start to the one holding its
    /// end, found inside that paragraph with line breaks read as spaces.
    public static func range(in text: String, selection: NSRange, scope: Scope) -> NSRange {
        let ns = text as NSString
        let para = paragraph(in: ns, selection)
        guard scope == .sentence, para.length > 0 else { return para }
        let flat = ns.substring(with: para)
            .replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ") as NSString
        var sentences: [NSRange] = []
        flat.enumerateSubstrings(in: NSRange(location: 0, length: flat.length),
                                 options: [.bySentences, .substringNotRequired]) { _, _, enclosing, _ in
            sentences.append(NSRange(location: enclosing.location + para.location, length: enclosing.length))
        }
        guard let first = sentences.first else { return para }
        func sentence(at i: Int) -> NSRange { sentences.last { $0.location <= i } ?? first }
        let a = sentence(at: selection.location)
        let b = sentence(at: selection.length > 0 ? NSMaxRange(selection) - 1 : selection.location)
        return NSRange(location: a.location, length: NSMaxRange(b) - a.location)
    }

    private static func paragraph(in ns: NSString, _ sel: NSRange) -> NSRange {
        func line(_ i: Int) -> NSRange { ns.lineRange(for: NSRange(location: i, length: 0)) }
        func isBlank(_ r: NSRange) -> Bool {
            ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let first = line(sel.location)
        let last = sel.length > 0 ? line(NSMaxRange(sel) - 1) : first
        var lo = first.location
        if !isBlank(first) {
            while lo > 0 {
                let prev = line(lo - 1)
                if isBlank(prev) { break }
                lo = prev.location
            }
        }
        var hi = NSMaxRange(last)
        if !isBlank(last) {
            while hi < ns.length {
                let next = line(hi)
                if isBlank(next) { break }
                hi = NSMaxRange(next)
            }
        }
        return NSRange(location: lo, length: hi - lo)
    }
}
