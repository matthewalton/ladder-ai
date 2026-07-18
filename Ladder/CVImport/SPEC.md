---
key: CVIMPORT
---

# CV Import

Drop a PDF or docx CV, extract its text on-device, have the intelligence service
propose Roles, Achievements, and skills, review every proposed item, and merge
the included ones into the existing Profile. This slice owns the extraction
step, the `IntelligenceService` protocol and its fixture implementation, the
proposal/review model, the merge, and `Prompts/import.md`.

Live in production: the import run reads the Anthropic API key from the
Keychain and calls the shared live `IntelligenceService` — pinned model per
Tailor decisions/0003, key store shared via `Ladder/Shared/Services/`
(decisions/0005). Without a stored key the run refuses and points to Settings;
production never falls back to fixtures (Tailor decisions/0002). Failures are
fail-fast with the reason surfaced — no repair request (decisions/0004). Tests
and previews stay on `FixtureIntelligenceService`'s canned JSON from
`LadderTests/Fixtures/`. Import requires an existing Profile (decisions/0001);
the proposal covers roles, achievements, and skills only (decisions/0002); the
review screen is the dedup (decisions/0003).

Out of scope: tailoring, PDF export, Profile creation via import, automatic
duplicate matching, `Education`/`Project` models, retry-with-repair
(decisions/0004), streaming, cancellation UX.

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

## [CVIMPORT-3] Starting an import when no Profile exists is refused

Import merges into the Profile and never creates it — the create-profile empty
state remains the only creation path (Profile decisions/0002, this slice's
decisions/0001). The flow refuses at start, before any extraction: the error is
`ImportError.profileRequired`. The UI only offers import entry points inside an
existing Profile, but the flow enforces the rule regardless of caller.

## [CVIMPORT-4] Every proposed item enters review as included

Review is the dedup (decisions/0003): there is no automatic duplicate
detection, so nothing is pre-excluded on the user's behalf. The user excludes
items they don't want — including duplicates of what's already on file.

## [CVIMPORT-5] Confirming the review adds each included proposed role with its achievements to the Profile

The merge. Included roles land as `Role`s owning their included `Achievement`s,
written through the existing `ProfileStore` pathway, alongside any roles
already on the Profile. Achievements keep their proposed order via the
persisted sort index ([PROFILE-7]); roles carry their proposed dates, and role
ordering in the editor follows dates, not insertion (SwiftData to-many
relationships are unordered).

Nothing lands before confirmation — the review is mandatory, there is no
import-without-review path.

## [CVIMPORT-6] A proposed item excluded in review does not land in the Profile

Per-item exclusion:

- Excluding a role excludes all of its achievements with it.
- Excluding one achievement keeps the role and its other achievements mergeable.
- Excluding a proposed skill keeps the achievement; the skill is simply not
  attached.

## [CVIMPORT-7] Merged roles and achievements are still present after the app relaunches

The merge writes through the same persistence pathway the Profile editor uses.
Relaunch is exercised by closing and reopening the `ModelContainer` against the
same store URL, as in the Profile slice's tests.

## [CVIMPORT-8] Merging a proposed skill whose name matches an existing SkillTag reuses the shared tag

Skill-name deduplication is the store's, per [PROFILE-8]: comparison is
case-insensitive and ignores leading/trailing whitespace, and the surviving tag
keeps the name as first entered. A proposal naming " swift " where the Profile
already has "Swift" attaches the existing "Swift" tag; the Profile's SkillTag
count does not grow.

## [CVIMPORT-9] Education and project sections of the CV are listed as not-imported in the review

`Education` and `Project` models are deferred (Profile decisions/0003, this
slice's decisions/0002). Content the proposal assigns to those sections is
never silently dropped: the review lists it as not-imported, and confirming the
review does not write it anywhere.

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
model obeying. Anything else non-JSON — preamble prose, truncation — still
fails with its reason ([CVIMPORT-17]).
