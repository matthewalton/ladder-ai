# 0012 — An edited CV over two pages is the user's to cut

Status: accepted (agreed with the human at the plan stage, 2026-07-28)

## Context

The two-page cap is absolute ([CVEXPORT-25]) and the fit loop enforces it by
condensing wordy bullets and then trimming the weakest (decisions/0008).
That is the right behaviour for content the *service* chose. It is the wrong
behaviour for content the *user* just chose: adding four points and watching
the machine quietly reword and drop them is the opposite of taking control.

## Decision

While editing, the composed document is re-laid-out deterministically —
compaction and stretch only, no service calls — and the preview shows the
resulting page count as the user works.

**Over two pages, Export is refused.** The preview says the CV is over and by
roughly how much; the user unticks or shortens something. The fit loop's
condense and trim passes are never run over hand-edited content.

## Consequences

- The fit loop still runs at **compose** time, on the tailor's own selection,
  exactly as decisions/0008 describes. It is editing that is protected from
  it, not composing.
- Re-layout during editing is deterministic, so it is instant and offline —
  the same property that lets coverage update live (decisions/0011).
- [CVEXPORT-25] is upheld by a different mechanism on this path: an
  over-length edit cannot reach the renderer at all, so no export can exceed
  two pages.
- The user can strand themselves in an over-length state and must resolve it
  before exporting. Accepted deliberately: an honest refusal beats silently
  undoing their work.
