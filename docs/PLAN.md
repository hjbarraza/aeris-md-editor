# Development plan — aeris-md-editor

The single tracking doc. Milestones below; tickets live in one `docs/TICKETS-M*.md`
file per milestone. Run `scripts/status.sh` to see progress and validate the gates.

## How tracking works

- **One ticket at a time**, in file order. Flip `[ ]` → `[x]` only after its *Verify*
  step passes. The checkbox is the source of truth; no other tracker.
- **Every ticket has a Verify step.** Automated where possible (`mdcheck`, XCTest),
  manual otherwise (a concrete thing to do in the app and a concrete thing to see).
- **Every milestone has exit criteria** — a short acceptance script a human runs once
  on the built app. A milestone is done when every ticket is `[x]` *and* the exit
  script passes. Record the date next to the milestone when it does.
- **Always-green gates** (run before every commit; `scripts/status.sh` runs them):
  `swift build` · `swift run mdcheck`. On CI / full Xcode: `swift test` too.
- Pure logic goes in `MarkdownCore` with a test in **both** `mdcheck` and XCTest.
  UI behaviour is verified manually against the ticket's step.

## Milestones

| # | Milestone | Goal (one line) | Tickets | Exit criteria | Done |
|---|---|---|---|---|---|
| M1 | Core editor | Open, edit, style, preview, save a real `.md` | [TICKETS-M1](TICKETS-M1.md) | open a `.md` → edit with live styling → live preview → save: bytes clean, cursor restored on reopen | |
| M1.5 | Editor commands | Every P0 editing command from PRD §4.3 | [TICKETS-M1.5](TICKETS-M1.5.md) | write a doc using only menu/shortcut commands: headings, lists, task list, table, link, image, footnote; stats popover shows correct counts; typewriter + focus toggle | |
| M2 | Library | Sidebar over on-disk folders, tags, smart folders, search | [TICKETS-M2](TICKETS-M2.md) | add a folder → browse, create, rename, trash files from sidebar; `#tag` appears in Tags; smart folder filters; ⌘K jumps to a file; Finder change shows live | |
| M3 | Export | Markdown / HTML / PDF export, copy matrix, print | [TICKETS-M3](TICKETS-M3.md) | export the same doc to `.md`, `.html`, `.pdf` and open each in another app; copy-as-HTML pastes into a browser; print preview renders | |
| M4 | Polish | Style check, URL scheme, themes, prefs | [TICKETS-M4](TICKETS-M4.md) | `aeris://open?path=…` opens a file; style check highlights adverbs; theme switch persists | |
| M5 | Optional | Authorship analytics (Human/AI/Reference %), annotations, transclusion | [TICKETS-M5](TICKETS-M5.md) | only if M1–M4 are done; see file | |
| M6 | Publishing | Push a document as a *draft* to WordPress, Ghost, Micropub, Micro.blog (Medium, Substack P2) | [TICKETS-M6](TICKETS-M6.md) | add a WordPress account (token in Keychain) → Publish → draft appears on the site, nothing public; republish updates the same post | |

**Publishing goes last (decided 2026-10-28).** The PRD puts it at M4; H moved it to
the end so the editor, library and export are solid before any network code. Nothing
in M1–M5 should depend on it.

**Note on M1.5.** PRD §5 lists five milestones, but the P0 editing commands in §4.3
(formatting, task lists, table editor, stats, typewriter/focus, autocomplete) belong to
none of them. M1.5 closes that gap so P0 work doesn't slip into "polish".

## Infrastructure tickets (do alongside M1)

These unblock validation itself. Tracked in [TICKETS-M1](TICKETS-M1.md) as `INF-*`.

- **INF-1 — App bundle.** SPM can't emit a `.app`; a script wraps the built binary with
  an `Info.plist` (document types, URL scheme, bundle id). Needed by M1-1.
- **INF-2 — CI.** GitHub Actions on a macOS runner: `swift build`, `swift run mdcheck`,
  `swift test`. This machine has CLT only, so CI is the only place XCTest runs.
- **INF-3 — Smoke-test fixtures.** `Tests/Fixtures/*.md` covering every node type we
  render; `mdcheck` and XCTest both read them.

## Decisions still open (and the ticket that forces each)

| Question | Forced by | Default if undecided |
|---|---|---|
| Word export library | M3-7 | Defer; P1 |
| Substack: Swift reimplementation vs bundled Python helper | M6-9 | Swift, cookie-authed, minimal endpoints |

Resolved: AppKit-primary (ADR-001) · WKWebView preview (ADR-001) · swift-markdown (ADR-001) ·
**Distribution = direct download, not Mac App Store** (decided 2026-10-28; no sandbox
constraints on folder access, Sparkle for updates later).

## Dependency order

```
INF-1 ─┐
M1 ────┼─▶ M1.5 ─▶ M2 ─▶ M3 ─▶ M4 ─▶ M5 ─▶ M6 (publishing, last)
INF-2 ─┘           (M3 only depends on M1; it can be parallelised
                    with M1.5/M2 if a second person joins)
```

## Scope guard

Before taking any ticket, re-read the hard boundary (README, Out of scope): **no accounts,
login, trials, or payment gating**; **no copied code/strings/design**. A ticket that
needs either is wrong — fix the ticket, not the boundary.
