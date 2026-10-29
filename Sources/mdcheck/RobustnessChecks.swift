import Foundation
import MarkdownCore

/// Inputs that once trapped, plus a fuzz pass: styling and rendering never crash.
/// Mirrored in Tests/MarkdownCoreTests/MarkdownCoreTests.swift.
func runRobustnessChecks() {
    // Smart punctuation applies to the preview HTML only; the editor and stats read the untouched parse.
    let smart = "\"a\" it's -- --- ..."
    check(MarkdownCore.html(smart).contains("“a” it’s – — …"), "smart punctuation in preview html")
    check(MarkdownCore.html("`\"a\" -- ...`").contains("<code>\"a\" -- ...</code>"), "code span stays literal")
    check(MarkdownCore.styleSpans("*\"a\" it's*").contains { $0.range == NSRange(location: 0, length: 10) },
          "styleSpans offsets follow the original source")
    check(TextStats.compute(smart).characters == smart.count, "stats count the original punctuation")
    // An inline code span in a lazy table row: swift-markdown reports column 0.
    let lazyRowCode = "d\n` `\na||\n-|-"
    check(MarkdownCore.html(lazyRowCode).contains("<table>"), "html survives a column-0 source location")
    check(MarkdownCore.styleSpans(lazyRowCode).allSatisfy { $0.range.location >= 0 && NSMaxRange($0.range) <= 13 },
          "styleSpans survives a column-0 source location, spans inside the text")

    let pieces = ["```\n", "~~~", "\n", "\n\n", "# ", "**", "*", "_", "~~", "`", "` `", "- ", "1. ", "> ", "    ", "\t",
                  "[a](b)", "![i](u)", "word", "|", "a||", "-|-", "| a | b |\n|---|---|\n", "---\n", "===\n", "<div>\n",
                  "\\", "é", "😀", "\r\n", "[^1]", "[[x]]", "- [ ] ", "$$", ":"]
    var seed: UInt64 = 0x9E3779B97F4A7C15
    func next() -> Int { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return Int(seed % 1_000_000) }
    var count = 0
    for _ in 0..<3000 {
        var s = ""
        for _ in 0..<(1 + next() % 12) { s += pieces[next() % pieces.count] }
        let n = (s as NSString).length
        let spans = MarkdownCore.styleSpans(s)
        _ = MarkdownCore.html(s, sourceLines: true)
        let starts = MarkdownCore.styleSpansAndBlockStarts(s).blockStarts
        _ = MarkdownCore.isInCodeBlock(s, at: next() % (n + 1))
        if spans.allSatisfy({ $0.range.location >= 0 && NSMaxRange($0.range) <= n }) && starts.allSatisfy({ $0 >= 0 && $0 <= n }) {
            count += 1
        }
    }
    check(count == 3000, "fuzz: 3000 random documents styled, rendered and parsed without a trap, spans in range (\(count))")

    // Code status from a parse that agrees with the whole document.
    let fence = "```\nsetup\n\n- x\n```\n\n- y\n"
    check(MarkdownCore.isInCodeBlock(fence, at: 11) && !MarkdownCore.isInCodeBlock(fence, at: 20),
          "isInCodeBlock: a list line inside a fence across a blank line is code; after it, not")
    let indented = "para\n\n    - x\n"
    check(MarkdownCore.isInCodeBlock(indented, at: 10), "isInCodeBlock: indented code")
    let lazy = "- item\n\n    - x\n"
    check(!MarkdownCore.isInCodeBlock(lazy, at: 12), "isInCodeBlock: an indented line in a list is not code")
    check(MarkdownCore.isInCodeBlock(fence, at: 11, parseFrom: 0) && !MarkdownCore.isInCodeBlock(fence, at: 20, parseFrom: 20),
          "isInCodeBlock: parseFrom at a top-level block start")
}
