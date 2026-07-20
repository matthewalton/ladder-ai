# Ladder brand mark — the trail badge

The logo is the app's double-chevron trail blaze stacked into three ladder
rungs, cut out of a solid pine plaque; the top rung is `summitGold` (the
summit stays scarce, per DESIGN.md §2). Flat, friendly, confident — no
gradients, no glass.

Files:

- `ladder-mark.svg` — Daylight (canonical)
- `ladder-mark-night.svg` — Night Hike
- `ladder-mark-template.svg` — rungs only, `currentColor`, for monochrome
  template contexts (menu bar extra, DESIGN.md §6)

Geometry (120-unit viewBox): plaque 8,8 → 104×104, corner radius 26.
Rungs span x 34–86, apex at 60; baselines y 91 / 68 / 45, apex rise 16,
stroke 9 with round caps and joins. Keep colors on palette tokens only.

The app icon (`Ladder/Shared/DesignSystem/Assets.xcassets/AppIcon.appiconset`)
is the same mark drawn full-bleed — the pine plaque fills the canvas and
macOS applies its own icon mask. PNGs are rendered by a throwaway
CoreGraphics script from the geometry above; regenerate at the same
coordinates (×1024/104) if the mark changes.
