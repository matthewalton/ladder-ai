# delivery-route lens

**Stance:** a plan that never says where the work lands lands on `main` by silence, and the
CI panel never sees it. Naming the route is one line while the plan is still cheap; finding
out it mattered means finding out from a merged commit.

## When this lens has work

Every plan. There is no scope that exempts a plan from saying where its commits go — but the
report is empty the moment the plan names a route and the choice is defensible.

## What to look for

- **No route named.** The plan must say **main** or **pull request** in so many words.
  Silence is not the default route; it is a decision nobody made (project CLAUDE.md →
  Workflow: Speccle).
- **`main` chosen for a change the CI panel should see.** These are the signals worth a
  pull request, and a plan carrying one without a word about it is the finding:
  - it touches `Ladder/Shared/` — design system, models, services every slice depends on
  - it edits another slice's shared ground: a model that slice defined and others amend
    in place (`Application`, `SkillTag`, `Stage`)
  - it lands or supersedes an ADR in `docs/adr/`
  - it changes the machinery itself — `.speccle/`, `project.yml`, `scripts/`, `.github/`
  - it crosses the privacy posture: the Keychain, the `IntelligenceService` seam, or any
    new path along which stored content leaves the machine
  - it is the first slice of a phase, or the first of its kind in the repo
- **Pull request chosen for a change that does not need it.** The CI panel is metered — a
  model call per lens per push. A two-line amendment routed through a pull request pays for
  a review the local `/review` already does for free. Say so; recommend `main`.
- **A pull-request plan with no branch named.** The route is only real once the branch is:
  the session that commits the contract cuts `feature/<key-lowercased>-<slug>`, and every
  later session reads the route back off `git branch --show-current`. A plan that opts in
  without naming the branch leaves the first session guessing.
- **A pull-request route on a slice already part-built on `main`.** Half a slice merged and
  half on a branch is a pull request whose diff cannot show the whole behaviour. Finish
  what is on `main` first, or the plan says out loud why the split is deliberate.

## How to report

- **where** — the plan element it anchors to: the route line, the scope, or a key decision
- **severity** — major · minor · nit
- **what** — what the route gets wrong, in one plain sentence
- **why** — the review the change would miss, or the metered run it would waste
- **suggest** — the route you would plan instead, and the branch name if it is a pull request
