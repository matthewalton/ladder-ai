# Stage 3 handoff — wire Tessl code review into GitHub Actions

Pick this up in a fresh session. Stages 1–2 are done and committed; this is the
CI step that runs the reviewers on every PR and posts inline comments.

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
