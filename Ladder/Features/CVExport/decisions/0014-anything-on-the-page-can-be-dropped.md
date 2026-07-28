# 0014 — Anything on the page can be dropped for one CV; only the Profile rewords it

Status: accepted (agreed with the human at the plan stage, 2026-07-28)

## Context

Baton #163's ask is full control over what a given employer sees. Limiting
removal to what tailoring selects — bullets, projects, skills — leaves the
Profile-derived sections untouchable: an education entry, an interest, a
contact line, or a role the user would rather leave off *this* application
could only be removed by editing the Profile, which changes every future CV.

[CVEXPORT-3] deliberately renders **every** Role so an ATS reading the CV
sees continuous employment and detects no gaps. Allowing a role to be dropped
knowingly gives that up. The cost was put to the human at the plan stage and
the wider surface was chosen.

## Decision

- **Removable, per application:** any bullet, project, skill, skill category,
  education entry, interest, contact line, the headline, the summary, and a
  whole role.
- **Not removable:** the Profile's name. A CV must identify its author.
- **Rewordable:** bullets and the CV summary only — the per-application
  wordings that already exist (Tailor `CONTEXT.md`: rephrasing). Every other
  section renders verbatim from the Profile; wrong wording is fixed in the
  Profile editor, the canonical place (decisions/0010).

Removal is always the user's explicit act. Nothing in the pipeline — tailor,
fit loop, renderer — may drop a role.

## Consequences

- **[CVEXPORT-3] is amended**: every Role renders unless the user removed it,
  and the ATS-continuity rationale moves into the body as the reason the
  default is to keep them. Tailoring still trims bullets, not jobs.
- [CVEXPORT-2], [CVEXPORT-18] and [CVEXPORT-33] take the same qualification —
  they describe what renders from the Profile absent a removal.
- Dropping a role can produce an employment gap that costs the user an ATS
  screen. The preview is the only place this is visible, so it is the place to
  say so.
- Removals are session-scoped like every other preview edit
  (decisions/0013): the next composed CV starts from the Profile again.
