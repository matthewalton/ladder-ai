---
key: PROFILE
---

# Profile

The single, canonical career history (see root `CONTEXT.md`: exactly one Profile
exists) and its editor. This slice owns the SwiftData schema for `Profile`, `Role`,
`Achievement`, `SkillTag`, `Education`, `Project`, and `ContactInfo` (plus the
Profile's ordered `interests` strings), the store that enforces the
single-profile invariant, the CRUD editor, the Tag vocabulary's Aliases and the
tag manage sheet (decisions/0013), the app's versioned schema and migration
plan (decisions/0011), and the on-demand Tag suggestion flow with its versioned
`Prompts/tags.md` (decisions/0012).

The editor is a single scrollable CV-style page — identity header (name,
headline, contact), then Experience, Education, Projects, and Interests sections
— beside a slim persistent detail rail that edits the focused item's depth
(point wording, Tags, impact metric, strength notes; role, education, and
project fields — `tech` is gone, decisions/0011). A Tag chip opens the tag
manage sheet: recase the primary name, record or remove Aliases. Achievements
are written as brief talking points; tailoring expands them into finished CV
prose per application (Tailor slice). Layout and visual treatment follow
DESIGN.md and are verified by a human — the criteria below promise observable
behaviour, which lives in the store and the persistence layer.

Live LLM access enters this slice only for Tag suggestions (decisions/0012):
the run reads the API key from the Keychain via the shared key store and calls
the shared live service — the CVImport/Tailor pattern. Tests and previews stay
on `FixtureIntelligenceService`. The LLM proposes — attach, mint, alias — and
only the user writes (root ADR 0005).

Out of scope: CV import, tailoring, PDF export, the JD scan and Match review
(Tailor-side work), and a pool-wide Tag manager view (deferred; the manage
sheet curates one Tag at a time).

## [PROFILE-1] A role added to the Profile is still present after the app relaunches

The tracer criterion: it proves schema, store, and persistence wiring end to end.

Relaunch is exercised in tests by closing and reopening the `ModelContainer`
against the same store URL — the same configuration path the app uses at launch.

## [PROFILE-2] Launching with no Profile shows the create-profile empty state

"No Profile" means zero `Profile` records in the store. The create-profile empty
state is the manual creation path (decisions/0002, amended by decisions/0008 —
a CV import may also create the Profile via the replace pathway, [PROFILE-18]);
it follows the empty-state treatment in DESIGN.md §6 (contour background, one
New York line, one clear action).

Downstream slices must handle Profile-absent — the Profile is optional until the
user creates it.

## [PROFILE-3] The create action creates the single Profile with the entered name and headline

- Name is required and must be non-empty after trimming whitespace; the create
  action is unavailable until it is.
- Headline may be empty.
- The created Profile starts with no roles and no skills, and `updatedAt` is set
  at creation time.

## [PROFILE-4] The store rejects creating a second Profile

The single-profile invariant. Creating while a Profile exists throws
(`profileAlreadyExists`); the store's Profile count never exceeds one. The UI
never offers the create action once a Profile exists, but the store enforces the
invariant regardless of caller.

## [PROFILE-5] A fully-populated Profile round-trips unchanged through a store reopen

"Fully populated" means every field of every model in this slice's schema holds a
non-default value:

- `Profile`: name, headline, contact, `updatedAt`, ordered `interests`
- `ContactInfo`: email, phone, location, link (one URL string)
- one `Role` with company, title, location, industry, start, and a nil end (a
  current role) plus a second `Role` with a non-nil end (decisions/0010 adds
  the optional location/industry pair)
- two `Achievement`s under one role, each with `title` (decisions/0010), text,
  `impactMetric`, `strengthNotes`, and at least one Tag (`tech` is gone —
  decisions/0011, [PROFILE-24])
- two `SkillTag`s with distinct names, one carrying an Alias
  ([PROFILE-26])
- two `Education` entries — one completed (non-nil end, non-empty detail), one
  in progress (nil end, empty detail)
- one `Project` with name, link, summary, a multi-line description, and at
  least one Tag (decisions/0009)

Every field compares equal after closing and reopening the container. Any change
to this slice's schema must keep this criterion's test in step (CLAUDE.md:
every model change needs a round-trip test).

## [PROFILE-6] Deleting a role also deletes its achievements

Cascade delete: `Role` owns its `Achievement`s. `SkillTag`s referenced by the
deleted achievements are not deleted — they are shared across the Profile, and
orphan pruning is out of scope for this slice.

## [PROFILE-7] Reordering a role's achievements persists the new order

SwiftData to-many relationships do not guarantee order, so order is an
explicit persisted attribute (a sort index) — the dropped order survives a
store reopen. Since decisions/0009 only roles own points; projects order
themselves by their own sort index, not their content.

Edge case: moving the first point to the last position — every intermediate
index shifts by one.

## [PROFILE-8] Tagging two points with the same Tag name yields one shared SkillTag

Tag-name deduplication:

- Comparison is case-insensitive and ignores leading/trailing whitespace:
  tagging "Swift" then " swift " yields one `SkillTag`.
- The surviving Tag keeps the name as first entered ("Swift" above).

Tag chips in the editor render `SkillTag`s; the chip is the rendering, the
`SkillTag` is the model (see this slice's CONTEXT.md). Achievements and
Projects draw from the same shared pool ([PROFILE-21]).

## [PROFILE-9] Editing a point's text persists the new text

Achievement text is the user-owned canon (root `CONTEXT.md`): the detail rail is
the only place it changes, and the edit survives a store reopen. The same store
pathway carries edits to `impactMetric` and `strengthNotes` (`tech` is gone —
decisions/0011).

## [PROFILE-10] A Profile with no roles shows the empty Experience section

There is no separate screen: an existing Profile with zero roles lands in the
editor, whose Experience section carries the empty-state copy (DESIGN.md §6):
"Every climb starts with a pack. Add your first role." — with the inline
add-role action. Distinct from the create-profile empty state ([PROFILE-2]),
which is shown when no Profile exists at all.

## [PROFILE-19] Deleting a Project leaves the shared Tags it referenced intact

Projects no longer own points (decisions/0009, retiring [PROFILE-11] and
[PROFILE-12]), so a Project delete removes only the Project record and its Tag
links. The `SkillTag`s it referenced — and their links to achievements and
other Projects — survive, the [PROFILE-6]/[PROFILE-16] no-orphan-pruning
stance.

## [PROFILE-20] Editing a Project's description persists the new text

The multi-line description (decisions/0009) is edited in the detail rail like
any other project field, and the edit survives a store reopen. The same store
pathway carries edits to the one-line summary and link.

## [PROFILE-21] Tagging a Project with an existing Tag name links the one shared SkillTag

The [PROFILE-8] rule applied to Projects: comparison is case-insensitive and
trimmed, the first-entered casing survives, and the Project references the
shared `SkillTag` — never a private copy. Tagging a Project "swift" when an
achievement already carries "Swift" yields one Tag linked from both.

## [PROFILE-13] Identity and contact edits persist across a reopen

Name (trimmed, non-empty — an all-whitespace name is rejected and the existing
name stands), headline, and the whole `ContactInfo` value survive a store
reopen.

## [PROFILE-14] Interests keep their entered order and dedupe case-insensitively

Interests are ordered strings on the Profile: entry order is preserved across a
reopen, additions are trimmed, and an addition matching an existing interest
case-insensitively is ignored (the first-entered casing survives).

## [PROFILE-15] Deleting a point persists, with the surviving siblings' order intact

The deleted point is gone after a reopen and the remaining siblings keep their
relative order with a dense sort index.

## [PROFILE-16] Untagging removes the link, never the Tag

Removing a Tag from a point or a Project severs only that one reference: the
`SkillTag` record and its links to other points and Projects survive (no
orphan pruning, consistent with [PROFILE-6]).

## [PROFILE-17] Replacing the Profile's content leaves exactly the replacement content after a store reopen

The wholesale replace pathway (decisions/0008): the store takes a replacement —
a plain value carrying identity (name, headline), contact, roles (company,
title, dates, and the optional location/industry pair — decisions/0010) with
their achievements (title, text, impact metric, tag names — `tech` is gone,
decisions/0011), education, projects (name, link, summary, description, tag
names — decisions/0009), and interests — and rebuilds the Profile from it in
one mutation.

- All-or-nothing: every prior role, achievement, education entry, project,
  interest, and `SkillTag` is gone afterwards — a replace never leaves a merged
  hybrid, and the Tag pool is rebuilt from the replacement's tag names alone
  (wholesale removal is deliberate here, unlike the no-orphan-pruning stance of
  single deletes, [PROFILE-6]/[PROFILE-16]). The rebuilt pool starts
  Alias-free: a replacement carries tag names only, so recorded Aliases go
  with the wholesale removal.
- Tag names within the replacement — achievement and project alike — dedupe
  by the [PROFILE-8] rule (case-insensitive, trimmed, first casing wins) into
  one shared pool ([PROFILE-21]).
- `updatedAt` is set at replace time.
- Ordering: achievements keep the replacement's order via the persisted sort
  index ([PROFILE-7]), projects via their own sort index; interests keep entry
  order ([PROFILE-14]).

Exercised by populating a full Profile, replacing it with different content,
closing and reopening the container, and comparing every field against the
replacement alone.

## [PROFILE-18] A replace with no Profile on file creates the single Profile with the replacement content

The second creation path (decisions/0008): the same replace pathway, starting
from zero `Profile` records, ends with exactly one Profile holding the
replacement content — the single-profile invariant ([PROFILE-4]) holds through
either branch. The create-profile empty state remains the manual path
([PROFILE-2]); nothing is auto-created without content the user chose to
import.

## [PROFILE-22] Editing a role's location and industry persists across a store reopen

The optional print-field pair on `Role` (decisions/0010): edited in the
detail rail beside the other role fields, surviving a reopen like any role
edit. An entry that is empty after trimming persists as nil — absent, never
an empty string — so downstream renderers can key "no subline" off nil alone
(cv-export's grey subline renders only what exists, [CVEXPORT-31]). Existing
roles carry nil for both until the user backfills by hand; no migration
invents values.

## [PROFILE-23] Editing a point's title persists the new title

`Achievement.title` is the optional bold lead phrase (root `CONTEXT.md`;
decisions/0010), edited in the detail rail beside the point's text and
persisting through the [PROFILE-9] store pathway. Empty after trimming
persists as nil — a titleless point renders plain, exactly as every point
did before the field existed. The title is canon like the text: manual
backfill only, and tailoring expands only the description, never writing
the title (Tailor slice).

## [PROFILE-24] Opening a pre-migration store folds each achievement's tech strings into its Tags

The repo's first destructive schema change (decisions/0011): `tech` leaves
`Achievement`, and its strings join the shared Tag pool. PipelineBoard
decisions/0001 recorded that the first destructive change is the moment
versioned schemas begin — this is it: a `VersionedSchema` pair and a
`SchemaMigrationPlan` with a custom stage replace implicit lightweight
migration.

- Each tech string resolves by the [PROFILE-8] rule — trimmed,
  case-insensitive, first casing wins: an achievement with tech `["swift"]`
  and an existing **Swift** Tag ends linked to that one shared Tag, never a
  duplicate.
- A migrated store has no `tech` attribute; the property is gone from the
  model, the detail rail, and the replace pathway.
- Exercised against a committed pre-migration fixture store in
  `LadderTests/Fixtures/` — written by the pre-migration schema before this
  change lands, never regenerated (the [PIPEBOARD-2] pattern). The Phase 1
  fixture store must also still open: lightweight inference up the versioned
  chain composes with the custom stage, and [PIPEBOARD-2] keeps defending
  that boundary.

## [PROFILE-25] The tech migration writes a store-file backup before it runs

The agreed safety net (decisions/0011): the July 2026 store loss (root ADR
0004) is why a destructive migration never touches the only copy. Before the
custom stage mutates anything, the store file is copied to a sibling backup
path; opening a pre-migration store leaves both the migrated store and a
backup whose bytes are the pre-migration store file's. An already-migrated
store writes no backup — the net exists for the one-way step, not every
launch.

## [PROFILE-26] Recording an Alias on a Tag persists it lowercase across a store reopen

Aliases are matching-only and lowercase; the primary name keeps its curated
casing (root `CONTEXT.md`: Alias). Recording trims and lowercases: ` K8s `
recorded on **Kubernetes** persists as `k8s`. Recorded from the tag manage
sheet (decisions/0013) or a confirmed alias suggestion ([PROFILE-35]) — the
same store pathway either way. Removing a recorded Alias persists too: the
Tag, its casing, and its links are untouched; the name simply stops
resolving ([PROFILE-28]).

## [PROFILE-27] Recording an Alias that matches an existing primary name or alias is refused

Resolution must stay unambiguous: one name, one Tag. The match is trimmed and
case-insensitive, across every Tag's primary name and Aliases — the target
Tag's own included (aliasing **Swift** with "swift" adds nothing the primary
does not already match). The store throws and the pool is unchanged; the
manage sheet surfaces the refusal.

## [PROFILE-28] Tagging a point with a name matching a Tag's Alias links that Tag

Pool resolution grows alias-aware (root ADR 0005): case-insensitive across
primary names and Aliases alike. Tagging "k8s" when **Kubernetes** carries
the alias `k8s` links Kubernetes — no new Tag is minted, and the chip shows
the primary name. The same resolution serves Projects ([PROFILE-21]) and
confirmed mint suggestions ([PROFILE-34]). The replace pathway is untouched:
a rebuilt pool has no Aliases to resolve against ([PROFILE-17]).

## [PROFILE-29] Recasing a Tag's primary name persists across a store reopen

The manage sheet's rename is a recase: the new name must equal the old
case-insensitively ("ios" → "iOS"), curating the display casing every chip
and rendered CV shows (root `CONTEXT.md`: Alias — "iOS", never "Ios").
Points and Projects reference the one shared `SkillTag`, so the recase
propagates without touching them.

## [PROFILE-30] A Tag rename that changes more than casing is refused

The guard on [PROFILE-29] (decisions/0013): renaming **JS** to "JavaScript"
is a merge question — which links move, what happens when both Tags exist —
and merge semantics belong to the deferred pool manager view. The store
throws and the Tag is unchanged.

## [PROFILE-31] A Tag suggestion request carries the versioned tags prompt and the pool vocabulary

`Prompts/tags.md` is born in this slice: canonical, versioned, loaded at
runtime — never an inline string (the [CVIMPORT-13] stance). The request
also carries the point's own evidence — title, text, impact metric, strength
notes; a Project sends name, summary, and description — and the vocabulary:
every Tag's primary name with its Aliases, so the model attaches or aliases
before it mints (decisions/0012). Exercised with the fixture service
recording the request it receives; the recorded prompt equals the file's
content.

## [PROFILE-32] A Tag suggestion run proposes attach, mint and alias changes for review

All three kinds from day one (decisions/0012; root ADR 0005): attach an
existing Tag to the point, mint a new Tag, record an Alias on an existing
Tag. Every proposal is grounded in what the point evidences — never
keyword-stuffing (root `CONTEXT.md`: Tag suggestion). The proposals are held
for review, each individually confirmable; nothing is persisted by the run
itself. The canned fixture response carries all three kinds.

## [PROFILE-33] Confirming an attach suggestion links the existing Tag to the point

A link and nothing else — no rename, no new Tag, no other point touched (the
[PROFILE-16] stance in reverse). The link survives a store reopen.

## [PROFILE-34] Confirming a mint suggestion creates the Tag and links it to the point

The minted Tag takes the proposed name as its curated casing. Minting
resolves against the pool first by the alias-aware rule ([PROFILE-8],
[PROFILE-28]): a mint whose name matches an existing primary name or Alias
links the existing Tag instead — the model's view of the pool may be stale,
the store's never is.

## [PROFILE-35] Confirming an alias suggestion records the Alias on its Tag

Through the [PROFILE-26] pathway — trimmed, lowercased, persisted. A
colliding alias is refused exactly as a manual one is ([PROFILE-27]); the
refusal surfaces in the review and the pool is unchanged.

## [PROFILE-36] A declined Tag suggestion leaves the pool and the point's Tags unchanged

Nothing lands without confirmation (root ADR 0005: the LLM proposes, only
the user writes). Declining is per-proposal: confirming one of a run's
proposals and declining the rest lands exactly the confirmed one.

## [PROFILE-37] Requesting Tag suggestions with no API key stored is refused

Checked before any service call ([CVIMPORT-14]'s rule): the refusal directs
the user to Settings, and production never falls back to fixture data —
`FixtureIntelligenceService` stays a test and preview concern.

## [PROFILE-38] The suggestion run creates its live service with the stored API key

The key store plus `makeIntelligence` factory shape ([CVIMPORT-15]; Tailor
decisions/0002 and 0003 lineage): exercised without network via a fake key
store holding a known key and a factory recording the key it was handed. The
default factory is the shared `AnthropicIntelligenceService` (pinned model).

## [PROFILE-39] A suggestion response failing validation fails the run with the reason

Fail-fast with the reason surfaced (CVImport decisions/0004's stance, adopted
here — no repair request): malformed JSON or a missing required part names
what was rejected. A fenced-but-valid response reaches review — the
[CVIMPORT-18] tolerance — and a truncated one carries its own reason via the
shared service ([CVIMPORT-19]). A failed run proposes nothing and the pool
is unchanged.

## [PROFILE-40] Removing an Alias from a Tag persists across a store reopen

The manage sheet's remove action ([PROFILE-26] names the pathway): after the
reopen the Alias is gone, the Tag's primary name and links are intact, and
tagging by the removed name now mints a fresh Tag rather than resolving
([PROFILE-28] no longer applies to it).
