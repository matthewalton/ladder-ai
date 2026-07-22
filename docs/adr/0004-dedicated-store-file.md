# 0004 — The store lives in Ladder's own file, never SwiftData's default

**Status:** accepted (2026-07-22)

## Context

Ladder opened its `ModelContainer` with a default `ModelConfiguration`, which
for an unsandboxed macOS app resolves to the literal shared path
`~/Library/Application Support/default.store`. That path is not per-app: every
unsandboxed process on the machine that also uses a default SwiftData
configuration opens the **same file** — Apple's own `icloudmailagent` among
them (its transactions are recorded in the file's persistent history alongside
Ladder's).

Each process that opens the shared file migrates it to *its own* schema.
Core Data's lightweight migration drops tables that are not in the destination
model — so two schemas ping-pong-clobber each other. On 2026-07-22 this
dropped all of Ladder's tables: the user's Profile, Roles, Achievements,
Skills, Education, Projects and Applications were deleted (achievement text
was later carved out of the file's freed pages; the rest was lost). No code
change in Ladder triggered it — sharing the path was the defect.

## Decision

`ProfileStore.container()` never uses the default configuration. The on-disk
store is always an explicit URL:

```
~/Library/Application Support/Ladder/Ladder.store
```

The directory is created on first launch. Tests keep using in-memory
containers or explicit temporary URLs, as before.

## Consequences

- No other process can migrate Ladder's store; Ladder cannot clobber another
  process's data either.
- The old `default.store` is left untouched — it belongs to whichever Apple
  daemon opens it next, and deleting or "reclaiming" it would recreate the
  original hazard.
- The store did not move existing data (there was none left to move); a fresh
  store is created at the new path on next launch.
- If the app is ever sandboxed, the same explicit path resolves inside the
  container and keeps working.
