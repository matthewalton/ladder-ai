# Profile — language

Slice-local terms. `Profile`, `Role`, `Achievement`, and `Tailoring` are defined in
the root `CONTEXT.md` and are not restated here.

**SkillTag**:
A named skill, stored once per distinct name (case-insensitive) and shared across
the Profile — achievements reference SkillTags, they never own private copies.
_Avoid_: chip (that is the UI rendering of a SkillTag), tag, skill label

**Contact info**:
The Profile's identity-header value type — email, phone, location, link. A Codable
struct on the Profile, not a model of its own.
_Avoid_: contact details, ContactCard

**Strength notes**:
The user's own context or STAR expansion on an Achievement — raw material for
later tailoring and debriefs, never shown on a rendered CV.
_Avoid_: notes, description, comments

**Create-profile empty state**:
The screen shown when no Profile record exists; the only place a Profile can be
created (decisions/0002).
_Avoid_: onboarding, setup wizard, welcome screen

**Add-first-role empty state**:
The screen shown inside an existing Profile that has zero roles.
_Avoid_: blank slate, zero state
