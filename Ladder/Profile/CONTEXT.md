# Profile — language

Slice-local terms. `Profile`, `Role`, `Achievement`, and `Tailoring` are defined in
the root `CONTEXT.md` and are not restated here.

**Tag**:
A named label attached to Achievements and to Projects so they can be matched
against a job description. Stored once per distinct name (case-insensitive)
and shared across the Profile — Achievements and Projects reference Tags, they
never own private copies. Tags are matching metadata, not
a CV section of their own (decisions/0006). Implemented by the legacy
`SkillTag` model — do not rename it in code (decisions/0006).
_Avoid_: skill, skill tag (in UI copy and docs), chip (that is the UI rendering
of a Tag)

**Point**:
Alias to avoid — the UI shows Achievements as brief bullet "points", but the
domain word stays **Achievement** (root `CONTEXT.md`). Views may use "point" in
user-facing copy; code identifiers and docs say Achievement. Since
decisions/0009 only Roles own Achievements — Projects have no points.

**Contact info**:
The Profile's identity-header value type — email, phone, location, link. A Codable
struct on the Profile, not a model of its own.
_Avoid_: contact details, ContactCard

**Education**:
One study entry — institution, qualification, start/end (nil end = in
progress), optional detail line. Facts, not selectable content: tailoring never
rewrites education.
_Avoid_: school, degree (as the entity name)

**Project**:
A piece of work outside a Role — name, optional link, one-line summary shown
inline next to the name, a multi-line description, and its own Tags for JD
matching, drawn from the shared pool (decisions/0009). Manually ordered.
_Avoid_: side project (as the entity name), portfolio item

**Description** (of a Project):
The Project's multi-line prose body — how the project is told on the profile
page and on a rendered CV. Distinct from the one-line summary, and from an
Achievement's strength notes.
_Avoid_: details (in UI copy and docs; the persisted attribute may keep the
name the schema needs), body, blurb

**Interests**:
An ordered list of short strings on the Profile — colour for the CV's final
section, no depth, no model.
_Avoid_: hobbies

**Strength notes**:
The user's own context or STAR expansion on an Achievement — raw material for
later tailoring and debriefs, never shown on a rendered CV.
_Avoid_: notes, description, comments

**Detail rail**:
The slim persistent pane beside the CV page that edits the focused item's depth
(wording, Tags, impact metric, tech, strength notes; role/education/project
fields). It is always present — unfocused it shows a placeholder.
_Avoid_: inspector, sidebar

**Create-profile empty state**:
The screen shown when no Profile record exists; the manual creation path
(decisions/0002). Since decisions/0008 a CV import may also create the Profile
through the replace pathway.
_Avoid_: onboarding, setup wizard, welcome screen

**Replace pathway**:
The store's wholesale mutation that rebuilds the Profile from a replacement
value — creating the Profile when none exists, replacing all content when one
does (decisions/0008). All-or-nothing; never a merged hybrid.
_Avoid_: bulk import (that is CVImport's flow; this is the store seam it calls),
reset
