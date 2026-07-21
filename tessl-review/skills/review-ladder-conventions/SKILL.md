---
name: review-ladder-conventions
description: Review a diff against Ladder's project conventions — the rules recorded in CLAUDE.md and the source-of-truth docs (ARCHITECTURE.md, DESIGN.md, CONTEXT.md, docs/adr/). Flags phase-gate breaches, design-system bypasses, unsafe API-key handling, SwiftData model changes without a round-trip test, direct LLM access outside IntelligenceService, edits to generated files, and non-canonical domain terms. Use as a project-convention review lens in `tessl change review` or a GitHub Actions review workflow.
---

# Review Ladder Conventions

A project-convention review lens for `tessl change review`. Ladder is a
macOS-native SwiftUI + SwiftData app whose rules live in `CLAUDE.md` and four
source-of-truth docs. New code sometimes bypasses one of these rules in a way a
generic reviewer would miss. Review the diff for concrete breaches of the
conventions below and report high-confidence, file-anchored findings.

## Stance

- Report a finding only when the changed lines actually breach a rule and you can
  name the rule and the offending line. When in doubt, stay silent — this lens is
  for clear convention breaches, not style opinions.
- Anchor every finding to a changed line (RIGHT side of the diff). Do not flag
  pre-existing code the diff merely moves unless the move itself breaks a rule.
- Prefer the rule's own remedy. Most breaches have one correct fix (use the
  accessor, add the test, move the key to Keychain); state it in one line.
- The canonical docs win. If the diff conflicts with `ARCHITECTURE.md`,
  `DESIGN.md`, `CONTEXT.md`, or an ADR, that is the finding — cite the doc.

## What to look for

Work through the diff against these rules. Each is a concrete, checkable breach.

1. **Phase gate — `Journey/` is frozen.** Any added or modified file under
   `Ladder/Journey/` is a hard breach (Phase 5 is gated; only a human advances
   phases by editing the "Current phase" line in `CLAUDE.md`). Flag it and stop
   short of suggesting the code — the fix is to not touch `Journey/`.

2. **Design system — colours and fonts via accessors only.** In view code, flag
   raw colour literals (`Color(red:green:blue:)`, `Color(hex:)`, `.init(hex:)`,
   asset-catalog colour names, hardcoded hex strings) and `.custom(...)` /
   hardcoded font sizes. Colours must come from `Palette.swift` accessors and
   type from `Typography.swift`. Exception: Summit View is exempt per DESIGN.md
   §3 — do not flag files that are part of the Summit View.

3. **API key — Keychain only.** Flag any key or secret written to or read from
   `UserDefaults`, embedded as a string literal in source, or passed to a logging
   call (`print`, `os_log`, `Logger`, `NSLog`). The only sanctioned store is the
   Keychain. Treat anything named like a key/token/secret being logged as a
   breach.

4. **SwiftData model change needs a round-trip test.** If the diff adds or
   changes a `@Model` type (new stored property, changed type, new model) under
   `Ladder/Shared/Models/` or a slice that owns a model, there must be a
   corresponding persistence round-trip test in the diff (save → refetch →
   assert). If the model changed and no such test is added or updated, flag it.

5. **LLM access behind `IntelligenceService`.** Flag any direct network/LLM call
   (URLSession to an API host, a vendor SDK client, a hardcoded model endpoint)
   in feature code that is not routed through `IntelligenceService`. Development
   uses `FixtureIntelligenceService`; live calls are only enabled deliberately in
   the tailor slice.

6. **Generated files are off-limits.** Flag any hand-edit to
   `Ladder.xcodeproj/` — the project is generated from `project.yml` via
   `xcodegen`. Changes belong in `project.yml`.

7. **New dependency without sanction.** Flag additions to Swift Package
   dependencies (new entries in `project.yml` packages, `Package.resolved`, or a
   new `import` of a third-party module) — dependencies require explicit human
   approval per CLAUDE.md.

8. **Canonical domain terms.** The Profile is the canonical term. Flag new
   identifiers, types, or user-facing strings using `vault` or `CareerProfile`
   for that concept. Prefer the vocabulary in `CONTEXT.md`.

9. **Every view has a `#Preview`.** If the diff adds a new SwiftUI `View` type
   without a `#Preview` in the diff, flag it (previews must keep compiling).

## How to report

- Anchor each finding to the changed line and name the rule it breaches, citing
  the doc where it lives (`CLAUDE.md`, `DESIGN.md §3`, the relevant ADR).
- State the one correct fix in a line — use the accessor, add the round-trip
  test, move the secret to Keychain, edit `project.yml` not the `.xcodeproj`.
- For the `Journey/` phase gate and unsanctioned dependencies, note that the
  resolution is a human decision, not a code change the author should just make.
- If the diff touches none of these rules, say so in one line.
