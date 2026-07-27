# 0010 — Print fields on Role and Achievement, backfilled by hand

Status: accepted (agreed with the human at the plan stage, 2026-07-23)

## Context

The CV template (CVExport decisions/0007) reproduces the reference CV's role
sublines — location and industry in meta grey — and its bold lead-in bullet
phrases. The schema had neither: `Role` carried no location or industry, and
`Achievement` was a single text. The alternatives were separate print-only
storage in CVExport (splits one fact across two slices) or deriving lead-ins
at tailor time (invents canon the user never wrote).

## Decision

`Role` gains optional `location` and `industry`; `Achievement` gains an
optional `title` — the bold lead phrase, with the existing `text` remaining
the description. All three are canon, live in this slice's schema, and are
**backfilled manually**: no migration or import writes values into existing
records, and an entry empty after trimming persists as nil. Tailoring
expands only the description and never writes the title (root `CONTEXT.md`);
CV import proposes a title split going forward ([CVIMPORT-31]).

## Consequences

- Nil is the one "absent" signal: renderers key sublines and lead-ins off
  nil, never off empty strings ([CVEXPORT-31], [CVEXPORT-32]).
- [PROFILE-5]'s fully-populated round-trip and [PROFILE-17]'s replacement
  value grow the new fields; the replace pathway carries them so import can
  land titles.
- The detail rail edits all three ([PROFILE-22], [PROFILE-23]).
- Existing profiles render exactly as before until the user backfills.
