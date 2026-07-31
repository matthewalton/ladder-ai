# visual lens

**Stance:** every other lens reads the change. This one **looks at it**. Render the UI and
open the PNGs before writing a word — a finding here must come from a picture you actually
saw, never from reasoning about what the code would draw.

## When this lens has work

Only when the change set touches something that draws:

- `Ladder/Features/*/src/Views/**`, `Ladder/Shared/DesignSystem/**`, or `Ladder/App/*.swift`
- a `Palette` / `Typography` accessor, or an asset in `Assets.xcassets`

If the diff touches none of those — a store, a model, a service, a test — **return an empty
report immediately and render nothing.** The build is not free and a refactor below the view
layer has nothing to show.

This lens also needs macOS and Xcode. The CI driver runs on a Linux runner, where
`scripts/snapshots.sh` cannot build: there, report nothing and say the visual lens could not
run. **Never fall back to reading the diff and guessing what it would look like** — that is
the one thing this lens exists not to do, and the local `/review` will do it properly.

## Render, then look

```sh
scripts/snapshots.sh views   # components → .snapshots/, light and dark, ~20s
scripts/snapshots.sh app     # the real app, driven and photographed → .snapshots/ui/, ~40s
scripts/snapshots.sh app stage-sheet tailor   # only those tour sections (list in the script)
```

Run `views` when the change is a component; run `app` when it changes a screen, the shell, or
anything reached by navigating. Run both when unsure. When the change set touches only one or
two screens, name their sections instead of walking everything — but a section run **wipes
`.snapshots/ui/` first**, so what remains afterwards is only what was just rendered. **Then
read the PNGs** — they are images, open them.

Two traps, neither of which is a finding:

- A component that renders **blank** in `views` has hit `ImageRenderer`'s wall, not a bug —
  it draws SwiftUI's own output but leaves `TextField`, `List`/`Form` rows and scrolling
  containers empty, and `TabView` as the unavailable glyph (ADR 0007). Re-check it with `app`.
- The tour photographs a **scratch store**, so screens are empty-state unless the tour seeds
  them. Empty is the state, not a defect.

If a screen the change affects is not in the gallery or the tour, **say so in the report** —
an unrendered screen is an unchecked screen, and silence reads as "looked at, fine".

## How deep

The owning slice's `CLAUDE.md` names the parts of that slice needing eyes — read it and cover
what it names. With nothing named, cover the screens and components the diff touches.

## What to look for

- **Layout** — overlap, clipping, a control pushed off its container, uneven gutters, a row
  that no longer aligns with the rows around it.
- **Text** — truncation with no ellipsis, a label wrapping to a second line that breaks the
  row's rhythm, a heading that lost its hierarchy.
- **Palette and typography** — a colour or face that is not `Palette` / `Typography`, a tone
  that reads wrong against `paper`, a weight that fights DESIGN.md.
- **Dark mode** — compare the pair. Text gone low-contrast, a border vanished into the
  background, a fill that stayed light.
- **State** — the empty state's copy and centring, a loading or error state that lost its
  shape, an indicator row whose affordance label no longer matches what it opens.
- **Against the spec** — the slice's `SPEC.md` and DESIGN.md describe what should be on
  screen. A criterion that is green in tests but invisible on screen is a finding.

## What this lens cannot see

Motion, drag-and-drop, materials, vibrancy, and anything needing a live pointer. Do not guess
at them. Name them in the report as **still needing the human's eyes**, and say which screen —
that list is this lens's other output, and the only honest one for what no PNG shows.

## How to report

Report only findings anchored to a **changed line** in this change set. For each finding give:

- `path:line` — the changed line it anchors to
- **severity** — major · minor · nit
- **what** — what looks wrong, in one plain sentence
- **why** — what the reader sees and why it is wrong: name the snapshot file it is visible in
- **fix** — the change that corrects it
- **route** — `criterion` · `check` · `lens` · `none`

Always close with the human-eyes list above, even when the findings list is empty. An empty
report plus "nothing here needs eyes" is a valid, common result.

### Write it for a reader who did not write the change

- **You saw it or you did not.** Every finding names the PNG it is visible in. A claim you
  cannot point at a file for is a hunch — hold it. A finding that mis-describes what is on
  screen is worse than none: the reader opens the image, sees something else, and stops
  trusting the lens.
- **Consequence first.** Open with what the user sees, in plain words; the cause is the next
  sentence. Not "the frame modifier lacks an alignment, so…" but "the company name sits half
  a row above its role — the card's frame has no alignment, so…".
- **Length follows severity.** A `nit` is a sentence. Only a broken screen earns a paragraph.
