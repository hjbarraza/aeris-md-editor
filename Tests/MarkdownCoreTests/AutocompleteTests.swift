import XCTest
import Foundation
@testable import MarkdownCore

/// Mirrors Sources/mdcheck/AutocompleteChecks.swift (same cases). Text marks the caret as `|`.
final class AutocompleteTests: XCTestCase {
    private func hashtagCases() -> [(String, [String])] {
        [
            ("Hello #world and #foo-bar, #a/b.", ["world", "foo-bar", "a/b"]),
            ("# Heading\n## Two #", []),
            ("#tag at start\n#second", ["tag", "second"]),
            ("mid#word 👋#emoji", []),
            ("`#code` and #real", ["real"]),
            ("```\n#fenced\n```\n#after", ["after"]),
            ("#123 #1st #_ok #é_tag", ["_ok", "é_tag"]),
            ("(#paren) [#bracket]", ["paren", "bracket"]),
            ("[text](http://x.com/#frag) #t", ["t"]),
            ("http://x.com/#frag www.y.com#z", []),
            ("##double #dup #dup", ["dup"]),
            ("#trail- #x/", ["trail", "x"]),
            ("a\r\n#crlf", ["crlf"]),
            ("    #indented code\n\n#para", ["para"]),
        ]
    }

    /// (marked text, expected kind, expected typed prefix); nil kind = no trigger.
    private func triggerCases() -> [(String, Completion.Kind?, String)] {
        [
            ("#|", .hashtag, ""),
            ("a #ta|", .hashtag, "ta"),
            ("(#ta|", .hashtag, "ta"),
            ("a#ta|", nil, ""),
            ("`#ta|`", nil, ""),
            ("`code` #t|", .hashtag, "t"),
            ("#1|", nil, ""),
            ("# |", nil, ""),
            ("##|", nil, ""),
            ("[[no|", .wikilink, "no"),
            ("[[x|]]", .wikilink, "x"),
            ("[[a]] x|", nil, ""),
            ("line #a\n[[b|", .wikilink, "b"),
            ("[t](do|", .path, "do"),
            ("[t](|)", .path, ""),
            ("[t](a b|", nil, ""),
            ("[t](x) y|", nil, ""),
            ("```\n[[x|\n```", nil, ""),
            ("`[[x|`", nil, ""),
            ("é 👋 #tä|", .hashtag, "tä"),
        ]
    }

    /// (marked text, value accepted, expected marked result).
    private func acceptCases() -> [(String, String, String)] {
        [
            ("a #ta|", "tag", "a #tag|"),
            ("a #ta|gx b", "tag", "a #tag| b"),
            ("[[no|", "notes", "[[notes]]|"),
            ("[[no|]]", "notes", "[[notes]]|"),
            ("[t](do|", "docs/", "[t](docs/|"),
            ("[t](do|cs) x", "draft.md", "[t](draft.md|) x"),
            ("👋 #|", "été", "👋 #été|"),
        ]
    }

    private func unmark(_ marked: String) -> (String, Int) {
        let s = marked as NSString
        let caret = s.range(of: "|")
        return (s.replacingCharacters(in: caret, with: ""), caret.location)
    }

    func testHashtags() {
        for (text, want) in hashtagCases() { XCTAssertEqual(Hashtags.extract(text), want, text) }
    }

    func testTriggers() {
        for (marked, kind, prefix) in triggerCases() {
            let (text, caret) = unmark(marked)
            let t = Completion.trigger(in: text, caret: caret)
            XCTAssertEqual(t?.kind, kind, marked)
            if let t { XCTAssertEqual((text as NSString).substring(with: t.prefix), prefix, marked) }
        }
    }

    func testAccept() {
        for (marked, value, want) in acceptCases() {
            let (text, caret) = unmark(marked)
            guard let t = Completion.trigger(in: text, caret: caret) else { XCTFail("no trigger in \(marked)"); continue }
            let e = Completion.accept(value, for: t, in: text)
            XCTAssertEqual(e.applied(to: text), want.replacingOccurrences(of: "|", with: ""), marked)
            XCTAssertEqual(e.selection, NSRange(location: (want as NSString).range(of: "|").location, length: 0), marked)
        }
    }

    func testRank() {
        let pool = ["Beta", "alpha", "alphabet", "gamma", "Alpaca", "zalph", "alpha"]
        XCTAssertEqual(Completion.rank(pool, prefix: "ALP"), ["Alpaca", "alpha", "alphabet", "zalph"])
        XCTAssertEqual(Completion.rank(pool, prefix: ""), ["Alpaca", "alpha", "alphabet", "Beta", "gamma", "zalph"])
        XCTAssertTrue(Completion.rank(pool, prefix: "xyz").isEmpty)
    }
}
