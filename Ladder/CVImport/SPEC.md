---
key: CVIMPORT
---

# CV Import

Drop a PDF or docx CV, extract its text on-device, have the intelligence service
propose Roles, Achievements, and skills, review every proposed item, and merge
the included ones into the existing Profile. This slice owns the extraction
step, the `IntelligenceService` protocol and its fixture implementation, the
proposal/review model, the merge, and `Prompts/import.md`.

Fixture-driven throughout: `FixtureIntelligenceService` returns canned JSON from
`LadderTests/Fixtures/` — no live API calls in this slice (live calls arrive
with the tailor slice). Import requires an existing Profile (decisions/0001);
the proposal covers roles, achievements, and skills only (decisions/0002); the
review screen is the dedup (decisions/0003).

Out of scope: tailoring, PDF export, Profile creation via import, automatic
duplicate matching, `Education`/`Project` models, live LLM access.

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
and the Profile is unchanged. No retry-with-repair in this slice — that loop
arrives with the tailor slice.

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
the request it receives; the recorded prompt equals the file's content. This
keeps the prompt real and versioned even while calls are fixture-driven.
