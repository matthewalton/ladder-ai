---
key: PROFILE
---

# Profile

The single, canonical career history (see root `CONTEXT.md`: exactly one Profile
exists) and its editor. This slice owns the SwiftData schema for `Profile`, `Role`,
`Achievement`, `SkillTag`, `Education`, `Project`, and `ContactInfo` (plus the
Profile's ordered `interests` strings), the store that enforces the
single-profile invariant, and the CRUD editor.

The editor is a single scrollable CV-style page — identity header (name,
headline, contact), then Experience, Education, Projects, and Interests sections
— beside a slim persistent detail rail that edits the focused item's depth
(point wording, Tags, impact metric, tech, strength notes; role, education, and
project fields). Achievements are written as brief talking points; tailoring
expands them into finished CV prose per application (Tailor slice). Layout and
visual treatment follow DESIGN.md and are verified by a human — the criteria
below promise observable behaviour, which lives in the store and the
persistence layer.

Out of scope: CV import, tailoring, PDF export, explicit JD-tag extraction, and
any live LLM access.

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
- one `Role` with company, title, start, and a nil end (a current role) plus a
  second `Role` with a non-nil end
- two `Achievement`s under one role, each with text, `impactMetric`, `tech`
  (two entries), `strengthNotes`, and at least one Tag
- two `SkillTag`s with distinct names
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
pathway carries edits to `impactMetric`, `tech`, and `strengthNotes`.

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
a plain value carrying identity (name, headline), contact, roles with their
achievements (text, impact metric, tech, skill names), education, projects
(name, link, summary, description, skill names — decisions/0009), and
interests — and rebuilds the Profile from it in one mutation.

- All-or-nothing: every prior role, achievement, education entry, project,
  interest, and `SkillTag` is gone afterwards — a replace never leaves a merged
  hybrid, and the Tag pool is rebuilt from the replacement's skill names alone
  (wholesale removal is deliberate here, unlike the no-orphan-pruning stance of
  single deletes, [PROFILE-6]/[PROFILE-16]).
- Skill names within the replacement — achievement and project alike — dedupe
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
