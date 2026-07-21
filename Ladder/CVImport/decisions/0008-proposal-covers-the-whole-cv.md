# 0008 — The proposal covers the whole CV

Status: accepted (agreed with the human at the plan stage, 2026-07-21) —
supersedes 0002 (roles, achievements, and skills only)

## Context

0002 deferred education and projects because their models did not exist. They
do now (Profile decisions/0004), plus contact info and interests — yet a real
CV import still routed everything but roles to not-imported sections. Tested
against the user's actual CV: contact details, education, projects, and
interests all failed to land.

## Decision

The proposal extends to the CV's identity (name, headline), contact (email,
phone, location, link), education entries, projects with their points, and
interests — everything the Profile schema can hold. The summary/profile
paragraph stays out **deliberately** (settled with the human): a CV summary
should be tailored to the job description, so it is generated per application
at tailor time (Tailor slice) rather than stored on the Profile. Not-imported
sections remain for it and anything else outside the schema.

## Consequences

- `Prompts/import.md` moves to v3 with the full schema; the proposal and
  review models grow to match.
- [CVIMPORT-9] (education/projects listed as not-imported) is retired;
  [CVIMPORT-23]–[CVIMPORT-27] replace it.
- ContactInfo keeps its single link field — per-project links land on the
  projects themselves.
