import Foundation
import Markdown

/// `#tags` in Markdown text.
public enum Hashtags {
    /// Tags (without `#`) in order of first appearance, each once. A tag is `#` at the
    /// start or after whitespace/punctuation, then letters, digits, `_`, `-`, `/`, not
    /// starting with a digit (trailing `-` / `/` dropped). Code spans and blocks, HTML,
    /// link destinations and headings' `# ` are skipped; a `#` inside a URL follows a
    /// tag character (`/`, a letter, a digit), so it never starts a tag.
    public static func extract(_ text: String) -> [String] {
        let skip = opaqueRanges(text, linkDestinations: true)
        let s = text as NSString
        var tags: [String] = [], seen = Set<String>()
        var i = 0
        while i < s.length {
            let hash = s.range(of: "#", range: NSRange(location: i, length: s.length - i))
            guard hash.location != NSNotFound else { break }
            i = hash.location + 1
            guard startsTag(s, at: hash.location), !skip.contains(where: { NSLocationInRange(hash.location, $0) })
            else { continue }
            var tag = tagChars(s, from: i)
            while tag.hasSuffix("-") || tag.hasSuffix("/") { tag.removeLast() }
            guard let first = tag.first, !first.isNumber else { continue }
            i += tag.utf16.count
            if seen.insert(tag).inserted { tags.append(tag) }
        }
        return tags
    }

    static func isTagChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_" || c == "-" || c == "/"
    }

    /// `#` at `i` may start a tag: at the start, or after whitespace or punctuation
    /// that isn't a tag character or another `#`.
    static func startsTag(_ s: NSString, at i: Int) -> Bool {
        guard i > 0 else { return true }
        let prev = Character(s.substring(with: s.rangeOfComposedCharacterSequence(at: i - 1)))
        return prev.isWhitespace || prev.isPunctuation && !isTagChar(prev) && prev != "#"
    }

    /// The run of tag characters starting at `i`.
    static func tagChars(_ s: NSString, from i: Int) -> String {
        var out = "", j = i
        while j < s.length {
            let r = s.rangeOfComposedCharacterSequence(at: j)
            let c = Character(s.substring(with: r))
            guard isTagChar(c) else { break }
            out.append(c); j = NSMaxRange(r)
        }
        return out
    }

    /// UTF-16 ranges where `#tags`, `[[` and `](` mean nothing: code, HTML and,
    /// optionally, the `](destination)` parts of links and images.
    static func opaqueRanges(_ text: String, linkDestinations: Bool) -> [NSRange] {
        let conv = SpanCollector(text)
        var out: [NSRange] = []
        func walk(_ m: Markup) {
            if let r = conv.nsRange(m.range) {
                switch m {
                case is InlineCode, is CodeBlock, is HTMLBlock, is InlineHTML: out.append(r)
                case is Link where linkDestinations, is Image where linkDestinations:
                    let end = m.children.compactMap { conv.nsRange($0.range) }.last.map(NSMaxRange) ?? r.location
                    out.append(NSRange(location: end, length: NSMaxRange(r) - end))
                default: break
                }
            }
            m.children.forEach(walk)
        }
        walk(MarkdownCore.parse(text))
        return out
    }
}

/// Where the autocomplete popup applies and what accepting a candidate writes.
public enum Completion {
    public enum Kind: Equatable, Sendable { case hashtag, wikilink, path }

    public struct Trigger: Equatable, Sendable {
        public let kind: Kind
        /// UTF-16 index of the `#`, `[[` or `](`.
        public let start: Int
        /// What has been typed after the trigger, up to the caret.
        public let prefix: NSRange
        public init(kind: Kind, start: Int, prefix: NSRange) {
            self.kind = kind; self.start = start; self.prefix = prefix
        }
    }

    /// The completion context at `caret`, if any: an open `[[` on the caret's line,
    /// an open `](` (no `)` or space typed since), or a `#tag` being typed at a word
    /// start. Never inside code or HTML, as parsed from the caret's run of non-blank
    /// lines (a code block that spans blank lines is the caller's to exclude).
    public static func trigger(in text: String, caret: Int) -> Trigger? {
        let s = text as NSString
        guard caret >= 0, caret <= s.length else { return nil }
        let lineStart = s.lineRange(for: NSRange(location: caret, length: 0)).location
        let before = NSRange(location: lineStart, length: caret - lineStart)
        /// The last `token` before the caret on its line, with none of `stoppers` typed since.
        func open(_ token: String, _ stoppers: String, _ kind: Kind) -> Trigger? {
            let o = s.range(of: token, options: .backwards, range: before)
            guard o.location != NSNotFound else { return nil }
            let typed = NSRange(location: NSMaxRange(o), length: caret - NSMaxRange(o))
            guard s.substring(with: typed).rangeOfCharacter(from: CharacterSet(charactersIn: stoppers)) == nil
            else { return nil }
            return Trigger(kind: kind, start: o.location, prefix: typed)
        }
        var t = open("[[", "[]", .wikilink) ?? open("](", ") \t", .path)
        if t == nil {
            let typed = String(s.substring(with: before).reversed().prefix(while: Hashtags.isTagChar).reversed())
            let hash = caret - typed.utf16.count - 1
            if hash >= lineStart, s.character(at: hash) == 0x23, Hashtags.startsTag(s, at: hash),
               typed.first.map({ !$0.isNumber }) ?? true {
                t = Trigger(kind: .hashtag, start: hash, prefix: NSRange(location: hash + 1, length: typed.utf16.count))
            }
        }
        guard let t else { return nil }
        let block = BlockLines.block(s, at: caret)
        let skip = Hashtags.opaqueRanges(s.substring(with: block), linkDestinations: t.kind == .hashtag)
        return skip.contains { NSLocationInRange(t.start - block.location, $0) } ? nil : t
    }

    /// Candidates matching `prefix`, case-insensitively: those starting with it first,
    /// then those containing it; alphabetical within each group.
    public static func rank(_ candidates: [String], prefix: String) -> [String] {
        let sorted = Set(candidates).sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
        guard !prefix.isEmpty else { return sorted }
        let p = prefix.lowercased()
        return sorted.filter { $0.lowercased().hasPrefix(p) }
            + sorted.filter { !$0.lowercased().hasPrefix(p) && $0.lowercased().contains(p) }
    }

    /// Accepting `value`: replaces the typed prefix (and, for tags and paths, the rest
    /// of the word after the caret). A wikilink gets its `]]` unless one follows.
    public static func accept(_ value: String, for t: Trigger, in text: String) -> TextEdit {
        let s = text as NSString
        var range = t.prefix, insert = value, after = 0
        switch t.kind {
        case .hashtag:
            range.length += Hashtags.tagChars(s, from: NSMaxRange(range)).utf16.count
        case .path:
            var end = NSMaxRange(range)
            while end < s.length, let u = Unicode.Scalar(s.character(at: end)),
                  !CharacterSet(charactersIn: ") \t\n\r").contains(u) { end += 1 }
            range.length = end - range.location
        case .wikilink:
            let rest = NSRange(location: NSMaxRange(range), length: min(2, s.length - NSMaxRange(range)))
            if s.substring(with: rest) == "]]" { after = 2 } else { insert += "]]" }
        }
        let caret = range.location + insert.utf16.count + after
        return TextEdit(range: range, replacement: insert, selection: NSRange(location: caret, length: 0))
    }
}
