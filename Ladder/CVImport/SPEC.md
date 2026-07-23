---
key: CVIMPORT
---

# CV Import

Drop a PDF or docx CV, extract its text on-device, have the intelligence
service propose the CV's full content — identity, contact, roles with their
achievements and skills, education, projects, interests — review every
proposed item, and confirm to make the Profile fresh: the included items
become the Profile's entire content through the Profile slice's replace
pathway, creating the Profile when none exists (decisions/0007). This slice
owns the extraction step, the `IntelligenceService` protocol and its fixture
implementation, the proposal/review model, the replace, and
`Prompts/import.md`.

Live in production: the import run reads the Anthropic API key from the
Keychain and calls the shared live `IntelligenceService` — pinned model per
Tailor decisions/0003, key store shared via `Ladder/Shared/Services/`
(decisions/0005). Without a stored key the run refuses and points to Settings;
production never falls back to fixtures (Tailor decisions/0002). Failures are
fail-fast with the reason surfaced — no repair request (decisions/0004). Tests
and previews stay on `FixtureIntelligenceService`'s canned JSON from
`LadderTests/Fixtures/`. Import is a hard refresh (decisions/0007, superseding
0001 and 0003): a run onto an existing Profile is confirmed before it starts,
and the review remains mandatory. The proposal covers the whole CV
(decisions/0008, superseding 0002); a CV's summary/profile paragraph stays
not-imported — the CV summary is generated per application at tailor time
(Tailor slice). Contact is belt-and-braces: on-device detection overrides the
model's proposal for email, phone, and link (decisions/0009). Projects
propose a description and skills, not points (decisions/0010; Profile
decisions/0009).

Out of scope: tailoring, PDF export, automatic duplicate matching,
retry-with-repair (decisions/0004), streaming, cancellation UX.

## [CVIMPORT-1] Importing a PDF CV produces a proposal of roles for review

The tracer criterion: file in → extracted text → intelligence service →
proposal held for review. It proves the extraction step (PDFKit), the
`IntelligenceService` protocol, the fixture implementation, and the import
flow's state machine end to end.

Exercised with a small fixture PDF in `LadderTests/Fixtures/` and
`FixtureIntelligenceService` returning the canned import proposal. The proposal
is transient — nothing is persisted until the merge ([CVIMPORT-5]).

## [CVIMPORT-2] Importing a docx CV produces a proposal of roles for review

The docx extraction path: `AttributedString`'s Office Open XML reading, no
third-party dependency. Same downstream flow as [CVIMPORT-1]; exercised with a
fixture docx.

## [CVIMPORT-4] Every proposed item enters review as included

Nothing is pre-excluded on the user's behalf. The review is where the user
excludes items they don't want on the fresh Profile (decisions/0007 superseded
0003's dedup framing — with replace semantics there is nothing on file to
duplicate).

## [CVIMPORT-6] A proposed item excluded in review does not land in the Profile

Per-item exclusion:

- Excluding a role excludes all of its achievements with it.
- Excluding one achievement keeps the role and its other achievements
  confirmable.
- Excluding a proposed skill keeps the achievement; the skill is simply not
  attached. The same holds for a project's proposed skills (decisions/0010).
- The same rule covers education entries, projects, and interests
  ([CVIMPORT-24], [CVIMPORT-26], [CVIMPORT-28]): an excluded item is simply
  absent from the replacement.

## [CVIMPORT-7] Merged roles and achievements are still present after the app relaunches

The confirmation writes through the Profile slice's replace pathway — the same
persistence layer the Profile editor uses. Relaunch is exercised by closing and
reopening the `ModelContainer` against the same store URL, as in the Profile
slice's tests.

## [CVIMPORT-10] A proposal failing schema validation fails the import

The service's JSON must match the proposal schema. On mismatch the import ends
in the failed state with `ImportError.proposalInvalid`, no review is offered,
and the Profile is unchanged. No retry-with-repair — fail-fast is deliberate
(decisions/0004); the failure carries the validation reason ([CVIMPORT-17]).

## [CVIMPORT-11] A CV yielding no extractable text fails the import

An image-only or empty PDF extracts no text. The import ends in the failed
state with `ImportError.extractionFailed` before any service call; the Profile
is unchanged.

## [CVIMPORT-12] A file that is neither PDF nor docx is rejected

Judged by file type before extraction is attempted:
`ImportError.unsupportedFileType`. Accepted types are exactly PDF and docx
(ROADMAP).

