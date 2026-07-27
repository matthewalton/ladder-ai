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

Criteria token: `[PROFILE-n]`
