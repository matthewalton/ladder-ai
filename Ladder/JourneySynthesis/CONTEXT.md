# Journey synthesis — language

Slice-local terms. `Application`, `Stage`, `Profile`, and `indicator row`
are defined in the root `CONTEXT.md`; `Debrief` in
`Ladder/Debrief/CONTEXT.md`; `Prep pack` in `Ladder/PrepPack/CONTEXT.md`.
None is restated here.

**Journey narrative**:
The persisted retrospective prose over one Application's full Stage chain,
generated on explicit user action when the Application is at `.offer`.
Plain text plus `generatedAt`; one per Application; regenerating replaces.
The feedstock for the Phase 5 celebration view, not the view itself.
_Avoid_: journey (bare — that is the Phase 5 module), retrospective,
story, summary, celebration

**Stage chain**:
The Application's Stages in `sortIndex` order — the spine the narrative is
told along. Every Stage is in the chain, debriefed or not.
_Avoid_: stage history, timeline (the Phase 2 slice), loop

**Journey section**:
The Application-detail section that holds the narrative text and, at
`.offer`, the generate action. Plain inline text — never a window, never
an illustration.
_Avoid_: celebration view, summit view, journey view (all Phase 5)

**Offer-time gate**:
The rule that generation is offered and accepted only while the
Application's status is `.offer` — in the UI ([JOURNEY-14]) and the store
([JOURNEY-5]) alike. Display is not gated: a persisted narrative shows at
any status.
_Avoid_: offer check, status guard
