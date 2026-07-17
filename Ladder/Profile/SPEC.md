---
key: PROFILE
---

# Profile

The single, canonical career history (see root `CONTEXT.md`: exactly one Profile
exists) and its editor. This slice owns the SwiftData schema for `Profile`, `Role`,
`Achievement`, `SkillTag`, and `ContactInfo`, the store that enforces the
single-profile invariant, and the CRUD editor.

The editor composes as a standard macOS three-pane: sidebar (roles), content
(the selected role's achievements), inspector (details of the selected item).
Layout and visual treatment follow DESIGN.md and are verified by a human — the
criteria below promise observable behaviour, which lives in the store and the
persistence layer.

Out of scope: CV import, tailoring, PDF export, `Education`/`Project` models
(decisions/0003), and any live LLM access.

## [PROFILE-1] A role added to the Profile is still present after the app relaunches

The tracer criterion: it proves schema, store, and persistence wiring end to end.

Relaunch is exercised in tests by closing and reopening the `ModelContainer`
against the same store URL — the same configuration path the app uses at launch.

## [PROFILE-2] Launching with no Profile shows the create-profile empty state

"No Profile" means zero `Profile` records in the store. The create-profile empty
state is the only place a Profile can be created (decisions/0002); it follows the
empty-state treatment in DESIGN.md §6 (contour background, one New York line, one
clear action).

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

- `Profile`: name, headline, contact, `updatedAt`
- `ContactInfo`: email, phone, location, link (one URL string)
- one `Role` with company, title, start, and a nil end (a current role) plus a
  second `Role` with a non-nil end
- two `Achievement`s under one role, each with text, `impactMetric`, `tech`
  (two entries), `strengthNotes`, and at least one skill
- two `SkillTag`s with distinct names

Every field compares equal after closing and reopening the container. Any change
to this slice's schema must keep this criterion's test in step (CLAUDE.md:
every model change needs a round-trip test).

## [PROFILE-6] Deleting a role also deletes its achievements

Cascade delete: `Role` owns its `Achievement`s. `SkillTag`s referenced by the
deleted achievements are not deleted — they are shared across the Profile, and
orphan pruning is out of scope for this slice.

## [PROFILE-7] Reordering a role's achievements persists the new order

Drag-reorder in the editor. SwiftData to-many relationships do not guarantee
order, so order is an explicit persisted attribute (e.g. a sort index) — the
dropped order survives a store reopen.

Edge case: moving the first achievement to the last position — every
intermediate index shifts by one.

## [PROFILE-8] Tagging two achievements with the same skill name yields one shared SkillTag

Skill-name deduplication:

- Comparison is case-insensitive and ignores leading/trailing whitespace:
  tagging "Swift" then " swift " yields one `SkillTag`.
- The surviving tag keeps the name as first entered ("Swift" above).

Skill chips in the editor render `SkillTag`s; the chip is the rendering, the
`SkillTag` is the model (see this slice's CONTEXT.md).

## [PROFILE-9] Editing an achievement's text persists the new text

Achievement text is the user-owned canon (root `CONTEXT.md`): this editor is the
only place it changes, and the edit survives a store reopen. The same store
pathway carries edits to `impactMetric`, `tech`, and `strengthNotes`.

## [PROFILE-10] A Profile with no roles shows the add-first-role empty state

Shown inside an existing Profile with zero roles — distinct from the
create-profile empty state ([PROFILE-2]), which is shown when no Profile exists
at all. Copy per DESIGN.md §6: "Every climb starts with a pack. Add your first
role." The action adds the first role; the Import CV action arrives with the
cv-import slice, not here.
