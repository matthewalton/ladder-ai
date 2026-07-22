# 0008 — Import-first application creation

Status: accepted (agreed with the human at plan, 2026-07-22; supersedes
decisions/0004's manual add and decisions/0007's standalone tailor entry;
amends the scope of decisions/0005 and 0006)

## Context

The board carried two side-by-side creation paths — the manual add
(decisions/0004) and tailor-and-export (decisions/0007) — both demanding
typing: company, role title, and a pasted JD. The human's actual entry
point, settled at plan: *I found a job posting; I want a CV for it.* Typing
what the posting already says is friction on the app's most important flow,
and the two small toolbar buttons buried the main action.

## Decision

1. **One hero action — "Create CV for new application"** — is the board's
   only creation door, in the shell toolbar and as the empty state's lead
   action. The manual add sheet and the standalone tailor entry are removed
   ([PIPEBOARD-17/18/19/20/34] retired).
2. **Job details are extracted, never typed.** The import surface takes a
   posting link or a PDF. Links fetch through the injected seam with the
   JobPosting ld+json pre-cleaning kept from [PIPEBOARD-28]; PDFs go through
   the shared extractor. The resulting text is structured by the
   intelligence service via `Prompts/job-details.md` into company, role
   title and a cleaned job description — **LLM always, both doors**. The
   API-key dependency is accepted: the key already exists for tailoring, and
   uniform extraction beats a markup-only fast path with divergent quality.
   This does not reopen decisions/0005/0006's no-LLM stance — that stays
   accepted for *re-import onto an existing application*, where the text is
   the artefact; creation needs the structured fields.
3. **The Application is created at import time, as `.draft`** — it lands on
   the board before any CV exists, and survives an abandoned tailor. The
   draft → applied stamp still belongs to [PIPEBOARD-9] and to export
   ([CVEXPORT-10]).
4. **Pause at the application.** Import selects the new row and opens its
   detail; a prominent "Create CV" there starts the tailor against the
   stored JD (Tailor decisions/0008), and export attaches the CV to this
   application (CVExport decisions/0006) — never a fresh one.
5. **The pasted link lands in `source`** (the file door lands the file
   name) — superseding decisions/0006's "the link is not stored" for the
   creation path. No schema change; `source` was built for provenance.
6. **Invalid extraction gets exactly one repair request** — the Tailor
   decisions/0004 loop, same bounds, same rationale.

## Consequences

- No offline or manual creation: a referral-style pursuit with no posting
  cannot be tracked, and every creation costs one LLM call (two worst-case).
  Accepted for now; reversing it is a new decision.
- calendar-sync's hand-testing convenience from decisions/0004 goes with the
  manual add, but its own `confirmCreate` path — the other consumer of
  `PipelineStore.createApplication` — is untouched; the seam survives as the
  shared creation rule-keeper and grows a `jobDescription` parameter.
- Auth-walled and JS-only links still fail at fetch; the PDF door is the
  fallback and the failure copy steers to it.
- The detail's raw JD re-import ([PIPEBOARD-22..28]) remains the correction
  path for a bad extraction.
