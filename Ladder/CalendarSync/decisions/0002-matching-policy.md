# 0002 — Matching: normalised exact containment + attendee domain, no fuzzy

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

Calendar matching false positives are the phase's named risk
(ARCHITECTURE.md §6). A wrong proposal costs the user a dismissal; a silent
wrong link would corrupt the pipeline. The confirmation sheet already
guarantees nothing lands unreviewed, so the matcher's job is a short, honest
candidate list — not maximum recall.

## Decision

Two signals, both exact after normalisation, no edit-distance:

1. **Company name containment** — normalise both sides (lowercase, strip
   punctuation, collapse whitespace, drop the corporate suffixes `corp`,
   `corporation`, `inc`, `ltd`, `llc`, `gmbh`, `plc`, `co`), then match a
   whole-word substring of the event title or organizer name.
2. **Attendee domain** — the registrable-domain label of an attendee or
   organizer email (`jane@mail.acme.com` → `acme`) equals the normalised
   company name's first word or its joined form (`acme corp` → `acme`,
   `acmecorp`). A fixed deny-list of public mail providers (`gmail.com`,
   `googlemail.com`, `outlook.com`, `hotmail.com`, `live.com`, `yahoo.com`,
   `icloud.com`, `me.com`, `proton.me`, `protonmail.com`) is never company
   evidence.

Only **tracked Applications** are matchable: status applied, active, or
offer. Draft means not yet sent; rejected and withdrawn are closed — events
from those companies are noise, not waypoints. (Settled at spec, within the
plan's matching ruling.)

An event matching several tracked Applications produces one proposal carrying
every candidate; the confirmation sheet shows a picker. The matcher never
ranks or auto-picks.

## Consequences

- Misspelled company names miss — accepted; the user tracked the company by
  typing its name in the tailor sheet, so the spelling is theirs.
- [CALSYNC-3]…[CALSYNC-6] pin the policy; the normaliser and domain
  extractor are pure helpers, testable without EventKit.
- The deny-list is fixed in code, not configuration.