## [CVIMPORT-13] The proposal request contains the versioned import prompt

`Prompts/import.md` is born in this slice: the canonical, versioned import
prompt, loaded at runtime — never an inline string. The fixture service records
the request it receives; the recorded prompt equals the file's content. The
same prompt travels in live requests — tests exercise the seam with the fixture
service, so the prompt stays real and versioned without network access.

## [CVIMPORT-14] Starting an import with no API key stored is refused

Checked at import start, before extraction and before any service call:
`ImportError.apiKeyRequired`. The refusal directs the user to Settings to enter
a key (same Settings scene the tailor slice owns). Production never falls back
to fixture data (Tailor decisions/0002, adopted by decisions/0005);
`FixtureIntelligenceService` stays a test and preview concern.

## [CVIMPORT-15] The import run creates its live service with the stored API key

The store takes a key store plus a `makeIntelligence` factory (the
`TailorStore` shape) and calls the factory with exactly the key read from the
key store. Exercised without network: a fake key store holding a known key and
a factory that records the key it was handed. The default factory is the shared
`AnthropicIntelligenceService` (pinned model, Tailor decisions/0003).

## [CVIMPORT-16] A failed live request ends the import in the request-failed state

Transport failure is not validation failure (decisions/0004): a service call
that throws — `LiveServiceError.httpFailure(status:)`, `emptyResponse`, or any
other transport error — ends the import with `ImportError.requestFailed`,
distinct from `proposalInvalid`. The failure message names what failed (the
HTTP status when there is one) so the user knows whether to retry, fix their
key, or report a bad extraction. No review is offered; the Profile is
unchanged.

## [CVIMPORT-17] A proposal validation failure carries the reason the proposal was rejected

Fail-fast earns its keep by being specific (decisions/0004): when the service's
JSON fails proposal validation, the failed state carries the reason — which
part of the proposal was rejected (e.g. malformed JSON, or a missing/empty
required part) — and the review UI shows it. A bare "proposal invalid" with no
reason does not satisfy this criterion.

## [CVIMPORT-18] A proposal wrapped in a markdown code fence produces a review

