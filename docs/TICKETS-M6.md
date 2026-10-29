# M6 — Publishing to the open web

Milestone goal: push the current document as a **draft** to WordPress first, then
Ghost, Micropub, Micro.blog, using their public APIs. Never an instant public post.
**Last milestone by decision (2026-10-28).** Depends on M1 + M3-2 (HTML payload). Credentials live in Keychain only.

Legend: `[ ]` todo · `[x]` done. Keep `swift build` and `swift run mdcheck` green.
Network clients are tested against a mock `URLProtocol`; request builders are pure
and unit-tested.

---

- [ ] **M6-0 — Publishing core.** `PublishTarget` protocol: `createDraft(post) → RemotePost`,
  `updateDraft(id, post)`, `uploadImage`. `PublishPayload` = HTML or Markdown (per
  account). `RemotePostMap`: local document ↔ (account, remote id), stored in the
  document's xattrs. All in a new `Publishing` target (no AppKit).
  *Verify:* unit tests for the map round-trip and payload selection.

  *Note (M1-5 review, 2026-10-29):* `MarkdownCore.html` passes raw HTML and
  `javascript:` URLs through unchanged, which is fine for the local preview. The
  publish payload must sanitise both before anything leaves the machine.

- [ ] **M6-1 — Accounts + Keychain.** `WebServiceAccount` (service, display name,
  endpoint, payload choice) in Application Support; secret in Keychain via
  `Security.framework` (no third-party wrapper). Preferences ▸ Publishing pane
  (SwiftUI leaf): add / edit / remove account.
  *Verify:* add an account → entry in Keychain Access; remove → gone.

- [ ] **M6-2 — WordPress, self-hosted.** WP REST API, application password (Basic).
  Create draft post (`status=draft`), upload media, update post.
  *Verify:* against a real site: Publish → draft appears in wp-admin, not public.

- [ ] **M6-3 — WordPress.com.** OAuth2 via `ASWebAuthenticationSession`; same REST
  calls through the `.com` endpoint.
  *Verify:* sign in → token stored → draft created on a `.com` blog.

- [ ] **M6-4 — Publish UI.** File ▸ Publish to ▸ (account). Sheet: title (from first
  H1), payload, tags; progress; result with "Open on site" link. Republish updates the
  mapped post instead of creating a new one.
  *Verify:* publish twice → one remote draft, updated.

- [ ] **M6-5 — Ghost.** Admin API: Staff Access Token → JWT; create/update draft
  (`status: draft`); image upload.
  *Verify:* draft appears in Ghost admin.

- [ ] **M6-6 — Micropub.** Endpoint URL + token; `h-entry` with `post-status=draft`;
  media endpoint discovery.
  *Verify:* against a Micropub test endpoint, draft created.

- [ ] **M6-7 — Micro.blog.** Email magic-link sign-in, then Micropub to micro.blog.
  *Verify:* draft posted to a test Micro.blog account.
- [ ] **M6-8 (P2) — Medium.** Integration token; create draft via Medium API.
  *Verify:* draft appears on Medium.

- [ ] **M6-9 (P2) — Substack.** `WKWebView` login → read `substack.sid` cookie → minimal
  internal-endpoint client (create/put draft, upload image) + Markdown→ProseMirror
  converter in `MarkdownCore` (tested).
  *Verify:* draft appears in the Substack dashboard; paywall node survives re-read.

Exit criteria for M6: add a WordPress account (token in Keychain), Publish → draft on
the site, nothing public; republish updates the same post. Ghost/Micropub/Micro.blog
each pass their own ticket.
