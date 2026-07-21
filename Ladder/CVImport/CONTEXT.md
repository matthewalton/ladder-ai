# CV Import — language

Slice-local terms. `Profile`, `Role`, `Achievement`, and `Tailoring` are defined
in the root `CONTEXT.md`; `SkillTag` in the Profile slice's `CONTEXT.md`.
Neither is restated here.

**Proposal**:
The structure the intelligence service returns for an extracted CV — identity
and contact, proposed roles, achievements, and skills, education, projects,
interests (decisions/0008), plus any not-imported sections — held in memory
for review, never persisted.
_Avoid_: draft profile, parsed CV, suggestions, import result

**Proposed item**:
One reviewable unit inside a proposal — a proposed role, achievement, skill,
education entry, project, project skill, or interest — carrying its
included/excluded state. Identity and contact are not proposed items: they
always travel with the confirmation.
_Avoid_: candidate, entry, line item

**Contact detection**:
The on-device pass between extraction and review that finds email, phone,
and URL in the CV — `NSDataDetector` over the extracted text plus the PDF's
link annotations — and overrides the proposal's matching contact fields
(decisions/0009). Detection fills, never blanks; location is never detected.
_Avoid_: contact parsing, scraping, autofill

**Review**:
The mandatory per-item confirmation step between proposal and replace; the only
route by which proposed items reach the Profile, and the place unwanted items
are excluded (decisions/0007).
_Avoid_: approval screen, confirmation dialog, preview

**Replace**:
Writing the review's included items as the Profile's entire new content
through the Profile slice's replace pathway (decisions/0007; Profile
decisions/0008). Creates the Profile when none exists; never leaves a merged
hybrid.
_Avoid_: merge (the pre-hard-refresh term), save, apply, commit, sync

**Replace confirmation**:
The explicit confirm required before a run starts when a Profile already
exists — before extraction and any service call. Absent when no Profile is on
file.
_Avoid_: overwrite warning, destructive prompt

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
CV content the proposal assigns outside the import scope — the
summary/profile paragraph (deliberately: the CV summary is generated per
application at tailor time), certifications, references — listed in the
review so nothing is silently dropped, and never written anywhere.
_Avoid_: skipped section, dropped content, unsupported content
