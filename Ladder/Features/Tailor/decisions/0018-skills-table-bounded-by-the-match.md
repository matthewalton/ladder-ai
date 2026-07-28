# 0018 — The skills table is bounded by the Match, not by the selection alone

**Status:** accepted (2026-07-28, agreed with the human)

## Context

Ticket #196: a generated CV's skills table carried skills with no bearing on
the job description. This was working as specced. decisions/0009 bounded the
grouping to the selection's Tag union (CVExport decisions/0004's vocabulary
rule, grouped instead of flat), and `Prompts/tailor.md` v9 says "use only
tags that appear on selected achievements or selected projects". Validation
enforced exactly that and no more — the only rejection was a *stray*, a skill
on no selected point.

So the table was the union of every Tag on every selected point. A point
selected for one strong, relevant reason dragged its whole Tag set onto the
CV. The union was the wrong bound: it is the vocabulary the *selection*
earned, when what the table should show is the vocabulary the *job
description* asked for and the selection can evidence.

The material to bound it with already exists and already reaches the
validation site: the confirmed Match's matched Tags (decisions/0011,
[TAILOR-49]), which `TailorStore.startRun` receives as `matchedTagNames`
alongside the payload's `tagNamesByID`.

## Decision

- **`skillCategories` is bounded by the intersection**: a skill may appear
  only when it is on selected content *and* in the confirmed Match's matched
  Tags. decisions/0009's union bound is tightened, not replaced — the
  grouping is still per-CV, still service-named, still transient, and still
  travels to cv-export's renderer verbatim.
- **Enforced deterministically in Swift**, the way strays are today: a skill
  outside the intersection fails validation and feeds the single repair
  (decisions/0004). The prompt instructs; validation is what guarantees.
- **An empty intersection means an empty table**, not a fallback to the
  union — the specced degenerate case already ([TAILOR-24]: no selected tags
  means an empty array; CVExport decisions/0004: a CV can render with no
  Skills section). A thin table is a true report that the vocabulary does not
  match, and the user has already seen that as the Match score before
  confirming the review.
- **`Prompts/tailor.md` version-bumps to v10** and carves `skillCategories`
  out of the "never echo `overlap` back" instruction (v9, lines 14–16) —
  which the matched-Tag names now must be echoed into.

## Considered options

- *Rank by match and backfill to a category minimum* — avoids a thin table,
  but still puts JD-irrelevant skills on the CV, which is the complaint in
  smaller print. It also needs a specced minimum, and validation cannot
  distinguish a legitimate backfill from a stray without re-deriving the
  ranking. Rejected.
- *Keep the union, have the model justify each skill against the JD* — puts
  vocabulary-relevance judgement back in the model, which root ADR 0005
  deliberately keeps deterministic, and a justification string cannot be
  validated: the guarantee would only be as good as the model's self-report.
  Rejected.

## Consequences

- The skills table becomes a subset of what it rendered before, so
  [CVEXPORT-23]'s vocabulary bound ("every skill shown comes from the
  selection's Tag union") stays true unamended — cv-export needs no change.
- The Match now reaches the CV's content, not just the payload's ordering and
  the review's overlap view. Curating the Tag pool in the Match review has a
  visible effect on the rendered CV.
- A low-coverage Match yields a short skills table or none. That is the
  intended report, and the Match review is where it is fixed — by confirming
  suggestions, which move gaps into matched Tags ([TAILOR-49]).
- The Match score is untouched: this reads matched Tags, never writes them,
  and nothing here feeds back into the score (root ADR 0005).
