# Tailor

JD → tailored, reviewed outcome: the tailor sheet, the `IntelligenceService` run, result
validation with the repair loop, the side-by-side review. Also the JD scan and the scan-first
flow it feeds — Match review, ranked payload, overlap view, FitMetrics content budget — and
the per-point relevance stats.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Shared/Services/` — the live `AnthropicIntelligenceService` lives there, not here
- `Ladder/CVExport/src/Application.swift` — cv-export owns `Application`; the `Match` model
  this slice persists is in this slice's `src/`
- `Prompts/tailor.md` and `Prompts/jd-scan.md`

**Traps**

- This is the slice that turned live API access on. Tests still never reach the network: the
  live service is tested at its **request-building seam**, the flow with
  `FixtureIntelligenceService`, and the Keychain store is faked behind its protocol
  everywhere except its own round-trip test.
- The repair loop runs **once**. A second failure is a failure, not another retry.

Criteria token: `[TAILOR-n]`