Live models mirror the fenced schema example in `Prompts/import.md` and wrap
their JSON in a ```json fence despite the "only JSON" instruction. The fence
is presentation, not content: it is stripped before schema validation, so a
fenced-but-valid proposal reaches review exactly as a bare one does. The
prompt also forbids fences explicitly, but tolerance must not depend on the
model obeying. Anything else non-JSON — preamble prose — still fails with its
reason ([CVIMPORT-17]); a response cut off at the token limit fails with its
own truncation reason ([CVIMPORT-19]).

## [CVIMPORT-19] A response cut off at the model's token limit fails the import with a truncation reason

The guard lives in the shared `AnthropicIntelligenceService`: the Messages
response's `stop_reason` is decoded alongside the content blocks, and
`"max_tokens"` throws `LiveServiceError.truncated` before any text is returned
— truncated JSON never reaches proposal validation, so the failure cannot
masquerade as "the response was not valid JSON" ([CVIMPORT-17]).

The import store maps the throw to its own `ImportError.responseTruncated`
(decisions/0006), distinct from `requestFailed` ([CVIMPORT-16]): the
failed-state message names the length problem — the CV may be too long to
import whole — because "check your connection and try again" is wrong advice
when a retry would truncate again at the same 16k cap. The Profile is
unchanged and no review is offered, as with every failed import.

## [CVIMPORT-20] Confirming the review replaces the Profile's content with the included items

The hard refresh (decisions/0007, superseding [CVIMPORT-5]'s add-alongside
merge): the included items become the Profile's entire content through the
Profile slice's replace pathway ([PROFILE-17]). Previously-curated roles,
education, projects, interests, and Tags are gone afterwards — that is the
point; the pre-run confirmation warned about it ([CVIMPORT-22]).

- Included roles land with their included achievements in proposed order;
  role ordering in the editor follows dates, not insertion.
- Two included achievements naming the same skill share one Tag — the
  [PROFILE-8] rule applied inside the replace; there is no pre-existing pool
  to reuse (supersedes [CVIMPORT-8]). Project skills join the same pool
  ([PROFILE-21]).
- Nothing lands before confirmation — the review is mandatory; there is no
  import-without-review path.

## [CVIMPORT-21] Confirming a review with no Profile on file creates the single Profile

Import is now a creation path (decisions/0007, superseding decisions/0001;
Profile decisions/0008, [PROFILE-18]): from the create-profile empty state, a
dropped CV runs, reaches review, and confirming creates the Profile with the
included content. The single-profile invariant holds ([PROFILE-4]); this
branch has no replace confirmation — there is nothing to lose
([CVIMPORT-22]).

## [CVIMPORT-22] Starting an import onto an existing Profile requires confirmation before the run begins

Protects the curated Profile from a mis-click, before any tokens are spent:
when a Profile exists the flow waits for an explicit confirm that the import
will replace it; declining aborts before extraction and before any service
call. With no Profile on file there is no confirmation step. The
needs-confirmation decision is a pure helper so the rule is testable without
views (the [PIPEBOARD-25] stance); dialog chrome is visual-verify.

## [CVIMPORT-23] The proposal carries the CV's identity and contact details

Name, headline, and contact — email, phone, location, link — from the CV's
header (decisions/0008). Identity is not a per-item reviewable: it always
travels with the confirmation (a fresh Profile needs a name; the review shows
it). The schema requires a non-empty name — the replace rejects an empty one
([PROFILE-3]'s rule) — so a proposal without one fails validation with its
reason ([CVIMPORT-17]). Contact fields the CV lacks land as empty strings.
The model's contact is only half the story: detected values override it
([CVIMPORT-29], decisions/0009).

## [CVIMPORT-24] The proposal lists the CV's education entries for review

Institution, qualification, `yyyy-MM` dates (null end = in progress), and the
detail line (grade, honours) when the CV states one. Each entry is a proposed
item — included by default ([CVIMPORT-4]), excludable ([CVIMPORT-6]).

## [CVIMPORT-28] The proposal lists the CV's projects with description and skills for review

Replaces [CVIMPORT-25]'s points shape (decisions/0010; Profile
decisions/0009): each project proposes name, link, one-line summary, a
multi-line description — prose in the CV's own wording, the project's
bullets/sentences joined, never invented — and skill names for the project as
a whole. Excluding a project excludes it wholesale; excluding one proposed
skill keeps the project confirmable ([CVIMPORT-6]).

## [CVIMPORT-26] The proposal lists the CV's interests for review

Short strings in the CV's own order, each excludable. Case-insensitive
dedup happens in the replace pathway ([PROFILE-14]'s rule), not in the
proposal.

## [CVIMPORT-27] A CV section outside the import scope is listed as not-imported in the review

The not-imported guarantee survives the scope growth (decisions/0008,
superseding [CVIMPORT-9]'s education/projects framing): content the proposal
cannot place — the summary/profile paragraph (deliberately: the CV summary is
generated per application at tailor time), certifications, references — is
listed in the review and never written anywhere.

## [CVIMPORT-29] A contact value detected in the CV overrides the service's proposal for that field

Contact detection (decisions/0009) runs on-device between extraction and
review: `NSDataDetector` over the extracted text for email, phone, and URL,
plus the PDF's link annotations for URLs the text layer never shows. A
detected value replaces the model's proposal for that field before the review
is shown — contact import must not depend on the model obeying the prompt.

- First match per field wins: a CV header leads with the owner's details; a
  referee's email later in the document never displaces one detected earlier.
- Location is not detected — no deterministic detector is reliable for
  free-form location lines; it stays with the model ([CVIMPORT-23]).
- Worked example (the real CV that motivated this): header text
  `London, UK · 07541 964763 · mattalton97@gmail.com` with a null-contact
  model response still reaches review with that phone and email filled.

## [CVIMPORT-30] A contact field with no detected value keeps the service's proposed value

The complement of [CVIMPORT-29]: detection only ever fills, never blanks. A
CV with no URL anywhere — no text-layer link, no link annotation — leaves the
link field exactly as the model proposed it (empty string when the model
returned null, [CVIMPORT-23]); location always passes through untouched.

## [CVIMPORT-31] The proposal lists each achievement's title and description for review

The title split (Profile decisions/0010): `Prompts/import.md` instructs the
service to split a CV bullet with a bold lead-in phrase — "**Shipped the
pipeline** - cut deploy time 80%" — into title "Shipped the pipeline" and
description "cut deploy time 80%"; a bullet with no lead-in proposes a null
title and the whole bullet as the description. Confirmed items land the
title through the replace pathway ([PROFILE-17]) onto `Achievement.title`.
The canned fixture proposal carries both titled and titleless achievements.
