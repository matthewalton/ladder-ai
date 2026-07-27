# 0011 — The Match persists as its own model, one-to-one from Application

**Status:** accepted (2026-07-27, agreed with the human)

## Context

Ticket #162 slice 2 brings the JD scan into this slice, and its output — the
Match — must outlive the scan: slice 3's Match review opens on it, the tailor
selection will be grounded in it, and root `CONTEXT.md` says it is refreshed
by every scan rather than frozen. That collides with decisions/0001, which
made the whole tailor flow transient. Two shapes were on the table for the
storage: a dedicated model, or fields flattened onto `Application`.

## Decision

- **A dedicated `Match` `@Model`**, one-to-one from `Application` with
  cascade delete — the `JourneyNarrative` shape. Fields: matched Tags as a
  to-many relationship to the live `SkillTag` instances (never copies —
  renames propagate, deletes remove), `vocabularyGaps: [String]`, and
  `scannedAt: Date`.
- **The Match is the slice's one persisted artefact.** decisions/0001's
  transient stance now covers the tailor flow — tailor result and reviewed
  outcome — not the slice. Only the JD scan writes the Match; a tailor run
  and review still persist nothing.
- **Each scan replaces the Match wholesale.** It tracks the pool, never
  freezes; the immutable record of what was sent remains the CV snapshot.
- **The model file lives in this slice's `src/`**; `Application` gains the
  relationship amended in place in `Ladder/CVExport/src/` (the PipelineBoard
  decisions/0001 precedent). The schema takes a lightweight V3 step in
  `LadderSchemaVersions.swift`.

## Considered options

- *Fields flattened onto `Application`* (matched-tags relationship + gaps +
  scanned-at directly) — one fewer model, but Match stops being a nameable
  thing while the glossary names it, `Application` keeps accreting fields,
  and slice 3 would grow it by touching `Application` again. Rejected.
- *Keeping the Match transient like the rest of the flow* — no schema
  change, but every review or selection would need a fresh scan and API
  call, and an Application could never show its standing offline. Rejected.

## Consequences

- The Match survives relaunches; slice 3's review and the tailor wiring read
  it without a scan having run this session.
- A schema V3 migration step exists, defended by the committed fixture
  stores ([TAILOR-42]) — a pre-Match store opens with no Match anywhere.
- Deleting an Application deletes its Match; deleting a `SkillTag` thins
  every Match that referenced it without resurrecting a gap ([TAILOR-40]).
