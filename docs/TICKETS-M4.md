# M4 — Polish, writing aids, automation

Milestone goal: the P1 extras that make the editor pleasant — style check, custom
patterns, URL scheme, themes, preferences. Depends on M1.5 and M3.

Legend: `[ ]` todo · `[x]` done. Keep `swift build` and `swift run mdcheck` green.

---

- [ ] **M4-0 — Preferences window.** `NSWindowController` with SwiftUI panes:
  General, Editor (font, size, insets), Markdown (extensions), Preview (theme),
  Publishing (from M6). Settings via `UserDefaults` keys in one `Prefs` enum.
  *Verify:* change editor font → applies live; relaunch keeps it.

- [ ] **M4-1 — Preview themes.** Two built-in CSS themes (light/dark variants each);
  user CSS override file in Application Support.
  *Verify:* switch theme → preview updates; custom CSS applies.

- [ ] **M4-2 — Style check.** `NSLinguisticTagger`/`NaturalLanguage` tagging;
  highlight adjectives / adverbs / weak verbs / clichés (toggle each). Runs on the
  visible range, debounced.
  *Verify:* enable adverbs → "quickly" highlighted; disable → cleared; no lag on a
  10k-word doc.

- [ ] **M4-3 — Custom patterns.** User-defined regex/word-list rules with a colour,
  managed in Preferences; applied by the style-check pass.
  *Verify:* add rule `\bvery\b` → highlighted.

- [ ] **M4-4 — URL scheme.** `aeris://` (x-callback-url style): `open?path=`, `new?text=`,
  `append?path=&text=`, `export?path=&format=`, `publish?path=&account=`. Registered
  via `Info.plist` (INF-1). Calls that mutate ask once for a per-caller token.
  *Verify:* `open "aeris://open?path=/tmp/a.md"` opens the file; `append` adds text.

- [ ] **M4-5 — Command palette.** ⇧⌘P: fuzzy list of every menu command.
  *Verify:* type "type" → "Typewriter Mode" → Return toggles it.

- [ ] **M4-6 — Document outline.** Sidebar pane listing headings; click to jump.
  *Verify:* click H2 → editor scrolls to it.

- [ ] **M4-7 — Version browser polish.** Confirm `NSDocument` version browser works with
  xattr metadata; diff view via `diff-match-patch` (optional).
  *Verify:* Revert To ▸ Browse All Versions shows history; restoring works.

Exit criteria for M4: `aeris://open?path=…` opens a file; style check highlights
adverbs; theme switch persists across relaunch.
