# 0004 — Live import fails fast, with the reason surfaced

Status: accepted (agreed with the user at plan stage, 2026-07-18)

## Context

Import is going live. The tailor slice answers nondeterministic model output
with exactly one repair request (Tailor decisions/0004), and [CVIMPORT-10]'s
original body deferred a repair loop to that slice. Going live, import could
adopt the same loop or stay fail-fast.

## Decision

No repair request in import. An invalid response fails the run on the first
attempt — but the failure must be actionable: validation is strict up front and
every failure states which stage failed and why, rather than collapsing into a
generic "proposal invalid".

## Consequences

- [CVIMPORT-10] stands unchanged: a proposal failing schema validation fails
  the import, first time, every time.
- Failure stages are distinct errors: `apiKeyRequired` ([CVIMPORT-14]),
  `requestFailed` for transport ([CVIMPORT-16]), `proposalInvalid` carrying the
  validation reason ([CVIMPORT-17]) — alongside the existing `profileRequired`,
  `extractionFailed`, `unsupportedFileType`.
- A flaky-but-repairable response costs the user a manual retry; the surfaced
  reason is what makes that retry informed. Revisit if real-world failure rates
  make the retry tax noticeable.
