# 0001 — Application migrated in place, on implicit lightweight migration

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

CVExport decisions/0001 shipped `Application` roadmap-minimal and explicitly
handed `Stage`, the relationship, and the status transitions to Phase 2. The
model file lives in `Ladder/CVExport/src/Application.swift` (the slice that
introduces a model owns its file; there is no `Shared/Models/`). This slice
needed to decide where the Phase 2 fields land and how the schema migrates.

## Decision

The `Application` model is edited in place in `Ladder/CVExport/src/` — no
move, no new home. This slice owns the change and records it here; cv-export's
observable contract ([CVEXPORT-8..14]) does not change, and its init grows
only defaulted parameters so `CVExportStore.export` compiles untouched.

New fields: `source: String?`, `appliedAt: Date?`, `notes: String = ""`, and
`@Relationship(deleteRule: .cascade, inverse: \Stage.application) stages:
[Stage]` with a computed `orderedStages`. `createdAt` stays — it records when
the row was created; `appliedAt` records when the user applied.

The `notes` default lives **at the property declaration**, not only in
`init`: SwiftData lightweight migration populates existing rows from the
declaration initial value, and an init-only default fails silently on first
launch over a Phase 1 store. [PIPEBOARD-2] defends this with a committed
Phase 1 fixture store.

The app stays on implicit lightweight migration — every change here is
additive (new model, new optional attributes, a non-optional attribute with a
declaration default, a new to-many relationship), so a
`VersionedSchema`/`SchemaMigrationPlan` would be pure ceremony. The first
*destructive* schema change in a later phase is the moment to introduce
versioned schemas. `Stage.self` joins the single `Schema([...])` in
`Ladder/Profile/src/ProfileStore.swift`.

## Consequences

- calendar-sync and timeline get `Stage`, `appliedAt`, and the relationship
  without another Application migration.
- The Phase 1 fixture store at `LadderTests/Fixtures/Phase1Store/` is a
  permanent asset: it was written by the Phase 1 schema and keeps defending
  the migration boundary. Never regenerate it.
- CLAUDE.md's repo-layout diagram (single gated `Pipeline/`) and
  ARCHITECTURE.md §7's folder list are updated to the sibling slice folders
  this slice inaugurates (`PipelineBoard/`), per the human's ruling on the
  Phase 2 slice map.
