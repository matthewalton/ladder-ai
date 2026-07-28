# 0010 — The preview selects and rewords; the Profile editor still authors

Status: accepted (agreed with the human at the plan stage, 2026-07-28)

## Context

Baton #163 arrived as "minor edits" but the live walkthrough wanted more:
full control over what lands on the CV, including points the service passed
over. The open question was whether "add a point" meant *pick one the
service skipped* or *write a new one here*.

Writing new points here would put a second authoring surface beside the
Profile editor, and a point that exists only in one PDF carries no Tags — so
no JD scan would ever match it, and the feedback half of the ticket would be
decorative.

## Decision

The preview's surface, over the composed document:

- **Select** — any Achievement or Project on the Profile may be added to this
  CV or removed from it, including ones the tailor result never selected. A
  skill may be dropped from the skills table.
- **Reword** — any bullet's text and the CV summary are editable in place,
  for this application only.
- **Tag** — a Tag may be applied to a point from the preview, which is how
  the user tells the model what it missed. This writes to the Profile: it is
  a **user action**, the only kind of Tag write there is (root ADR 0005 —
  the LLM proposes, only the user writes).

**The preview never authors a point.** A point that does not exist yet is
created in the Profile editor, the one canonical place.

## Consequences

- `Achievement.text` and `.title` stay canon (root `CONTEXT.md`): rewording
  here produces a per-application wording, exactly as a **rephrasing** does
  (Tailor `CONTEXT.md`) — the canon is never overwritten.
- [CVEXPORT-14] survives literally: **export** still writes nothing to the
  Profile. Applying a Tag is its own action with its own criterion, not part
  of the export.
- [CVEXPORT-5]'s stance narrows: a Profile achievement outside the *tailor's*
  selection may now appear, because the user put it there. The criterion is
  reworded to bind the render to the final selection rather than to the
  service's.
- The tailor slice's **Review** keeps its definition — it "never adds or
  removes achievements from the selection". That stays true of the tailor
  review; the preview is a different step.
