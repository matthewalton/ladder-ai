# Tailor

JD → tailored, reviewed outcome: the tailor sheet, the `IntelligenceService` run, result
validation with the repair loop, the side-by-side review. Also the JD scan and the scan-first
flow it feeds — Match review, ranked payload, overlap view, FitMetrics content budget — and
the per-point relevance stats.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Shared/Services/` — the live `AnthropicIntelligenceService` lives there, not here
- `Ladder/Features/CVExport/src/Application.swift` — cv-export owns `Application`; the `Match` model
  this slice persists is in this slice's `src/`
- `Ladder/Features/CVExport/src/Render/CVRenderTests.swift` — cv-export's render tests build a
  `TailorResult` directly, so a change to its validating initialiser's signature reaches them
- `Prompts/tailor.md` and `Prompts/jd-scan.md`

**Needs eyes**

- Match review and the tailor review, at the sheet's width — `scripts/snapshots.sh app tailor`
  records them as `20-match-review` and `21-tailor-review`. The sheet is sized for the CV
  preview, not for these (cv-export decisions/0015), so what the frames answer is whether the
  capped reading measure still reads as a deliberate column and not as content stranded at one
  edge. Each frame's `.txt` beside it carries the measured widths.
- The scan and tailor failure screens — nothing renders them: the tour's fixture service
  answers every prompt, so the flow never enters a failed phase. Stays the human's.
- The three progress states — the tour steps past each one waiting on the screen that follows,
  so no frame catches them. Stays the human's.

**Traps**

- This is the slice that turned live API access on. Tests still never reach the network: the
  live service is tested at its **request-building seam**, the flow with
  `FixtureIntelligenceService`, and the Keychain store is faked behind its protocol
  everywhere except its own round-trip test.
- The repair loop runs **once**. A second failure is a failure, not another retry.

Criteria token: `[TAILOR-n]`
