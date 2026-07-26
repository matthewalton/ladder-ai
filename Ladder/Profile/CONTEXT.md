# Profile — language

Slice-local terms. `Profile`, `Role`, `Achievement`, `Tag`, and `Tailoring` are
defined in the root `CONTEXT.md` and are not restated here. (`Tag` moved up on
2026-07-26 when the JD side began sharing the vocabulary; decisions/0006
remains the record of why it is matching metadata, not a profile section.)

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
(wording, Tags, impact metric, strength notes; role/education/project
fields — `tech` retired, decisions/0011). It is always present — unfocused it
shows a placeholder.
_Avoid_: inspector, sidebar

**Tag manage sheet**:
The sheet a Tag chip opens to curate the one shared Tag — recase its primary
name, record or remove Aliases (decisions/0013). One Tag at a time: a
pool-wide manager view is deferred.
_Avoid_: tag editor, tag settings, pool manager (the deferred view)

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
