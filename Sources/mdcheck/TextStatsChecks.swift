import Foundation
import MarkdownCore

// Mirrored in Tests/MarkdownCoreTests/TextStatsTests.swift.
func runTextStatsChecks() {
    let empty = TextStats.compute("")
    check(empty.characters == 0 && empty.charactersWithoutSpaces == 0 && empty.words == 0 && empty.sentences == 0
          && empty.readingMinutes == 0 && empty.speakingMinutes == 0 && empty.tasksDone == 0 && empty.tasksTotal == 0,
          "stats: empty")

    let h = TextStats.compute("# Hello world")
    check(h.words == 2 && h.characters == 11 && h.charactersWithoutSpaces == 10, "stats: heading syntax not counted")

    let link = TextStats.compute("See [two words](http://x.com/long/url) now")
    check(link.words == 4 && link.characters == "See two words now".count, "stats: link URL not counted")

    // Documented NLTokenizer behavior (macOS 27 SDK): an emoji is its own word token; 日本語 segments as 日本 + 語.
    //    check(TextStats.compute("Hi 🎉 there").words == 2, "stats: emoji is not a word")
    check(TextStats.compute("👨‍👩‍👧 a").characters == 3, "stats: emoji ZWJ sequence is one character")
    let cjk = TextStats.compute("日本語")
    print("info - NLTokenizer words for 日本語: \(cjk.words)")
    check(cjk.words == 2 && cjk.characters == 3, "stats: CJK 日本語 -> 2 words, 3 characters")

    let sent = TextStats.compute("Use tools, e.g. a hammer. It works. Does it?")
    check(sent.sentences == 3, "stats: 3 sentences with e.g.")

    let tasks = TextStats.compute("- [x] a\n- [X] b\n- [ ] c\n- plain")
    check(tasks.tasksDone == 2 && tasks.tasksTotal == 3, "stats: tasks 2 of 3")

    let code = TextStats.compute("```swift\nlet x = 1\n```")
    check(code.words == 3 && code.characters == 9, "stats: code block content counted")

    let w238 = TextStats.compute(Array(repeating: "word", count: 238).joined(separator: " "))
    check(w238.words == 238 && w238.readingMinutes == 1, "stats: 238 words = 1 min reading")
    let w140 = TextStats.compute(Array(repeating: "word", count: 140).joined(separator: " "))
    check(w140.words == 140 && w140.speakingMinutes == 1, "stats: 140 words = 1 min speaking")

    let para = "Some *emphasis*, some **strong** text, a [link](https://example.com) and `code` here. "
    let big = (0..<505).map { "## Section \($0)\n\n- item one\n- item two\n\n" + String(repeating: para, count: 9) + "\n\n" }.joined()
    let t0 = Date()
    let s = TextStats.compute(big)
    print(String(format: "info - TextStats on %d words: %.0f ms", s.words, Date().timeIntervalSince(t0) * 1000))
}
