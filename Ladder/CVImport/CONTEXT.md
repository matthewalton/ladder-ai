# CV Import — language

Slice-local terms. `Profile`, `Role`, `Achievement`, and `Tailoring` are defined
in the root `CONTEXT.md`; `SkillTag` in the Profile slice's `CONTEXT.md`.
Neither is restated here.

**Proposal**:
The structure the intelligence service returns for an extracted CV — proposed
roles, achievements, and skills, plus any not-imported sections — held in memory
for review, never persisted.
_Avoid_: draft profile, parsed CV, suggestions, import result

**Proposed item**:
One reviewable unit inside a proposal — a proposed role, achievement, or skill —
carrying its included/excluded state.
_Avoid_: candidate, entry, line item

**Review**:
The mandatory per-item confirmation step between proposal and merge; the only
route by which proposed items reach the Profile, and the place duplicates are
rejected (decisions/0003).
_Avoid_: approval screen, confirmation dialog, preview

**Merge**:
Writing the review's included items into the existing Profile through the
`ProfileStore` pathway. A merge never creates the Profile and never edits
existing Profile content.
_Avoid_: save, apply, commit, sync

**Extraction**:
Turning the dropped file into plain text on-device — PDFKit for PDF,
`AttributedString` Office Open XML reading for docx. Extraction produces text;
structuring it is the service's job.
_Avoid_: parsing, OCR, scraping

**Truncated response**:
A live reply the model cut off at its `max_tokens` cap — `stop_reason ==
"max_tokens"` — detected by the shared service before any JSON parsing and
surfaced as its own failure (decisions/0006), never as invalid JSON.
_Avoid_: cut-off response, length-limit error, incomplete response, overflow

**Not-imported section**:
CV content the proposal assigns outside the import scope (education, projects) —
listed in the review so nothing is silently dropped, and never merged.
_Avoid_: skipped section, dropped content, unsupported content
