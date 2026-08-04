# Profile

The single canonical Profile: its SwiftData models (`Profile`, `Role`, `Achievement`,
`SkillTag`, `ContactInfo`), the store enforcing the single-profile invariant, and the
sidebar/content/inspector editor.

**Edits into this folder** — the boundary runs the other way here. `src/ProfileStore.swift`
holds the schema entry list for **every** slice's models, so a slice adding a model edits
this file. A model that is never registered there persists nowhere.

**Traps**

- The single-profile invariant is the store's job, not the caller's — a second `Profile`
  is a bug wherever it was created.
- `src/ProfilePersistenceTests.swift` owns the `temporaryStoreURL()` / `removeStore(at:)`
  helpers the whole repo's persistence criteria use.
- Live LLM access exists only in the Tag suggestion flow; the rest of the slice is offline.
- The machinery that photographs that flow's failures (ADR 0008) — `LadderUITests/ScreenTour.swift`
  plus its `tag-failure` case in `scripts/snapshots.sh`, which focuses a seeded point and asks for
  suggestions against an empty key (`-LadderTourNoKey`) and a refusing service
  (`-LadderTourServiceFails`).

**Needs eyes**

- The tag-suggestion failure caption, at the rail's real 300pt width —
  `scripts/snapshots.sh app tag-failure` records it as `30-tag-suggestion-needs-key` and
  `31-tag-suggestion-request-failed`. What the frames answer is whether a clay caption under the
  button still reads as attached to it once the message wraps. The rail is the narrowest place
  any live failure copy has to survive, and the request arm now carries two sentences where it
  carried one — the Detail, then the Advice the rail never used to give at all (Tailor
  decisions/0022).

Criteria token: `[PROFILE-n]`
