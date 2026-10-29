# ADR-001: AppKit-primary, SwiftUI for leaf views

**Status:** accepted · **Date:** 2026-10-28

## Decision

Build the app shell, document layer, editor, and library in **AppKit**. Use
**SwiftUI only for leaf views** that don't involve rich text or the document model —
preferences panes, dialogs, the stats popover, small inspectors.

## Why

1. **The editor must be `NSTextView`.** Live Markdown styling, typewriter mode, focus
   mode, author-attributed text, and table editing all need fine-grained control over
   text layout and attributes. SwiftUI's `TextEditor` can't do this; fighting it wastes
   the whole project.
2. **The document model is `NSDocument`.** Autosave, version browser, file coordination,
   restorable state, folder-wrapped documents — all come free from AppKit's
   `NSDocument`/`NSDocumentController`. SwiftUI's `DocumentGroup` is too restrictive
   (poor multi-pane, weak file-system/library control).
3. **The library sidebar is an outline/tree** with drag-drop, context menus, live
   file-system updates — a natural `NSOutlineView`, awkward in SwiftUI.
4. **A proven split.** Mature Mac editors pair AppKit text editing with SwiftUI only
   in leaf views. We adopt the same split rather than relitigate it.

## Consequences

- Core targets are AppKit; `NSHostingController`/`NSHostingView` bridges SwiftUI leaf
  views in where they help.
- No Mac Catalyst, no SwiftUI `App` lifecycle — classic `NSApplicationMain`-style entry.
- Preview is `WKWebView` (generated HTML + themeable CSS), not a native SwiftUI render.
- Markdown parsing is **not** ours: depend on `apple/swift-markdown`.

## Not chosen
- *SwiftUI-primary*: blocked by rich-text editing limits. Revisit only if SwiftUI gains
  a real attributed-text editor.
- *Catalyst / cross-platform*: out of scope; this is a focused macOS app.
