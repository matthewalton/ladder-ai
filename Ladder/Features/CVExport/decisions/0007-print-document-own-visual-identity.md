# 0007 — The print document has its own visual identity

Status: accepted (agreed with the human at the plan stage, 2026-07-23)

## Context

The rendered CV goes to recruiters, not Ladder users. The app's trail-map
design system (DESIGN.md) is deliberately the wrong voice for it, and the
CLAUDE.md convention — colors/fonts only via `Palette.swift` /
`Typography.swift`, no raw hex or `.custom` fonts in views — was written for
app UI. The human's reference CV (`Matthew_Alton_CV.pdf`, analysed
2026-07-23) defines the look the export must keep: Inter (four weights) and
Source Serif 4 Bold — both SIL OFL, bundleable — over a steel-blue print
palette (`#1A4D68` headings/rules, `#1F2833` body ink, `#5D6B76` meta grey,
`#C7D6DD` hairlines).

Alternatives considered: a `PrintPalette` in `Shared/DesignSystem/`
(speculative reuse, blurs the trail-map identity with one it rejects), and a
system-wide ADR (ceremony for what is today one document in one slice).

## Decision

The CV template's palette, typefaces, and layout metrics live slice-local in
`CVExport` (a `CVTheme`), with the fonts bundled and registered by this
slice. The print document is exempt from the app-UI palette/typography
convention, mirroring the Summit View exemption; CLAUDE.md records the
exemption with a pointer here.

## Consequences

- `Shared/DesignSystem/` stays purely the app's trail-map identity.
- Raw hex and `.custom` fonts are legal inside the CV template only; app UI
  rules are unchanged.
- A future second print surface (e.g. Summit export) would prompt revisiting
  whether the print identity moves shared — not before.
