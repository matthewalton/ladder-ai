# 0007 — Calendar-first import: heuristic + browse surfacing, create-on-confirm, on-demand look-back

Status: accepted (agreed with the human at plan, 2026-07-19; the look-back
range is **defaulted**, see below)

## Context

The slice was board-first: an Application had to exist past Draft before an
event could match ([CALSYNC-1]–[CALSYNC-6]). Real usage arrived in the other
order — interviews already on the calendar, no Application yet — and the scan
correctly, uselessly, proposed nothing ([CALSYNC-20]'s explainer, working as
specced). The gap surfaced during the Phase 2 exit dry run: two real
interview events inside the window, zero proposals, because the board held no
application for either company.

## Decision

**Surfacing is two-tier, and creation stays behind confirmation.** Matching
runs first and wins. Events left unmatched go through the interview
heuristic: a title keyword or a recognised meeting link flags the event as a
possible-interview proposal ([CALSYNC-21], [CALSYNC-22]); neither signal →
no proposal ([CALSYNC-23]). The browse list is the fallback for what the
heuristic misses: every window event minus linked/dismissed, any of which
can be picked into a proposal on demand ([CALSYNC-27], [CALSYNC-28]). The
heuristic stays deliberately small because the browse list is the escape
hatch. Nothing is created silently (ARCHITECTURE.md §6): scans and picks
only propose; the confirmation sheet remains the single write gesture.

**The heuristic vocabulary** is the word "interview" plus every keyword the
kind guess already knows (the decisions/0005 table) — one vocabulary, two
uses, no second list to drift.

**The company guess** pre-fills the sheet's company field, domain first:
the registrable-domain label of a non-public attendee or organizer email
(the [CALSYNC-4] rules, via `CalendarMatcher.companyLabel`), cased from the
title when the label appears there ([CALSYNC-24]). With no usable domain,
the fallback is the title stripped of the heuristic vocabulary and
connective words ([CALSYNC-25]). A guess only ever pre-fills — the
[CALSYNC-15] stance.

**Confirming a possible-interview proposal creates** an applied Application
plus its event-linked Stage in one gesture ([CALSYNC-26]), through
`PipelineStore.createApplication` then `addStage`, so the [PIPEBOARD-7]
auto-advance lands it active. `appliedAt` takes the event's start — the real
application predates the interview, but the event is the best evidence on
hand, and the date is as editable as any manual add's. `source` records
"calendar".

**The look-back is on-demand only**: a per-application action running one
wider scan — ninety days back to the scan instant — matched against that
application's company alone, sole candidate pinned ([CALSYNC-29],
[CALSYNC-30]). The standing window (decisions/0003) is untouched; no
automatic retro-scan ever runs.

**Defaulted, not agreed:** the ninety-day range. The human chose "on demand
only" without ruling on the number; ninety came from the recommendation
(covers a job-search season). It lives in one place in code — revisit with
evidence, the decisions/0003 posture.

## Consequences

- Real calendar-first interviews import in two gestures (pick/confirm),
  with company pre-filled — but never zero gestures: §6 holds.
- [CALSYNC-3] narrows without retiring: an unmatched event now yields no
  proposal only when the heuristic is silent too.
- The bar can now show proposals for companies the board has never heard
  of; dismissal ([CALSYNC-11]) is the noise valve, unchanged.
- A second write path into PipelineStore exists (create + stage in one
  confirm); it reuses the manual-add invariants (blank fields refuse,
  backdating allowed) rather than inventing its own.
