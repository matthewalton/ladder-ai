# Debrief — language

Slice-local terms. `Application`, `Stage`, `Profile`, and `Achievement` are
defined in the root `CONTEXT.md`; `notes overview` in
`Ladder/TranscriptImport/CONTEXT.md`. None is restated here.

**Debrief**:
The persisted, evidence-based analysis of one Stage's call — question
entries, themes, signals, and drills — generated on explicit user action
from the notes overview, the Stage's context, and the Profile. One per
Stage; regenerating replaces.
_Avoid_: report, scorecard, assessment, review (that word belongs to
tailor and cv-import)

**Question entry**:
One question the interviewer asked, as the service reported it: the
question, an answer summary, an answer quality, a grounding quote, and
missed ammo. A model row, not a value struct (decisions/0001).
_Avoid_: QAItem, Q&A, exchange

**Answer quality**:
The service's categorical judgement of one answer — strong, adequate, or
weak. Never a number (ARCHITECTURE.md §1).
_Avoid_: score, rating, grade, percentage

**Claim**:
A statement the debrief makes about what happened on the call — a question
entry, a theme, or a signal. Every claim carries a grounding quote
(decisions/0002). Drills are recommendations, not claims.
_Avoid_: finding, insight

**Grounding quote**:
The verbatim excerpt of the notes overview attached to a claim as its
evidence; validated as an exact substring of the notes overview.
_Avoid_: citation (the segment-level word that returns with native
capture), evidence, source

**Grounded remark**:
A theme or signal's value shape: its text plus its grounding quote.
_Avoid_: bare string, note

**Missed ammo**:
The Profile Achievements a question entry links as the stronger material
the answer never used — a relationship to the canon, never a copy
(decisions/0001).
_Avoid_: missed opportunity, suggestion, gap (that word belongs to tailor)

**Theme**:
A recurring topic the service heard across the call; a grounded remark.
_Avoid_: topic, pattern

**Signal**:
What the interviewer's words indicated — interest, concern, a hint about
next steps; a grounded remark. Never a probability.
_Avoid_: vibe, read, prediction

**Drill**:
One concrete practice exercise the debrief recommends before the next
Stage. Plain text, no quote.
_Avoid_: action item, homework, exercise
