# 0005 — Expand, don't reword: bullets grow from brief points at tailor time

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

The Profile redesign made Achievements brief talking points (root CONTEXT.md,
Profile decisions/0004+). v2 of `Prompts/tailor.md` assumed finished prose and
instructed conservative rewording ("same facts, the job's language").

## Decision

`Prompts/tailor.md` v3 changes the contract: the model selects best-fit points
(role `a…` and project `p…` ids) and **expands** each into one polished CV
bullet, grounded strictly in the point's own fields — text, impactMetric,
tech, tags, strengthNotes. Never invent; thin fields mean a terse bullet, not
padding. The JSON key is `bullet` (was `rephrasing`) because the semantics
genuinely changed; `achievementID` stays to contain churn.

## Consequences

- Rejecting an expansion puts the user's brief point verbatim on the CV
  ([TAILOR-14]) — correct, since the point is the user-owned canon.
- Education and interests travel as payload context only, never selectable.
- Existing long-form achievement texts still work — expansion of an
  already-full point returns it near-verbatim.
