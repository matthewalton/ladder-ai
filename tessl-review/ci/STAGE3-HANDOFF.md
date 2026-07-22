# Stage 3 handoff — wire Tessl code review into GitHub Actions

Pick this up in a fresh session. Stages 1–2 are done and committed; this is the
CI step that runs the reviewers on every PR and posts inline comments.

## STATUS (2026-07-22): both TODOs resolved — workflow authored, awaiting secrets + a test PR

The two open questions below were resolved authoritatively from the CLI's own
embedded `change-review` skill (`~/.local/share/tessl/embedded-plugins/0.92.0/
harness-engineering/skills/change-review/`), so no guessing and no billed local
review run were needed:

- **TODO(1) — installer:** the official CI install is the reusable action
  `uses: tesslio/setup-tessl@v2` (with `token: ${{ secrets.TESSL_TOKEN }}`), NOT
  a `curl | sh` script. The guessed installer is gone.
- **TODO(2) — field mapping:** the real `--json` shape is
  `summary.{overview,warnings,unplacedFindings}`, `comments[]`
  (`{path,line,side,body,startLine?,startSide?}`), and
  `metadata.{headSha,skills}` — the draft's `.summary` / `.inlineComments[]`
  were wrong. Publishing now uses the CLI's hardened reference publisher.

Live artifacts (replacing the old parked `tessl-review/ci/tessl-review.yml` draft,
now deleted):

- `.github/workflows/tessl-review.yml` — canonical change-review workflow,
  adapted to Ladder: all 5 vendored `tessl/code-review` lenses + the local
  `tessl-review/skills/review-ladder-conventions` lens, `--base origin/main`,
  `--model anthropic/claude-sonnet-4-5`, `REVIEW_ACTION: comment`. Adds fork-PR
  rejection, trusted-vs-reviewed code separation (`_workflow` vs `_pr`), and a
  one-automatic-review-per-PR policy the old draft lacked.
- `.github/change-review/publish-review.mjs` — hardened publisher; one
  `pulls.createReview` call, degrades unplaced findings into the body, validates
  each inline comment locally.

Remaining to go live (human): add the two repo secrets, then open a test PR (see
"Definition of done" below). Note on `ANTHROPIC_API_KEY`: it is wired into the
run step to match the local setup, but `setup-tessl` + `TESSL_TOKEN` may already
route the model through Tessl's gateway — the test PR will confirm whether the
Anthropic key is actually required.

---

## Original handoff (context)

## What already exists (do not redo)

- **Vendored built-in lenses** committed under `.tessl/plugins/tessl/code-review/`:
  `review-code-legibility`, `review-test-risk`, `review-contract-boundaries`,
  `review-security-risks`, `review-local-precedent`.
- **Custom Ladder lens** at `tessl-review/skills/review-ladder-conventions/SKILL.md`
  (plugin `malton/ladder-review`, workspace `malton`). Enforces CLAUDE.md rules.
  Validated: 0 false-positives on clean code, 8/8 on deliberate breaches.
- `tessl.json` is `mode: vendored` with the `tessl/code-review` dependency.
- CLI verified locally: `tessl` v0.92.0, model `anthropic/claude-sonnet-4-5`.
- Setup lives on branch `chore/tessl-review-setup` (commit `bdd02d3`).

## Decisions already made

- **Model:** `anthropic/claude-sonnet-4-5` (Anthropic, not the openai/gpt-5.5 default).
- **Vendored** delivery: reviewers are committed, so CI needs no registry install of them.
- **Cadence:** one automatic review per PR, plus a gated `@tessl-change-review`
  comment re-run restricted to OWNER/MEMBER/COLLABORATOR.

## The draft

`tessl-review/ci/tessl-review.yml` is a structurally complete draft, deliberately
NOT under `.github/workflows/` so it can't fire while incomplete. The review step
(skills, `--base`, `--model`, `--json --output`) is final. Two things need
confirming before it goes live:

### TODO(1) — CLI install for CI
The local box used a "native" install to `~/.local/bin/tessl`. Confirm the
documented CI installer at https://docs.tessl.io (the draft guesses
`curl -fsSL https://get.tessl.io/install.sh | sh` — VERIFY the URL/flag, or pin a
released binary). Alternatively check whether Tessl now ships a reusable GitHub
Action (`uses: tessl-io/...`) — as of this writing the docs described a raw
workflow, no official action. The `tessl-leo/tessl-workflow-installer` registry
skill, or `tessl agent` with "set up a code review for every new PR", can
scaffold this if you'd rather generate than hand-write.

### TODO(2) — publisher field mapping
`tessl change review` emits structured data but never posts to GitHub — a
separate step does. Run one `--json` review locally and inspect the shape
(summary text + inline comments; locally they render as
`path:line (SIDE) body`). Map those exact field names onto GitHub's
"Create a review" API (`POST /repos/{owner}/{repo}/pulls/{n}/reviews` with
`body`, `event`, `comments[].{path,line,side,body}`). The draft's `jq` uses
plausible names (`.summary`, `.inlineComments[]`) that MUST be checked against
real output. Note the CLI demotes findings outside a changed hunk into the
summary as "unplaced findings" — the publisher should surface those too.

## Secrets to add to the repo (Settings → Secrets and variables → Actions)

- `TESSL_TOKEN` — Tessl auth for CI. Create with `tessl api-key create`.
- `ANTHROPIC_API_KEY` — same key used locally (currently in `~/.zshrc`).
- `GITHUB_TOKEN` — auto-provided; no action needed.

## Definition of done

1. TODO(1) and TODO(2) resolved and verified.
2. `tessl-review/ci/tessl-review.yml` moved to `.github/workflows/tessl-review.yml`.
3. Repo secrets added.
4. Open a test PR (this very branch is a good candidate) and confirm one review
   posts with inline comments on the right lines.
5. Once trusted, consider Stage 4 (`tessl change risk init`) and Stage 5
   (`tessl change verify`).

## Local run command (reference)

```bash
tessl change review run \
  --skill tessl/code-review#review-code-legibility \
  --skill tessl/code-review#review-test-risk \
  --skill tessl/code-review#review-security-risks \
  --skill tessl-review/skills/review-ladder-conventions \
  --base origin/main --model anthropic/claude-sonnet-4-5 --json --output review.json
```
(Needs `ANTHROPIC_API_KEY`; local shells load it from `~/.zshrc` — non-interactive
shells need `source ~/.zshrc` first.)
