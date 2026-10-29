# M3 — Export, copy, print

Milestone goal: get a document out as Markdown, HTML, PDF; copy as Markdown/HTML/rich
text; print. All free and ungated. Depends on M1 (preview HTML pipeline).

Legend: `[ ]` todo · `[x]` done. Keep `swift build` and `swift run mdcheck` green.

---

- [ ] **M3-0 — Export menu + save panel.** File ▸ Export… with a format popover
  (`ExportFormat` enum: markdown, html, pdf; word/archive added later). `NSSavePanel`
  with the right extension. One `Exporter` protocol, one type per format.
  *Verify:* menu shows; choosing a format changes the suggested extension.

- [ ] **M3-1 — Markdown export.** Write the document text; if folder-wrapped, copy
  referenced images beside it.
  *Verify:* exported `.md` is byte-identical to the source; images present.

- [ ] **M3-2 — HTML export.** Standalone `.html`: `MarkdownCore.html` + the preview
  theme CSS inlined, images either relative or base64 (option). Template shared with
  the preview pane (one source of truth in `MarkdownCore/Templates`).
  *Verify:* open the `.html` in Safari → matches the preview pane.

- [ ] **M3-3 — PDF export.** Render the export HTML in an off-screen `WKWebView` →
  `createPDF` with page size / margins options.
  *Verify:* `.pdf` opens in Preview.app; headings, code, table paginate sanely.

- [ ] **M3-4 — Copy matrix.** Edit ▸ Copy as Markdown / HTML / Rich Text, each for
  selection and whole document. Rich text via `NSAttributedString(html:)` on the
  export HTML. Pasteboard gets *only* the chosen type (plus plain text).
  *Verify:* Copy as HTML → paste in a browser form shows markup; Copy as Rich Text →
  paste in Pages shows formatting; Copy as Markdown → plain source.

- [ ] **M3-5 — Print.** File ▸ Print: formatted (via the preview web view) and plain
  text (via `NSTextView`); both support print-to-PDF from the system dialog.
  *Verify:* ⌘P shows the formatted doc; "Print plain text" shows the source.

- [ ] **M3-6 — Pre-export warnings.** `MarkdownCore.Links.extract` (tested) → check
  local image/link targets exist; show a sheet listing broken ones before export.
  *Verify:* reference a missing image → export warns, lists the path, lets you continue.

- [ ] **M3-7 — Word export (P1).** `.docx` via a maintained Swift lib or our own minimal
  OOXML writer from the AST. Decide in-ticket; record the choice in an ADR.
  *Verify:* `.docx` opens in Pages/Word with headings, lists, bold/italic intact.

- [ ] **M3-8 — Project archive (P2).** Zip of the folder-wrapped document. Pick a
  maintained zip lib.
  *Verify:* archive unzips to the original folder.

Exit criteria for M3: export one doc to `.md`, `.html`, `.pdf` and open each in another
app; Copy as HTML pastes into a browser; print preview renders.
