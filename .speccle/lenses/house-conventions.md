# house-conventions lens

**Stance:** the rest of the panel knows what good code looks like anywhere. This lens knows
what it looks like **here**. Every finding cites a rule someone already wrote down — CLAUDE.md,
an ADR, a slice's `**Traps**`, a past remedy — so the author can go and read it. A finding you
cannot cite is taste, not a convention: hold it, or route it `lens` and say the rule should be
written.

The rules live in five places, and a finding names which: the root `CLAUDE.md` (Conventions,
Testing, Repo layout), `CONTEXT.md` (the domain words), `docs/adr/` (decisions the code must
honour), each slice's `CLAUDE.md` under `**Traps**` (what that slice already paid for), and
`.speccle/remedies.jsonl` (a finding that recurred).

## What to look for

### Comments

- **Almost none, and never a restatement.** A comment that re-says a declaration, narrates the
  body's steps, or summarises a signature in doc-comment form is a finding on its own line.
  CLAUDE.md → Conventions is explicit: names carry the meaning.
- **Traceability is not a comment.** A comment citing a criterion token, a decision, or an ADR
  for behaviour the code makes plain is a finding — that history lives in `SPEC.md`,
  `decisions/`, and git.
- **A comment that guards an unreachable trap is a finding.** Before accepting a warning
  comment, check that a caller can actually reach the state it warns about. If none can, the
  comment is stale reassurance (remedy `comment-states-unreachable-trap`); the fix is to delete
  it and let a test defend the behaviour instead.
- **What does earn a comment:** a framework quirk, a hard-won trap, deliberately surprising
  test data — something the code cannot state. `// MARK:` is always fine.
- **`@Test("[TOKEN-n] …")` names are string literals, not comments.** Never flag one as noise
  and never propose stripping it — it is how a criterion claims its test.

### The design system

- **Colour and type come from `Palette.swift` / `Typography.swift` only.** A raw hex, a
  `Color(red:green:blue:)`, or a `.custom` font in a view is a finding.
- **There are exactly two exemptions, and both are written down:** the Summit View
  (DESIGN.md §3) and the rendered CV's print template (CVExport `decisions/0007`). A new site
  claiming exemption without a decision behind it is a finding — the fix is a decision record
  or an accessor.

### Layering

- **MVVM-lite: SwiftUI views plus `@Observable` stores.** No third-party architecture
  framework, and no new dependency of any kind without asking first.
- **Rules belong to the store, not the view.** The UI seam stays thin on purpose — pipeline-board
  keeps every move-legality rule in `PipelineStore` so the untestable part is only chrome.
  Logic that appears in a view and cannot be reached by a test is a finding.
- **An invariant belongs to the thing that owns it, not to each caller.** The single-`Profile`
  rule is the store's job; a second `Profile` is a bug wherever it was created. A new
  invariant enforced by convention at call sites is a finding.
- **A slice that writes nothing keeps writing nothing.** Timeline reads dates persisted by
  pipeline-board and calendar-sync; a change that needs new stored data belongs in the slice
  that owns the storage.

### Duplication that drifts

- **Two literals for one concept is a finding, even when they currently agree.** Two
  unconnected 720pt reading measures drifted independently until the constant moved to
  `Shared/DesignSystem` (remedy `duplicated-layout-constant`). A value two slices both depend
  on lives in `Shared/`, named.
- **A derived boolean that restates conditions another branch already establishes is a
  finding** (remedy `derived-predicate-duplicates-branch`) — the two can silently disagree once
  an arm is added. One expression decides; both sites read it.

### Slice boundaries

- **A slice constructs another slice's types through that slice's own fixture factory**, never
  through its validating initialiser — otherwise a validation change forces lockstep edits
  across a feature boundary (remedy `cross-slice-direct-construction`;
  `.speccle/checks/tailor-result-construction.json` gates the `TailorResult` case). Report the
  class when it appears on a type no check covers yet, and route `check`.
- **A validating initialiser gives no defaults to the bounds it validates.** A `= []` on a
  parameter the validation depends on silently disables it for every caller that omits it
  (remedy `optional-default-on-validating-init`). Required means required.
- **`Ladder/Features/` holds slices and nothing else**, siblings all the way down — no umbrella
  folder over a phase's slices. Versioned prompt files live in `Prompts/`, never beside a
  slice.

### The LLM seam, the key, the data

- **All model access goes through `IntelligenceService`.** A store, view, or helper reaching an
  HTTP client directly is a finding regardless of how well it works.
- **The API key is Keychain-only** — never `UserDefaults`, never a literal, never logged, never
  in an error message a user could screenshot (ARCHITECTURE.md §2 privacy posture, hard
  requirement).
- **Transcripts and profile content leave the machine only on a user-triggered action.**
  A new call site that sends stored content without the user asking for that analysis is a
  finding.
- **The Match score is computed in Swift from confirmed tag overlap alone** (ADR 0005). Any
  path that lets an LLM judgement move that number is a finding — the score's whole value is
  that it recomputes offline and can be explained tag by tag.
