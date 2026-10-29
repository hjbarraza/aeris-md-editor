# PRD — aeris-md-editor

A free, native macOS Markdown editor. Independently built. Files stay plain text
and local; publishing to the open web is first-class.

## 1. Vision & principles

- **Plain text, your files, your folders.** Every document is a real `.md` file on
  disk. No proprietary container, no lock-in. Any other tool can read our files.
- **Free, no accounts.** No login, no trial, no subscription, no payment gating.
  Everything the app does works offline on day one.
- **Publish to the open web.** First-class push to WordPress, Ghost, Micropub,
  Micro.blog, Medium using their public APIs.
- **Native and fast.** AppKit/SwiftUI, incremental parsing, no Electron.
- **Adopt, don't rebuild.** Use `swift-markdown` for parsing; don't reinvent solved problems.

## 2. Non-goals

- No account system, licensing, trials, or in-app purchase.
- No proprietary typography engine or template marketplace (ship a couple of good
  built-in themes instead).
- No bespoke cloud sync service (rely on the user's own iCloud/Dropbox/git folders).

## 3. Architecture

| Concern | Approach |
|---|---|
| Markdown parse | `apple/swift-markdown` (CommonMark + GFM) |
| Document | `NSDocument` subclass; plain `.md` on disk |
| Per-doc metadata | extended file attributes (xattr), never in file content |
| Editor | `NSTextView` + incremental re-styling on edit |
| Preview | `WKWebView` (modern), generated HTML + themeable CSS classes |
| Library | folder tree + saved-search "smart folders" + favorites + tags |
| Diff/version | `diff-match-patch` (open source) |
| Publishing | direct HTTP clients to each service's public API |
| Automation | URL scheme (x-callback-url style) |

## 4. Feature requirements

### 4.1 Document & files (P0)
- Open/edit/save plain `.md` (and `.markdown`, `.txt`) files.
- Auto-name new drafts from first line of content.
- Autosave + macOS version browser.
- Folder-wrapped documents: attach images alongside markdown in a folder bundle.
- Store cursor/scroll position in xattrs (survives reopen; file stays clean).

### 4.2 Library / organizer (P0)
- Sidebar tree of on-disk folders ("Locations").
- Favorites (pinned folders/files).
- Tags via inline `#hashtags`, grouped in the sidebar.
- Smart Folders = saved search queries (by text, tag, date).
- Quick search / jump-to-file (⌘-K style) across the whole library.
- Dual navigation history: document back/forward AND library back/forward.
- File ops in-sidebar / right-click: new file, new folder, duplicate, rename,
  move to trash, favorite, reveal in Finder, Get Info, Share, Export, Print, Copy.
- **Tabbed windows**: open documents in new tabs (macOS native tabs), "Show All Tabs".
- Sort/display: by Date Modified/Created, Name, Extension; oldest/newest first;
  pin folders to top; show/hide date; show/hide text excerpts.
- Live refresh when files change on disk (NSFilePresenter).

### 4.3 Editor (P0)
- Live markdown syntax styling (inline + block) with incremental re-parse.
- Formatting commands: bold/italic/**highlight**/code/strikethrough, headings (1–6),
  quote, lists, link, image, footnote, wikilink `[[...]]`, callout/alert, **comment**,
  display math (LaTeX), horizontal rule, page break, table of contents, clear styles.
- **Lists incl. task lists**: List, Ordered List, **Task**, **Ordered Task** (GFM
  checkboxes; completed/total tasks surfaced in stats).
- **Content Blocks (transclusion)** — embed another file's content into a document (P2).
- Full table editor: add/delete/move rows & columns, merge/unmerge, align, sort, transpose, reformat.
- Autocomplete popup for hashtags, wikilinks, file paths.
- Typewriter mode (keep caret line centered).
- Focus mode (dim all but current sentence/paragraph; scope selectable).
- **Live stats** (popup): characters, characters without spaces, words, sentences,
  **reading time**, **speaking time**, tasks (done/total). Pick which shows in the bar.
- Spellcheck + standard macOS text checking.

### 4.4 Writing aids (P1)
- Style check / syntax highlighting of parts of speech (adjectives, adverbs, etc.).
- User-definable linguistic patterns (custom highlight rules).

### 4.5 Authorship / review (P2 — differentiator, optional)
- Multi-author attribution (color per author), mark/paste-as-author.
- Range annotations/comments.
- **Authorship analytics**: % of words by **Human / AI / Reference** (shown in the
  stats popup). This is the standout modern feature — "how much of this did AI write" —
  and pairs naturally with our "free + open web" positioning. Consider promoting to P1.
- *Otherwise lower priority; include only if it doesn't slow P0/P1.*

### 4.6 Preview (P0)
- Live HTML preview in `WKWebView`, themeable via CSS classes.
- Adjustable width / display mode.
- Editor↔preview scroll sync.
- PDF preview with fit-page / fit-width zoom.

### 4.7 Export & copy (P0) — **free, ungated**
- Export to (confirmed from the reference UI): **Markdown, HTML, PDF, Microsoft Word,
  Project Archive** (zip of the folder-wrapped document — hence a zip lib). P0: Markdown/HTML/PDF; Word + Archive = P1/P2.
- Print: formatted + plain text; print-to-PDF.
- Copy matrix: (Markdown | HTML | Rich text) × (selection | whole document).
- Pre-export warnings for broken embedded content (missing images/links).

### 4.8 Publishing to the open web (P0/P1)
Each target: add account (store token in Keychain), choose HTML-or-Markdown payload,
push current document as a post. All via documented public APIs.

| Target | API | Priority |
|---|---|---|
| WordPress (.com + self-hosted) | WP REST API | P0 |
| Ghost | Ghost Admin API (JWT) | P1 |
| Micropub (IndieWeb) | Micropub spec | P1 |
| Micro.blog | Micro.blog API | P1 |
| Medium | Medium API | P2 |
| Substack | Unofficial (internal endpoints + session cookie) | P2 |

- Publishing **creates a draft on the remote service that the user reviews before
  it goes live** — never an instant public post. (Confirmed from the reference UI:
  "creates drafts which you can review before publishing.") Match this: it's safer
  and is the expected mental model.
- Each service stores one credential: Ghost = Staff Access Token + API URL;
  Medium = integration Token; Micropub = endpoint URL + token; Micro.blog = email
  magic-link; WordPress = .com OAuth or self-hosted URL + app password.
- Per account, choose **HTML or Markdown** as the push payload.
- **Substack** is a special case — no official API. Auth is a browser **session
  cookie** (`substack.sid`, captured via an embedded WebView login); posts are
  created as drafts through Substack's internal endpoints, with the body converted
  to Substack's ProseMirror doc JSON. Notes (short-form) have no API and need WebView
  automation. Heavier lift → P2.
- Publishing is **push-on-demand**, per document — not continuous sync.
- Update/republish an existing post (keep remote post id mapping locally).

### 4.9 Automation / interop (P1)
- URL scheme to open/create/append documents and trigger export/publish from
  scripts or other apps (x-callback-url style).

## 5. Milestones

- **M1 (core editor):** NSDocument + swift-markdown + live styling + save/open + preview. 
- **M2 (library):** sidebar, folders, tags, smart folders, quick search.
- **M3 (export):** Markdown/HTML/PDF export, copy matrix, print.
- **M4 (publishing):** WordPress first, then Ghost/Micropub/Micro.blog.
- **M5 (polish):** focus/typewriter mode, style check, automation URL scheme.

## 6. Open questions
- SwiftUI vs AppKit for the shell? (Editor itself is NSTextView either way.)
- Preview rendering: WKWebView HTML vs native SwiftUI render (`swift-markdown-ui`)?
- Distribution: Mac App Store (sandbox limits folder access) vs direct + Sparkle?
