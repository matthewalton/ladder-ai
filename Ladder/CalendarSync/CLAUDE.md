# Calendar Sync

The `CalendarSyncService` seam (protocol + fixture + live EventKit implementation), the
scan/match/propose store, the `DismissedEvent` model, and the confirmation sheet.

**Edits outside this folder** — a change here usually touches:

- `project.yml` — the calendar entitlement and its usage string. Change them there and
  re-run `xcodegen generate`; the generated project is never edited directly

**Traps**

- **Never construct a live `EKEventStore` in a test.** The suite must stay green on a machine
  with no calendar permission granted (ROADMAP Phase 2 exit criterion 4). The live
  implementation is exercised by humans only.
- Fixture events are constructed in code by the fixture service — no JSON files, and no
  `EKEvent` in any test.
- `[CALSYNC-12]` is the persistence criterion.

Criteria token: `[CALSYNC-n]`
