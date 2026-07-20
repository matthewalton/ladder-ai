# 0009 — Proposals list in the sidebar; the bar slims to header, check, and explainers

Status: accepted

## Context

The bar rendered every pending proposal above the board. Each proposal row
made the bar taller, pushing the board down (and, before the layout fix,
painting over it) — the standing surface for proposals competed with the
content it sat on. The user asked for the proposals to live in the
Applications sidebar instead: tracked applications first, a divider, then
the proposals, reviewable and dismissable from there.

## Decision

- Every pending proposal — matched and possible-interview alike — lists in
  the **calendar section**: the area of the Applications sidebar beneath the
  tracked-applications list, separated by a divider. One surface, not a
  split by proposal flavour.
- With zero pending proposals the calendar section does not render — no
  divider, no header, the sidebar reads exactly as before the slice existed.
- The **bar stays** but slims permanently: its header, the "Check calendar"
  control (still the explicit gesture that first requests calendar access,
  decisions/0008), and the explainers ([CALSYNC-17], [CALSYNC-19],
  [CALSYNC-20]). It never renders proposal rows again.
- Sidebar rows are compact — event title, start, possible-interview badge or
  kind guess. Clicking a row opens the confirmation sheet; dismissal is a
  hover ✕ and a right-click context menu, both through the same
  `CalendarSyncStore.dismiss` path ([CALSYNC-11], [CALSYNC-12] unchanged).
- Cross-slice plumbing only: `PipelineRootView` (PipelineBoard slice) gains
  an unspecced sidebar-bottom accessory slot, wired in `App/ContentView`.
  No PIPEBOARD criterion changes; the calendar section's behaviour is owned
  here.

## Consequences

- The board never loses vertical space to proposals; the bar's height is
  constant apart from explainers.
- Proposals gain a standing, glanceable home alongside the applications
  they may become — at the cost of a narrow (~200pt) surface, hence the
  compact row and click-to-sheet interaction instead of inline buttons.
- [CALSYNC-35] and [CALSYNC-36] pin the split; the bodies of [CALSYNC-23],
  [CALSYNC-30], and [CALSYNC-33] now speak of the calendar section where
  they said "the bar".
