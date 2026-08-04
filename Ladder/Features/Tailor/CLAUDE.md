# Tailor

JD → tailored, reviewed outcome: the tailor sheet, the `IntelligenceService` run, result
validation with the repair loop, the side-by-side review. Also the JD scan and the scan-first
flow it feeds — Match review, ranked payload, overlap view, FitMetrics content budget — and
the per-point relevance stats.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Shared/Services/` — the live `AnthropicIntelligenceService` lives there, not here.
  `IntelligenceService.swift` holds the seam itself: the protocol, its streaming default, and
  `IntelligenceRequest`. Both are shared ground — nine slices call through them (ADR 0009)
- `Ladder/Features/CVImport/SPEC.md` — [CVIMPORT-19]'s truncation guard is this slice's stop-reason
  handling seen from import; changing where that signal is read reaches its body
- A new `LiveServiceError` case needs its user-facing copy on the case itself, in
  `LiveServiceError.detail` — the switch there is exhaustive, so a case without copy does not
  compile (decisions/0021). Stores call `AnthropicIntelligenceService.failureDetail(for:)` and
  write no copy of their own; the slices that do so are found by that call, not by a list here
- `Ladder/Features/CVExport/src/Application.swift` — cv-export owns `Application`; the `Match` model
  this slice persists is in this slice's `src/`
- `Ladder/Features/CVExport/src/Render/CVRenderTests.swift` — cv-export's render tests build a
  `TailorResult` directly, so a change to its validating initialiser's signature reaches them
- `Prompts/tailor.md` and `Prompts/jd-scan.md`
- The machinery that photographs this slice's dead ends (ADR 0008) — `LadderTests/SnapshotGallery.swift`
  renders `TailorProgressView` for each of its `Step` cases, and `LadderUITests/ScreenTour.swift`
  plus its `tailor-failure` case in `scripts/snapshots.sh` drive the two failure arms. Reaching
  those arms is what `TourSeed.plantBare` and `-LadderTourNoKey` exist for; changing the phase
  machine's refusals reaches all of them.

**Needs eyes**

- Match review and the tailor review, at the sheet's width — `scripts/snapshots.sh app tailor`
  records them as `20-match-review` and `21-tailor-review`. The sheet is sized for the CV
  preview, not for these (cv-export decisions/0015), so what the frames answer is whether the
  capped reading measure still reads as a deliberate column and not as content stranded at one
  edge. Each frame's `.txt` beside it carries the measured widths.
- The two refusal screens — `scripts/snapshots.sh app tailor-failure` records them as
  `26-tailor-failed-nothing-to-select` (the retry arm, on a Profile with nothing to select
  from) and `27-scan-failed-needs-key` (the `SettingsLink` arm, on an empty key). What the
  frames answer is whether a single centred line still reads as placed rather than adrift in
  a sheet sized for the CV preview.
- The two live-failure arms of the same sheet — the tailor request and the JD scan, each on
  a service that refuses. Neither had ever been photographed: the section above reaches the
  refusals, which never touch `LiveServiceError`, so the sheet's Detail and Advice went
  unseen while three other slices' equivalents were covered. What the frames answer is
  whether two sentences — the Detail mid-parentheses, then the Advice after it — still read
  as one centred block at this sheet's width, where the same copy has the most room and so
  wraps least like the rail's.
- The three progress states — `scripts/snapshots.sh views` writes them as
  `tailor-progress-scanning`, `-tailoring` and `-composing`, light and dark. The yellow glyph
  above the text is `ImageRenderer`'s stand-in for `ProgressView`, which is AppKit-backed and
  never draws headlessly; what the frames answer is where the centred text lands, so a
  regression to leading alignment shows up as text stranded at the measure's left edge. The
  spinner itself stays the human's.

**Traps**

- This is the slice that turned live API access on. Tests still never reach the network: the
  live service is tested at its **request-building seam**, the flow with
  `FixtureIntelligenceService`, and the Keychain store is faked behind its protocol
  everywhere except its own round-trip test. The stream reader is the same rule one layer
  down — it is fed **recorded event bytes**, never a connection, which is also how a reply
  that is cut off, reports an error, or simply stops gets exercised on purpose.
- A new `IntelligenceService` conformer needs no streaming code: the protocol extension's
  default returns the whole result (ADR 0009). Only the live service overrides it.
- The repair loop runs **once**. A second failure is a failure, not another retry.

Criteria token: `[TAILOR-n]`
