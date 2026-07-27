# 0008 — Check results are ephemeral: results sheet, other events, no standing browse surface

Status: accepted (agreed with the human at plan, 2026-07-20; supersedes the
browse-surfacing part of decisions/0007)

## Context

decisions/0007 made the browse list the heuristic's escape hatch — every
window event minus linked/dismissed, behind a standing "Browse events"
button on the bar, available at any time after any scan. In use that
standing surface felt wrong: the human wants the full fetched list shown
once, as the result of the check they just ran, with the uninteresting
events out of the way — not a browse affordance that lingers in the bar
indefinitely.

## Decision

**A check — the user-initiated scan — presents a check-results sheet** when
its scan completes: proposals (matched and possible-interview) prominent on
top with the normal Review/Dismiss flow, and beneath them a collapsed
"Other events (N)" disclosure. The standing "Browse events" button is
removed; there is no other route to the full list.

**Other events** are the check's fetched events that produced no proposal —
linked ([CALSYNC-10]), dismissed ([CALSYNC-11]), and proposed events all
excluded, since a proposal already surfaces above ([CALSYNC-31]). Same
fetched events as the scan, no second fetch.

**The list is user-check-only and ephemeral.** Automatic re-scans — the
calendar-change signal ([CALSYNC-14]) and the already-granted launch scan —
refresh proposals but leave other events empty ([CALSYNC-32]). Closing the
sheet discards the list ([CALSYNC-33]). Nothing is ever persisted to disk —
the pre-0008 posture, now pinned. The bar afterwards shows proposals only.

**The expanded disclosure carries a title filter** ([CALSYNC-34]):
case-insensitive containment, empty filter shows all. The human reviewing a
check knows the interview they're looking for; typing beats scrolling a
month of calendar.

**Picking stays the escape hatch**: any other event becomes a proposal on
demand, [CALSYNC-28] semantics unchanged — candidates when matching finds
tracked Applications, possible-interview proposal otherwise, then the
normal confirmation flow.

All three choices (results sheet over inline disclosure, user-check-only
lifetime, title filter) were agreed with the human at plan — none defaulted.

## Consequences

- [CALSYNC-27] is retired — its promise was the standing browse list. The
  number 27 stays retired; [CALSYNC-31]–[CALSYNC-34] carry the new surface.
- The store must distinguish a check from an automatic re-scan; the
  calendar-change observer and launch path call the automatic form.
- An interview the heuristic misses is now only reachable while its check's
  sheet is open — the cost of a quiet bar, accepted knowingly: checking
  again is one click.
- decisions/0007's heuristic, company guess, create-on-confirm, and
  look-back decisions all stand; only its browse surfacing is superseded.
