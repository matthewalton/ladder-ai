# 0006 — JD import from a pasted link

Status: accepted (2026-07-20, agreed with the human; supersedes the
"URL import / scraping stays out" consequence of decisions/0005)

## Context

decisions/0005 scoped the JD import to user-supplied files. The human then
asked for a second path the same day (Baton ticket 156): some JDs exist only
as links. Fetching a page the user explicitly pastes is user-triggered
egress to a site of their choosing — consistent with the privacy posture
(ARCHITECTURE.md §2), whose hard requirements concern audio, transcripts,
and the API key.

## Decision

1. **Plain fetch + on-device HTML→text.** A `URLSession` GET of the pasted
   URL, then HTML→text conversion on-device — no offscreen WebKit render, no
   LLM cleanup, matching 0005's plain-extraction stance. A response whose
   bytes are a PDF (`%PDF` magic) extracts via PDFKit instead.
2. **The link is not stored.** The text is the artefact; a link worth
   keeping goes in Notes or Source by hand. No schema change.
3. **Same guard rails as the file path.** Confirm-then-replace onto a
   non-empty JD ([PIPEBOARD-25]); any failure leaves the JD untouched
   ([PIPEBOARD-24]).
4. **The fetch is injected into the store** so the criteria are testable
   offline with canned bytes.

## Consequences

- Server-rendered job pages (Greenhouse, Lever, Ashby…) import well;
  JS-only and auth-walled pages (LinkedIn behind login) fail or land junk —
  the editor is the correction path, and that limitation is accepted for v1.
- Page text lands raw, nav and footer included; an LLM cleanup pass, if
  ever wanted, remains a new decision.
- Rejected alternatives: offscreen WKWebView (heavier, still blind behind
  login walls) and LLM cleanup (breaks the no-key, no-prompt posture of the
  import).
