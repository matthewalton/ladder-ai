# 0013 — The scan's Tag suggestions are transient; the Match holds confirmed vocabulary only

**Status:** accepted (2026-07-27, agreed with the human)

## Context

The JD scan proposes Tag suggestions alongside the Match it produces. The
Match persists (decisions/0011); do the unconfirmed suggestions persist with
it so a review can open later without re-scanning? And which of root ADR
0005's three kinds can a scan honestly propose?

## Decision

**No.** Suggestions live in the scan result in memory and die with it. The
persisted Match holds only confirmed vocabulary — matched `SkillTag`
references and gap strings — so nothing LLM-proposed enters the store before
the user confirms it, extending ADR 0005's "the LLM proposes, only the user
writes" from the pool to the store as a whole. A review that wants
suggestions runs a scan; scans are cheap and each one refreshes the Match
against the current pool anyway.

Pool consistency of suggestions is likewise not checked at scan time: it is
enforced at confirmation, where the store's view is never stale — the
[PROFILE-34]/[PROFILE-35] precedent.

**The scan proposes the pool-level kinds only: mint and alias.** An attach
grounds in a point's evidence — which the scan payload deliberately lacks —
and lands per-point metadata that never moves the vocabulary-level Match
score, so a scan proposing one would be guessing. The on-demand and import
doors, which see the point, own attach ([PROFILE-32]).

## Considered options

- *Persist pending suggestions on the Match* — a review could open offline,
  but unconfirmed LLM output would sit in the store and go stale the moment
  the pool changes, needing its own invalidation story. Rejected.

## Consequences

- Slice 3's Match review is entered from a scan, not from cold storage.
- Records of what was *used* per generated CV are a separate concern (the
  CV-composition idea, Baton #164) — nothing here prejudges it.
