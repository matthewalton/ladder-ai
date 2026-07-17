# 0001 — Colocated tests routed to the test target via project.yml globs

Status: accepted (agreed with the human at the plan stage, 2026-07-17)

## Context

The Speccle convention keeps tests beside the code they defend, inside the
feature's `src/`. Xcode requires unit tests to compile into a separate test
bundle target (`LadderTests`, loaded via `TEST_HOST`) — a test file inside the
app target's source tree would otherwise be compiled into the app.

## Decision

Tests live in `Ladder/Profile/src/` beside the code, named `*Tests.swift`. The
`project.yml` manifest routes them: the `Ladder` target excludes
`**/*Tests.swift` (and the slice's markdown contract, so it never ships in the
app bundle); the `LadderTests` target includes `Ladder/**/*Tests.swift` in
addition to `LadderTests/`.

## Consequences

- Every feature slice keeps the uniform Speccle shape; an agent landing in the
  folder finds code and its tests together.
- `project.yml` owns the routing; adding a slice needs no per-file target lists,
  but renaming the `*Tests.swift` suffix would silently move files into the app
  target — the suffix is load-bearing.
- `xcodegen generate` must run after adding files, as everywhere in this repo.
