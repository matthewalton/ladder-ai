# Ladder

macOS-native interview companion. One canonical Profile feeds tailored applications, pipeline tracking, interview capture, and AI debriefs — the loop compounds because every feature reads from the same career history.

## Language

**Profile**:
The user's single, canonical career history — identity header (name, headline, contact) plus roles, education, projects, and skills. Exactly one exists; there is no profile switcher. Tailoring is the mechanism by which the one Profile presents differently per application.
_Avoid_: CareerProfile, vault, CV vault

**Achievement**:
The atomic unit of the Profile — one brief, factual talking point of something the user moved forward, belonging to a Role or a Project. Its text is canon: the user writes it terse; tailoring expands it into polished CV prose per application but never edits it silently. (UI copy may call these "points"; the domain word stays Achievement.)
_Avoid_: bullet, accomplishment

**Role**:
A position held at a company over a period; owns its Achievements. (A "current" role is one with no end date.)
_Avoid_: job, position

**Application**:
One pursuit of a specific job at a company; owns an ordered chain of Stages, plus the immutable CV snapshot that was actually sent.
_Avoid_: opportunity, candidacy

**Stage**:
One step in an Application's interview loop (screen, recruiter, technical, …) carrying its prep context, prep pack, transcript, debrief, and outcome.
_Avoid_ (functional contexts): round, waypoint, interview

**Tailoring**:
Selecting best-fit Achievements from the Profile for a pasted job description, proposing rephrasings, and flagging gaps. It never free-writes career history.
_Avoid_: generating a CV, optimising

**Indicator row**:
The collapsed presentation of long text content that is set — a row showing the content exists, with Open and Remove, never the text inline. The app-wide rule is docs/adr/0003; Granola notes established the pattern.
_Avoid_: collapsed view, summary row, chip

## Flagged ambiguities

- **"vault" retired (2026-07-17):** ARCHITECTURE.md originally used "CareerProfile" in code and "vault" in product copy for the same concept. Merged: the canonical term is **Profile** everywhere — model, folders, UI. Trail-flavoured narrative copy may say "pack" instead.
- **Trail vocabulary** (waypoint, summit, trail, pack, base camp) is narrative-only, per DESIGN.md §9. It appears in New York-set storytelling text, never in functional UI text or code identifiers. A Stage node on the Summit View may be *rendered* as a waypoint; the type is `Stage`.

## Example dialogue

> **Dev:** When someone imports a CV, do we create a new Profile?
> **Expert:** Never — the create-profile empty state is the only place a Profile is created, and import requires one to exist first. Import proposes Roles and Achievements *into* the Profile, and nothing lands without the user confirming each item.
> **Dev:** And when they apply somewhere, we copy the Profile onto the Application?
> **Expert:** No — tailoring selects and rephrases Achievements for that one job description. The Application stores the rendered PDF as an immutable snapshot and the selection rationale, but the Achievements themselves stay in the Profile, untouched.
> **Dev:** So if an interview goes badly, the debrief compares the transcript against the Profile?
> **Expert:** Right — that's the whole point. The debrief can say "you gave the weak version of that story; the stronger Achievement is on file" precisely because the Profile is the one persistent asset everything reads.
