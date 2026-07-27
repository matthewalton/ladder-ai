# 0005 — Stage kind guessed from title keywords, pre-selected and editable

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

The phase accept criterion is "zero typing" up to the confirmation. Always
asking for the kind adds a decision to every proposal; guessing wrongly and
silently would misfile Stages. The confirmation sheet already stands between
guess and write.

## Decision

A pure keyword map over the lowercased event title pre-selects the kind —
first hit in priority order wins:

| Keywords | Kind |
|---|---|
| `system design`, `architecture` | systemDesign |
| `take-home`, `take home`, `takehome` | takeHome |
| `phone screen`, `screen`, `screening` | screen |
| `recruiter`, `intro call`, `introduction` | recruiter |
| `technical`, `coding`, `pairing`, `pair programming` | technical |
| `behavioral`, `behavioural`, `values`, `culture` | behavioral |
| `final`, `onsite`, `on-site`, `loop` | final |
| `offer` | offer |

Multi-word kinds outrank single-word ones ("system design screen" →
systemDesign, not screen). No hit → no pre-selection: the sheet requires a
pick before confirming, and the guess never defaults to a kind. The guess is
only ever a pre-selection — the user can change it in the sheet.

## Consequences

- [CALSYNC-15] and [CALSYNC-16] pin the two sides; the helper is testable
  without EventKit or views.
- A wrong guess costs one picker tap in a sheet the user was already in.
- The map is fixed in code; growing it is a body-level edit to this decision,
  not a schema or criterion change.
