# 0021 — Failure copy belongs to the error, not to each store

Status: accepted (review of 1300050, 2026-08-04)

## Context

decisions/0020 settled which store-level case each new failure maps to. It did
not settle where the user-facing wording lives, and the answer it inherited was
"in every store that shows one": four `requestFailureDetail` functions across
three slices, each switching over `LiveServiceError` and each ending in a
`default:` arm.

That shape cannot be made safe by care. The functions take `error: Error` and
switch over the existential, so no switch is ever exhaustive and the compiler
cannot ask for a missing case — an omission falls to
`(error as NSError).localizedDescription`, which for a plain Swift enum reads
`The operation couldn't be completed. (… error 3.)`. Adding two cases meant
eight lines in four files, and the only safeguard was prose: the same four-store
roll-call recited in `SPEC.md`, this slice's `CLAUDE.md`, and 0020 itself. The
copies had already begun to drift — `TailorStore` carried a `truncated` arm the
other three did not — and half the new copy reached no test at all.

## Decision

`LiveServiceError` carries its own copy, in a `detail` property switching over
`self`. That switch is exhaustive, so a new case without copy is a build error
rather than a string a user finds later.

Stores no longer write copy. Each calls
`AnthropicIntelligenceService.failureDetail(for:)`, which reads `detail` when
the error is a `LiveServiceError` and otherwise keeps the existing
`(error as NSError).localizedDescription` fallback for everything else that can
reach a catch block.

`truncated`'s copy lives on the enum with the rest even though only
`TailorStore` reaches it: the other three catch `.truncated` earlier and map it
to their own store-level case, so carrying it costs them nothing.

## Consequences

- A new `LiveServiceError` case is one edit, and the compiler enforces it. The
  four-store roll-call is no longer load-bearing and has been removed from
  `SPEC.md` and this slice's `CLAUDE.md`.
- The copy is defended in one place — [TAILOR-73]'s case-by-case test — instead
  of needing a store test per slice to prove each copy exists. The store tests
  that do exist now check that a store surfaces the shared copy, not what the
  wording is.
- The wording constraint survives the move: callers interpolate `detail`
  mid-sentence inside parentheses, so it must still read that way.
- `failureDetail(for:)` is the seam to grep for when asking which slices show a
  live failure, replacing the list this slice used to maintain by hand.
