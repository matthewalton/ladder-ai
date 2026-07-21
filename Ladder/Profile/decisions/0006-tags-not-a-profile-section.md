# 0006 — Tags are matching metadata, not a profile section

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

The old editor presented "Skills" as a profile-wide concept, and CV export
rendered the whole `profile.skills` pool as the CV's Skills line. The redesign
reframes them: they exist to map individual points (role and project) against a
job description.

## Decision

- The domain and UI word is **Tag**. The persisted model keeps its `SkillTag`
  code name and `skills` property names — renaming stored schema names would
  break SwiftData lightweight migration for existing stores.
- The Profile page has no top-level Tags section. Tags appear on point rows and
  are edited in the detail rail.
- The exported CV's Skills line is derived per application: the sorted unique
  union of Tag names across the *selected* points (see the CVExport slice) —
  not a dump of the whole profile's Tag vocabulary.

## Consequences

- `profile.skills` remains the dedup registry the store tags against; CV export
  no longer reads it directly.
- Explicit JD-tag extraction and overlap display is future work, out of this
  slice's scope.
