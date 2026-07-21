# 0004 — The skills line derives from the selected points' Tags

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

The Profile redesign reframed skills as **Tags**: matching metadata attached
to individual points, not a profile-level CV section (Profile
decisions/0006). This slice previously rendered the whole `profile.skills`
pool as the CV's Skills section.

## Decision

`CVDocument.skills` is the sorted unique union of Tag names across the
review's selected points (role and project). `profile.skills` is no longer
read by this slice.

## Consequences

- The skills line is per-application relevant — exactly the vocabulary the
  selection earned — instead of a dump of everything the user has ever tagged.
- A CV can render with no Skills section when the selected points carry no
  Tags.
- [CVEXPORT-6] rewritten to promise the derivation, including the negative
  case (unselected points' Tags absent).
