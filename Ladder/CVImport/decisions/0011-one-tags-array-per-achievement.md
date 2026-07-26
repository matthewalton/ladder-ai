# 0011 — One tags array per achievement: the skills + tech split is gone

Status: accepted (agreed with the human at plan, 2026-07-26)

## Context

Root `CONTEXT.md` (2026-07-26) fixed one flat Tag vocabulary with no
parallel typed fields, and Profile decisions/0011 removed
`Achievement.tech`. The v5 proposal schema still asked the model for both
`skills` and `tech` per achievement — two lists feeding two destinations,
one of which no longer exists.

## Decision

The proposal carries one `tags` array per achievement ([CVIMPORT-32]);
projects keep their single list, renamed to the same word ([CVIMPORT-28]).
`Prompts/import.md` version-bumps with the folded instruction; the canned
fixture proposal and the schema validation follow. Review and replace
behaviour is unchanged — a proposed tag is a proposed item exactly as a
proposed skill was ([CVIMPORT-4], [CVIMPORT-6], [CVIMPORT-20]).

## Considered options

- _Accept both shapes for a while_ — tolerate `skills`/`tech` keys alongside
  `tags`. Rejected: the prompt and schema travel together in every request
  ([CVIMPORT-13]), so there is no window in which a live model legitimately
  answers with the old shape; tolerance would only mask a wrong prompt.

## Consequences

- A response with the old keys and no `tags` fails validation with its
  reason ([CVIMPORT-17]) — no back-compat window.
- The review renders one tag list per achievement; nothing else about the
  flow moves.
