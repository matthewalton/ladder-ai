# 0006 — Empty-scan explainers are chosen by a live tracked-Applications signal

Status: accepted (agreed with the human at plan, 2026-07-19)

## Context

An empty scan and the denied state look identical in the bar today: header
only. Diagnosis of "gave calendar access but can't add anything" (Baton
#141) showed two silent cases behind an empty scan — no tracked Application
at all (matching never ran), and tracked Applications with no event matching
under the exact-match policy (decisions/0002). Both collapse to
`scanState == .ready, proposals == []`, and the store discards the
distinction, so the bar cannot explain itself.

## Decision

The store exposes `hasTrackedApplications`, a computed property over the
pipeline's Applications filtered by the same tracked statuses the scan uses
(decisions/0002) — live, not captured at scan time, so the explainer stays
truthful when the board changes after a scan. No new scan state and no
stored empty-reason: `.ready` + zero proposals + this one flag is enough to
pick between the two explainers. Explainers render only in `.ready` — never
while idle, scanning, or denied — and mirror the denied explainer's quiet
one-line form.

## Consequences

- [CALSYNC-19] pins the no-tracked-Application explainer, [CALSYNC-20] the
  tracked-but-unmatched one; [CALSYNC-3] is untouched as the store-level
  "empty list, not an error" criterion.
- A stale-signal class of bug is designed out: moving the last tracked
  Application back to Draft after a scan flips the bar to the case-one
  explainer without a re-scan.
- If a later slice wants finer reasons (e.g. "all matches were dismissed"),
  that is a new signal and new criteria, not a rework of this flag.
