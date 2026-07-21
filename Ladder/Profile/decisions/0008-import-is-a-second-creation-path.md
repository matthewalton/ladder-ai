# 0008 — CV import is a second creation path, via an all-or-nothing replace

Status: accepted (agreed with the human at the plan stage, 2026-07-21) —
amends 0002's "only creation path" stance

## Context

CV import is flipping from add-alongside merging to hard-refresh semantics
(CVImport's amendment, same plan): importing a CV makes the Profile fresh.
That needs a store pathway that can rebuild the whole Profile, and it makes
"create the Profile first, then import" a pointless detour — the CV carries
the identity the create form would ask for.

## Decision

The store gains one wholesale replace pathway that creates the single Profile
from a replacement value when none exists, and replaces an existing Profile's
entire content when one does. Replace is all-or-nothing over identity, contact,
roles, achievements, Tags, education, projects, and interests — it never
leaves a merged hybrid. The create-profile empty state stays as the manual
creation path; 0002's explicit-creation stance otherwise stands (nothing is
persisted the user didn't ask for — an import is an explicit act).

## Consequences

- 0002's "the create-profile empty state is the only creation path" no longer
  holds; its store-enforced single-profile invariant ([PROFILE-4]) does, through
  both branches of the replace.
- The Tag pool is rebuilt on replace — the one place wholesale `SkillTag`
  removal is correct, unlike single deletes ([PROFILE-6]/[PROFILE-16]).
- CVImport's merge becomes a caller of this pathway and stops layering roles
  alongside existing ones (CVImport supersedes its decisions/0001 and 0003).
