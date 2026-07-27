# 0002 — StageKind persists as a raw string, not an associated-value enum

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

ARCHITECTURE.md §3 gives `StageKind` an `.other(String)` case alongside the
known kinds. SwiftData persists a Codable enum with associated values as an
opaque composite — un-queryable, and fragile under schema evolution. The
codebase has no persisted associated-value enum; every stored enum so far is
a plain `String`-raw-value (`ApplicationStatus`).

## Decision

`Stage` persists `kindRaw: String` and exposes a computed `kind: StageKind`.
`StageKind` is a hand-rolled `Hashable` enum: the known cases each map to a
fixed raw string; `init(rawValue:)` maps any unknown string to
`.other(rawValue)`; `rawValue` of `.other(label)` is the label itself. A
`static knownCases` array (no `.other`) feeds pickers, with a free-text
"Other" escape hatch in the form.

Accepted edge: a user typing exactly "technical" into the Other field
round-trips as `.technical` — a harmless collapse. Forward-compatible by the
same token: a kind added to the enum later degrades to `.other` in an old
binary instead of failing to decode.

`StageOutcome` has no associated value and follows the `ApplicationStatus`
pattern exactly: `String, Codable, CaseIterable, Sendable`.

## Consequences

- `kindRaw` is predicate-friendly (calendar-sync and timeline can filter by
  kind) and trivially lightweight-migration-safe.
- [PIPEBOARD-3] round-trips an `.other` kind to pin the mapping.
- Pickers never offer `.other` directly; the form's free-text row is the only
  way to produce one.
