# 0001 — Heard back is derived from Stage dates, never stored

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

ROADMAP's timeline runs applied → heard back → each Stage → outcome, but
`Application` has no `heardBackAt` field — only each `Stage` carries one
(editable in pipeline-board's stage form since PIPEBOARD, populated
opportunistically by calendar-sync). The ticket left open whether the
application-level heard-back moment needed a new field plus an editor, or
could be derived.

## Decision

The heard-back entry is derived: the earliest date across every Stage's
`scheduledAt` and `heardBackAt` ([TIMELINE-2]). No new model field, no
migration, no amendment to the PIPEBOARD slice. When no Stage carries a
date, the entry is absent ([TIMELINE-3]).

## Consequences

- The slice stays purely read-only — its whole surface is presentation over
  what pipeline-board and calendar-sync persist.
- A response that never becomes a Stage (a rejection email, say) cannot set
  heard back today. That is the ARCHITECTURE.md §6 "capture opportunistically"
  stance: when Phase 3/4 paste-in parsing lands, capture writes a Stage or a
  Stage date, and the timeline picks it up with no change here.
- The write path for every timeline date remains where it already lives:
  pipeline-board's stage form and calendar-sync's confirmation.
