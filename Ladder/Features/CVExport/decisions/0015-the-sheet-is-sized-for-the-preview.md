# 0015 — The tailor sheet is sized for the preview, and the earlier phases hold their measure

Status: accepted (agreed with the human at the plan stage, 2026-07-31)

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
handing them 1000 would give them line lengths nothing else in the app has.

## Decision

**The sheet's floor is sized for the phase that needs the most room, and the
phases that do not need it decline it.**

- The sheet's floor rises to 1000 × 640.
- The single-column phases — Match review, tailor review, and the progress and
  failure states — cap their content at a readable measure of 720pt and centre
  it. They keep the line lengths they had; the extra width becomes margin.
- The preview phase alone spends the full width. Its page pane opens at about
  620pt, so the A4 page renders at full scale.

The split divider stays useful rather than becoming decorative: the page pane
floors at 520 and the editor at 340, leaving about 140pt to hand between them.
Dragging the page to its floor costs about 0.87 scale — readable, just not
print-exact.

## Consequences

- The guarantee the criteria carry is **at the opening position**: the preview
  opens with the page at full scale. A user who drags the divider is choosing
  a smaller page, which is different from being given one.
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
- Sheets elsewhere in the app are untouched. This decision is about the tailor
  sheet, which is the only one hosting a phase with a fixed-aspect document in
  it.
