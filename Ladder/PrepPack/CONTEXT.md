# Prep pack — language

Slice-local terms. `Application`, `Stage`, `Profile`, and `Achievement` are
defined in the root `CONTEXT.md`; `Debrief` in `Ladder/Debrief/CONTEXT.md`.
None is restated here.

**Prep pack**:
The persisted preparation material for one upcoming Stage — likely
questions, talking points, company brief, and mock tasks — generated on
explicit user action from the Stage's kind, the job description, the prep
context, the prior debriefs, and the Profile. One per Stage; regenerating
replaces. Forward-looking coaching, never evidence (decisions/0002).
_Avoid_: briefing, cheat sheet, study guide, dossier

**Likely question**:
One question the service predicts the interviewer will ask at this Stage.
Plain text, persisted in the service's order.
_Avoid_: predicted question, sample question

**Talking point**:
One thing worth saying at this Stage, as the service proposed it: its text
plus its mapped achievements. A model row, not a value struct
(decisions/0001).
_Avoid_: bullet, highlight, selling point

**Mapped achievements**:
The Profile Achievements a talking point links as the material behind it —
a relationship to the canon, never a copy, resolved from payload indices
(decisions/0001).
_Avoid_: missed ammo (the debrief's word for the backward-looking link),
achievement ids

**Company brief**:
The service's short orientation on the company and role, drawn from the
job description and pasted prep context only — never scraped, never
outside knowledge presented as fact.
_Avoid_: company research, intel, background check

**Mock task**:
One practice exercise for a technical-type Stage, tuned to the JD's stack:
a title and a brief. A value struct on the pack; answered outside the app
(§6 v1 ruling: exported, not interactive).
_Avoid_: drill (the debrief's word), challenge, homework

**Technical-type Stage**:
A Stage whose kind is technical, system design, or take-home — the kinds
whose prep pack carries mock tasks.
_Avoid_: coding stage, hard stage

**Prior debriefs**:
The debriefs of the Application's Stages ordered strictly before the
prepped Stage — the earlier calls this pack learns from. A later Stage's
debrief, or the prepped Stage's own, is never prior.
_Avoid_: past debriefs, history, previous feedback

**Prep export**:
The whole pack rendered as one markdown file through the save panel —
offline string assembly, no service call.
_Avoid_: report, download, printout
