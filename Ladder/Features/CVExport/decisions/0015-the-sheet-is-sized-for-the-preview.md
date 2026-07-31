# 0015 — The tailor sheet is sized for the preview, and the earlier phases hold their measure

Status: accepted (agreed with the human at the plan stage, 2026-07-31; the
numbers corrected at implementation the same day — see **Correction**)

## Context

The CV preview is presented inside the tailor sheet, which declares a single
`.frame(minWidth:minHeight:)` for all four of its phases. A sheet is not
user-resizable, so that floor is also its ceiling: the sheet opened at exactly
780 × 560, the page pane at its declared 420 minimum, and the A4 page rendered
413.9 wide — about 0.70 scale, with body text landing at ~8pt line boxes.
`PDFView.autoScales` was doing the right thing; the pane was too narrow to
scale into. The `HSplitView` divider only trades width between the two panes,
so no gesture could make the rendered CV bigger.

The defect survived construction because `CVPreviewView`'s `#Preview` sets a
1000 × 700 frame. The view was only ever wrong at the size it actually ships
at.

Widening the sheet is the only fix available, and one sheet serves four
phases. Match review and tailor review are single-column and read well at 780;
handing them the preview's width would give them line lengths nothing else in
the app has.

## Decision

**The sheet's floor is sized for the phase that needs the most room, and the
phases that do not need it decline it.**

- The sheet's floor rises to 1100 × 640.
- The single-column phases — Match review, tailor review, and the progress and
  failure states — cap their content at a readable measure of 720pt and centre
  it. They keep the line lengths they had; the extra width becomes margin.
- The preview phase alone spends the full width. Its page pane opens at 620pt,
  so the A4 page renders at full scale.

The split divider stays useful rather than becoming decorative: the page pane
floors at 620 and the editor at 340, leaving about 140pt to hand between them.

## Correction (2026-07-31, at implementation)

This decision first set the sheet at 1000 × 640 and the page pane's floor at
520, expecting `HSplitView` to open the pane at 620 — the sheet's width less
the editor's 380 ideal — and to let a drag take it down to 520, at about 0.87
scale.

Measured against the running app, `HSplitView` does no such thing. It opens the
**leading** pane at exactly its minimum and hands the trailing pane every
remaining point, ignoring `idealWidth` on either. The page pane therefore
opened at 520 and the page rendered 512.4 wide, at 0.86 scale: the original
defect moved, not fixed.

So the page pane's floor **is** the width it opens at, and it has to clear A4 on
its own. It rises to 620, and the sheet to 1100 so the ~140pt of play between
the panes survives. Both properties this decision reasoned about hold; only its
model of the framework was wrong.

## Consequences

- The guarantee the criteria carry is at the opening position, and it now holds
  everywhere: because the page pane cannot be dragged below its own floor, the
  page can never be shown below full scale. The trade this decision originally
  accepted — a readable-but-not-print-exact 0.87 — is not reachable.
- What the divider trades is the editor's width against a page already at full
  scale. Dragging is how the user gets a roomier editing surface, which is why
  the sheet keeps slack beyond the two floors rather than sitting at 960.
- The page pane's floor is expressed against `CVMetrics.pageSize.width`, not as
  a bare number, so the relationship that was violated is the thing under test.
  Changing either the sheet's floor or a pane's minimum breaks the test that
  states A4 fits.
- The sheet's metrics live in this slice, beside the page size they are derived
  from. `TailorView` reads them — a code-level touch in the tailor slice, on the
  precedent [CVEXPORT-4] already set. **No TAILOR criterion changes**: every
  review screen still shows exactly what it promised, at the measure it already
  had.
- The 640 height floor is the smaller half of the change and buys the preview's
  footer and the editor's first sections room to breathe. No phase needed more
  than 560 before; none is harmed by more.
- `CVPreviewView`'s `#Preview` is pinned to the sheet's floor. A roomier canvas
  is what hid the defect through construction, and a canvas that lies about the
  shipping size is worth nothing.
- Sheets elsewhere in the app are untouched. This decision is about the tailor
  flow sheet, which is the only one hosting a phase with a fixed-aspect document
  in it.
