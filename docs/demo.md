# Aeris demo

A tour of what the editor renders today. Extended with each visible feature.

## Inline

Some **bold**, *italic*, ~~strike~~, `code` and a [link](https://example.com).
Tags: #draft #aeris. Wiki link: [[Another note]].

## Lists

- item one
- item two
  - nested
- [ ] a task
- [x] a done task

1. first
2. second

> A quote, with **bold** inside.

## Code

```swift
let greeting = "# not a heading"
```

## Table

| Feature | Status |
|---------|--------|
| Editor  | live   |
| Preview | live   |

## Window

⌘⌥S hides and shows the library sidebar; the layout is kept across launches.

## Library

File > Add Location… and pick `docs/demo-library`. Expect Drafts, Notes, Welcome.md; Notes shows Archive and Meeting.txt (no `data.json`, no hidden file).

Click a file in the library: it replaces the document in this window; edits to the previous file are saved first; an unsaved new document asks before it goes.
