import Foundation
import MarkdownCore

// Mirrored in Tests/MarkdownCoreTests/FocusRangeTests.swift.
func runFocusRangeChecks() {
    func f(_ t: String, _ loc: Int, _ len: Int = 0, s: FocusRange.Scope) -> NSRange {
        FocusRange.range(in: t, selection: NSRange(location: loc, length: len), scope: s)
    }
    func r(_ a: Int, _ b: Int) -> NSRange { NSRange(location: a, length: b) }
    check(f("One. Two. Three.", 6, s: .sentence) == r(5, 5), "focus: caret's sentence")
    check(f("One. Two. Three.", 16, s: .sentence) == r(10, 6), "focus: caret at end is in last sentence")
    check(f("One. Two. Three.", 2, 5, s: .sentence) == r(0, 10), "focus: selection spans two sentences")
    check(f("First line\ncontinues. Next.", 2, s: .sentence) == r(0, 22), "focus: sentence across a hard wrap")
    check(f("a\nb c\n\nd", 3, s: .paragraph) == r(0, 6), "focus: paragraph is the non-blank line run")
    check(f("a\nb c\n\nd", 6, s: .paragraph) == r(6, 1), "focus: blank line is its own paragraph")
    check(f("a\nb c\n\nd", 8, s: .paragraph) == r(7, 1), "focus: last paragraph at end of text")
    check(f("a\n\nb", 0, 4, s: .paragraph) == r(0, 4), "focus: selection over two paragraphs")
    check(f("", 0, s: .sentence) == r(0, 0), "focus: empty text")
}
