# Ladder

macOS-native interview companion. One canonical Profile feeds tailored applications, pipeline tracking, interview capture, and AI debriefs — the loop compounds because every feature reads from the same career history.

## Language

**Profile**:
The user's single, canonical career history — identity header (name, headline, contact) plus roles, education, projects, and skills. Exactly one exists; there is no profile switcher. Tailoring is the mechanism by which the one Profile presents differently per application.
_Avoid_: CareerProfile, vault, CV vault

**Achievement**:
The atomic unit of the Profile — one brief, factual talking point of something the user moved forward, belonging to a Role or a Project. It carries an optional title (the bold lead phrase on a rendered CV bullet) and its text, the description. Both are canon: the user writes them terse; tailoring expands the description into polished CV prose per application but never edits either silently, and never writes the title. (UI copy may call these "points"; the domain word stays Achievement.)
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

**Tag**:
A short named label for any matchable concept a profile point evidences — a
technology ("Swift"), practice ("Incident response"), or looser theme
("Spec-driven development"). One flat vocabulary: Tags carry no type or
category, and there are no parallel typed fields beside them (2026-07-26; CV
skill groupings are invented per application at tailor time, never stored —
Tailor decisions/0009). Stored once per distinct name (case-insensitive) and
shared across the Profile; Achievements and Projects reference Tags, never own
private copies. Tags exist to match the Profile against a job description's
vocabulary — matching metadata, not a profile section (Profile
decisions/0006). Implemented by the legacy `SkillTag` model — never renamed in
code.
_Avoid_: skill, skill tag, keyword, tech (retired field), chip (the UI
rendering of a Tag)

**Alias**:
An alternate name recorded on a Tag so near-miss vocabulary still matches —
"postgresql" on **PostgreSQL**, "k8s" on **Kubernetes**. The primary name is
what every surface shows, stored in curated casing ("iOS", never "Ios");
aliases are matching-only, lowercase, and visible only when managing the tag.
Any name resolved against the pool — JD scan, CV import, Tag suggestion —
resolves case-insensitively against primary names and aliases alike.
_Avoid_: synonym

**Tag suggestion**:
An LLM-proposed change to the Tag vocabulary: attaching an existing Tag to an
Achievement or Project, minting a new Tag, or recording an Alias. Always
grounded in what the point or job description actually evidences — never
keyword-stuffing to lift a score — and it never lands without the user
confirming it (in the Match review, the import review, or on demand from a
point's detail). The LLM proposes; only the user writes (2026-07-26).
_Avoid_: auto-tagging, tag refinement

**Tailoring**:
Selecting best-fit points from the Profile (role Achievements and project points) for a pasted job description, expanding each brief point into one polished CV bullet grounded in the point's own fields, and flagging gaps. It never free-writes career history. Since 2026-07-26 it begins with a JD scan and Match review — selection is grounded in a confirmed Match, never a raw JD.
_Avoid_: generating a CV, optimising

**JD scan**:
The LLM pass that reads an Application's job description against the Profile's
Tag vocabulary (primary names and Aliases), producing the Match and the Tag
suggestions that could strengthen it. Runs as the first step of tailoring, and
on demand; each run refreshes the Application's Match against the current
pool.
_Avoid_: keyword extraction, JD parsing

**Match**:
The confirmed correspondence between one Application's job description and the
Profile: which of the JD's asks the Tag vocabulary covers (matched Tags),
which it doesn't (vocabulary Gaps), and the **Match score** — a
deterministic number derived from tag overlap alone, recomputed live as Tag
suggestions are toggled in the **Match review**, the confirmation step that
precedes selection. LLM-judged relevance never moves this score. A Match
tracks the pool rather than freezing it — it is refreshed by each JD scan; the
immutable record of what was sent remains the CV snapshot.
_Avoid_: fit / fit score (the page-fit loop owns "fit"), relevance score

**Gap**:
A job-description requirement the Profile doesn't cover, qualified by which
check failed. A **vocabulary gap** is word-level and deterministic, found by
the JD scan: no Tag — primary name or Alias — matches the ask. An **evidence
gap** is content-level and LLM-judged, found at tailor time: no Achievement or
Project substantiates the ask, whatever the tags say. Vocabulary gaps surface
in the Match review, where accepting a Tag suggestion can dissolve one;
evidence gaps surface in the tailor review. UI may label both plainly as
"Gaps".
_Avoid_: unmatched requirement, missing skill

**Indicator row**:
The collapsed presentation of long text content that is set — a row identifying the content, with Open and Remove, never the text inline. Typed-or-imported content identifies itself by its opening snippet and its size; generated content by the date it was made (docs/adr/0006). The app-wide rule is docs/adr/0003; Granola notes established the pattern.
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
