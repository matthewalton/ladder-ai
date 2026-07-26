# 0013 — The manage sheet recases and aliases; it never renames or merges

Status: accepted (agreed with the human at plan, 2026-07-26)

## Context

Aliases and curated casing (root `CONTEXT.md`: Alias) need a curation
surface. The full surface — browse the pool, rename freely, merge Tags,
prune orphans — is a view of its own, held by ticket #193. This slice needed
to decide how much lands now.

## Decision

A tag manage sheet opened from a Tag chip, scoped to that one Tag: recase
the primary name ([PROFILE-29], [PROFILE-30]) and record or remove Aliases
([PROFILE-26], [PROFILE-27], [PROFILE-40]). Arbitrary rename is refused
because it is a merge question in disguise — which links move, what happens
when both Tags exist — and merge semantics wait for the pool manager.

## Considered options

- _Full rename with merge_ — resolve collisions by merging links. Rejected
  for this slice: merge UX and its undo semantics deserve their own
  criteria, and nothing in ticket #162 needs them.

## Consequences

- A typo'd Tag name ("Pyton") is fixed by minting the right Tag and
  re-linking, or waits for the pool manager — accepted cost, noted on
  ticket #193.
- Sheet chrome is visual-verify; the store behaviour it drives is criterial.
