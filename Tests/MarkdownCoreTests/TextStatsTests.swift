import XCTest
@testable import MarkdownCore

final class TextStatsTests: XCTestCase {
    func testEmpty() {
        XCTAssertEqual(TextStats.compute(""), TextStats(characters: 0, charactersWithoutSpaces: 0, words: 0,
            sentences: 0, readingMinutes: 0, speakingMinutes: 0, tasksDone: 0, tasksTotal: 0))
    }
    func testHeadingSyntaxNotCounted() {
        let s = TextStats.compute("# Hello world")
        XCTAssertEqual(s.words, 2); XCTAssertEqual(s.characters, 11); XCTAssertEqual(s.charactersWithoutSpaces, 10)
    }
    func testLinkURLNotCounted() {
        let s = TextStats.compute("See [two words](http://x.com/long/url) now")
        XCTAssertEqual(s.words, 4); XCTAssertEqual(s.characters, "See two words now".count)
    }
    /// Documents NLTokenizer behavior: an emoji is its own word token; 日本語 segments as 日本 + 語.
    func testEmojiAndCJK() {
        XCTAssertEqual(TextStats.compute("Hi 🎉 there").words, 3)
        XCTAssertEqual(TextStats.compute("👨‍👩‍👧 a").characters, 3)
        let cjk = TextStats.compute("日本語")
        XCTAssertEqual(cjk.words, 2); XCTAssertEqual(cjk.characters, 3)
    }
    func testSentencesWithAbbreviation() {
        XCTAssertEqual(TextStats.compute("Use tools, e.g. a hammer. It works. Does it?").sentences, 3)
    }
    func testTasks() {
        let s = TextStats.compute("- [x] a\n- [X] b\n- [ ] c\n- plain")
        XCTAssertEqual(s.tasksDone, 2); XCTAssertEqual(s.tasksTotal, 3)
    }
    func testCodeBlockCounted() {
        let s = TextStats.compute("```swift\nlet x = 1\n```")
        XCTAssertEqual(s.words, 3); XCTAssertEqual(s.characters, 9)
    }
    func testMinutes() {
        XCTAssertEqual(TextStats.compute(Array(repeating: "word", count: 238).joined(separator: " ")).readingMinutes, 1)
        XCTAssertEqual(TextStats.compute(Array(repeating: "word", count: 140).joined(separator: " ")).speakingMinutes, 1)
    }
}
