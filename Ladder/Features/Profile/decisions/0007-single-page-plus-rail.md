# 0007 — Single CV-style page with a persistent detail rail

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

The original editor was a three-pane `NavigationSplitView` (roles sidebar →
achievement cards → `.inspector`). It read as a database browser, not a CV, and
had no home for Education, Projects, Interests, or contact editing.

## Decision

- The editor is one scrollable CV-ordered page (identity header, Experience,
  Education, Projects, Interests) beside a fixed-width (300pt) detail rail in a
  plain `HStack`. Not `HSplitView` (resize complexity for no benefit) and not
  `.inspector` (dismissable/transient by design, which contradicts a
  persistent rail).
- The add-first-role screen is gone: `ProfilePresentation` has two states
  (`createProfile`, `editor`) and the empty Experience section carries the
  add-first-role copy inline ([PROFILE-10]).
- "Add role/education/project" creates the record with placeholder-empty fields
  and focuses the rail for editing — no modal forms.
- Point reorder uses `.draggable`/`.dropDestination` with a parent-scoped token
  (a `ScrollView` has no `.onMove`), plus context-menu Move up/down as the
  keyboard-free fallback. [PROFILE-7]'s promise (persisted order) is defended
  at the store either way.
- Focus follows deletion: deleting the focused item — or a parent of it —
  clears the rail first.

## Consequences

- The Import CV and Tailor entry points live on the page's toolbar.
- Every rail pane resets its editing state via `.id(persistentModelID)` when
  focus moves.
