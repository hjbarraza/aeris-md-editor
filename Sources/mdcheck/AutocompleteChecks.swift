import Foundation
import MarkdownCore

// Hashtags + Completion cases. Mirrored in Tests/MarkdownCoreTests/AutocompleteTests.swift.
// Text marks the caret as `|` (see InlineEditChecks.swift).
func hashtagCases() -> [(String, [String])] {
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
func triggerCases() -> [(String, Completion.Kind?, String)] {
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
func acceptCases() -> [(String, String, String)] {
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

func runAutocompleteChecks() {
    for (text, want) in hashtagCases() {
        let got = Hashtags.extract(text)
        if got != want { print("     got \(got)") }
        check(got == want, "hashtags in \(text.debugDescription)")
    }
    for (marked, kind, prefix) in triggerCases() {
        let (text, sel) = unmarkSelection(marked)
        let t = Completion.trigger(in: text, caret: sel.location)
        let ok = t?.kind == kind && (t == nil || (text as NSString).substring(with: t!.prefix) == prefix)
        if !ok { print("     got \(String(describing: t))") }
        check(ok, "trigger \(marked.debugDescription) → \(kind.map { "\($0)" } ?? "none")")
    }
    for (marked, value, want) in acceptCases() {
        let (text, sel) = unmarkSelection(marked)
        guard let t = Completion.trigger(in: text, caret: sel.location) else { check(false, "accept: no trigger in \(marked)"); continue }
        let got = markedResult(text, Completion.accept(value, for: t, in: text))
        if got != want { print("     got \(got.debugDescription)") }
        check(got == want, "accept \(value.debugDescription) in \(marked.debugDescription)")
    }
    let pool = ["Beta", "alpha", "alphabet", "gamma", "Alpaca", "zalph", "alpha"]
    check(Completion.rank(pool, prefix: "ALP") == ["Alpaca", "alpha", "alphabet", "zalph"], "rank: prefix matches first, then substring, deduped")
    check(Completion.rank(pool, prefix: "") == ["Alpaca", "alpha", "alphabet", "Beta", "gamma", "zalph"], "rank: empty prefix lists all, sorted")
    check(Completion.rank(pool, prefix: "xyz").isEmpty, "rank: no match")
}
