# 0017 — Relevance stats: four fixed criteria, judged in the tailor request, Swift-averaged, transient

**Status:** accepted (2026-07-27, agreed with the human)

## Context

Ticket #195, deferred from #162: root ADR 0005 reserved per-point LLM-judged
relevance for tailor time but left the shape open — which criteria, whether
they combine into one rank, whether they persist, and which request judges
them.

## Decision

- **Four fixed criteria per selected point** — tech/tooling relevance,
  topic/domain relevance, responsibility/seniority relevance, impact/outcome
  relevance — each an integer 0 to 5. The #162 grill's candidate set,
  adopted unchanged.
- **One overall relevance per point: the unweighted mean of the four,
  computed in Swift.** The model never returns an aggregate, so the
  aggregate can never disagree with the visible sub-scores it derives from.
  Sub-scores stay visible wherever the aggregate shows.
- **Judged in the same tailor request.** The tailor result schema gains the
  stats, `Prompts/tailor.md` version-bumps, and validation failures feed the
  single repair (decisions/0004). No second scoring pass.
- **Transient.** Stats live in the tailor result and die with the flow
  (decisions/0001). Persistence is deliberately deferred to the
  CV-composition record (Baton #164) — nothing here prejudges its shape.
- **Restated hard line (root ADR 0005):** relevance stats never move the
  Match score, and never reorder the payload — [TAILOR-53]'s deterministic
  overlap sort stands.

## Considered options

- *LLM-returned overall score* — could weigh nuance a mean flattens, but is
  not derivable from the sub-scores, so the aggregate could disagree with
  its parts. Rejected for explainability.
- *Separate scoring pass* — decouples judging from selecting and could score
  unselected points, but doubles latency and cost and adds a second failure
  mode; the model already reads every point at selection time. Rejected.
- *Persist per tailor run now* — prejudges #164's shape, needs a schema
  migration, and stores judgments that go stale as the Profile changes.
  Rejected.

## Consequences

- The tailor review shows the deterministic overlap view and the judged
  relevance stats side by side, never merged into one figure.
- The tailor result schema and `Prompts/tailor.md` version-bump; the canned
  fixture results grow stats for every selected point.
- When #164 lands, stats join whatever composition record it defines — not
  before.