- **Nothing lands in the Tag vocabulary silently** (ADR 0005). Attaching a Tag, minting one,
  recording an Alias — each is proposed and user-confirmed.
- **Long text collapses to an indicator row** decided at appearance, opens in a window via
  `openWindow` rather than a sheet, and confirms before removal (ADR 0003). Typed-or-imported
  content identifies itself by opening snippet **and** size; generated content by its date
  (ADR 0006). A new long-text surface that invents its own pattern is a finding.

### Tests

- **A model change needs a round-trip persistence test in the same change.** Store tests use
  `ProfileStore.container(inMemory: true)`; persistence criteria reopen a file-backed container
  through the shared `temporaryStoreURL()` / `removeStore(at:)` helpers.
- **No test touches the network, ever.** Inject `FixtureIntelligenceService` and a faked key
  store. Never construct a live `EKEventStore` — the suite stays green on a machine with no
  calendar permission. A Keychain test uses a UUID-namespaced service name so it cannot collide
  with the real entry.
- **Tests never read the clock.** Dates are passed in explicitly — the `[PIPEBOARD-16]` pattern;
  derivations take an explicit `asOf: Date`.
- **A committed fixture store is never regenerated.** `Phase1Store`, `Phase2Store`,
  `Phase3Store`, `Phase4Store`, `Phase4PrepStore` were each written by an older schema and that
  is their entire value. A diff that rewrites one is a **blocker**. Copying one means the
  `.store` plus its `-wal`/`-shm` sidecars together.
- **A test that asserts a computed property nothing forces the body to consume defends
  nothing** (remedy `layout-cap-not-defended-by-render`) — deleting the behaviour left the suite
  green. Assert what is rendered.
- **Behaviour that lives at exactly one call site and no test reaches routes to a `check`**
  (remedy `view-wiring-untested-at-call-site`). A wiring flag a lens must notice by eye should
  be a deterministic gate instead.
- **A `*Tests.swift` file lives in its slice's `src/`**, beside the code it defends — the
  `project.yml` globs route it into the `LadderTests` target.

### The words

`CONTEXT.md` is binding on identifiers, UI copy, and docs alike.

- **Profile** is canonical — never "vault", never "CareerProfile".
- **Achievement** is the domain word; UI copy may say "points", code may not.
- **Trail vocabulary** — waypoint, summit, trail, pack, base camp — is narrative copy only
  (DESIGN.md §9). Never a functional label, never an identifier. The type is `Stage`.
- **`SkillTag`** is the legacy model name behind Tag and is never renamed.
- Tags are stored in curated casing — `"iOS"`, never `"Ios"`.

### The gates

- **Nothing is created or modified under `Ladder/Features/Journey/`** while the phase line in
  CLAUDE.md reads Phase 4. Only the human advances it. Any diff touching that folder is a
  **blocker**.
- **`Ladder.xcodeproj` is generated — a diff that edits it by hand is a finding.** `project.yml`
  is the manifest; new files need `xcodegen generate` and a build.

## Not findings

Report none of these; each is deliberate and already argued.

- The unused `Segment` value type in transcript-import — kept for the model's future consumers,
  and its looking unused is expected.
- Raw colour and font values inside the CV print template (CVExport `decisions/0007`).
- The single `-LadderScratchStore` launch-argument branch in `LadderApp` (ADR 0007) — it only
  ever narrows to a throwaway path.
- The tailor sheet's footer action bar sitting inside the reading measure — ruled deliberate by
  the human on the rendered frames.
- A screen or component missing from the tour or gallery. That is the **visual** lens's finding
  to make (ADR 0008), and it makes it better, having tried to render it.

## How to report

Report only findings anchored to a **changed line** in this change set — not a pre-existing
violation the change did not touch. For each finding give:

- `path:line` — the changed line it anchors to
- **severity** — blocker · major · minor · nit
- **what** — the convention broken, in one line
- **why** — **the rule, quoted or cited by source**, and the concrete harm here
- **fix** — the change that follows the convention
- **route** — `criterion` · `check` · `lens` · `none`

**Prefer `check`.** A house convention that reduces to a path-and-text fact about a change set
belongs in `.speccle/checks/` as a deterministic gate, not in a lens that has to notice it
again next time. Route `lens` only when the rule needs judgement, and `criterion` when the real
gap is that no test claimed the behaviour.

### Write it for a reader who did not write the change

- **Cite, don't opine.** Name the source — "CLAUDE.md → Conventions", "ADR 0005",
  "Tailor `**Traps**`", "remedy `duplicated-layout-constant`". A rule the author can go and read
  ends the argument; "this feels un-idiomatic" starts one.
- **Consequence first.** Open with what it costs, then the rule. Not "CLAUDE.md forbids
  comments that restate the body, and this one…" but "this comment will be wrong the first time
  the guard moves — it restates a condition rather than…".
- **Length follows severity.** A `nit` is a sentence. Only a blocker earns a paragraph.
- **Severity is about the rule's cost, not its age.** A regenerated fixture store or a touched
  `Journey/` folder is a blocker on the first offence; a comment that restates its line is a
  nit however often it recurs.
- An empty report is a valid and common result.
