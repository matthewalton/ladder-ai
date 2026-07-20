# Ladder — Visual Design System

> Companion to `ARCHITECTURE.md` §5. This is the visual source of truth: palette, type, spacing, components, motion, and the full spec for the journey celebration view. Written for Claude Code — token values are given as SwiftUI code where useful.

---

## 1. Design concept: **The Trail Map**

Ladder's world is the climb: applications are routes, stages are waypoints, the offer is the summit. The visual language borrows from **hand-annotated trail maps and national-park signage** — paper textures, contour lines, trail blazes, carved-wood warmth — rather than from SaaS dashboards.

Why this works for the brief:
- It's *friendly and human* without being cutesy. Trail signage is warm but calm and legible — exactly the register for an app people open while stressed.
- It gives every structural element a native metaphor: stages are **waypoints**, the pipeline board is the **trailhead**, prep packs are the **route notes**, a rejection is a **closed trail** (not a red X), the celebration is the **summit**.
- The everyday UI stays quiet (native macOS, mostly system materials); the trail identity concentrates in accents, iconography, and the journey view — restraint everywhere, boldness in one place.

Explicitly avoid: corporate blue dashboards, dense data grids, confetti, gradients-on-everything, terracotta-on-cream "AI default" styling, and anything that reads as an ATS.

---

## 2. Palette

Two schemes: **Daylight** (light) and **Night Hike** (dark). Both are pine-anchored — the neutral tones lean green rather than gray, which is the palette's quiet signature. Follow the system appearance; never force light.

### Daylight
| Token | Hex | Use |
|---|---|---|
| `paper` | `#F6F5F0` | Window/background. Cool limestone, *not* warm cream. |
| `paperRaised` | `#FDFCF9` | Cards, inspector panels |
| `ink` | `#26332C` | Primary text. Pine-slate, never pure black. |
| `inkSoft` | `#5C6B62` | Secondary text, captions |
| `pine` | `#2F5D46` | Primary brand. Buttons, active states, links, the drawn trail path. |
| `pineTint` | `#E3EDE6` | Selected rows, tag chips, subtle fills |
| `summitGold` | `#D99A2B` | **Achievement only**: offers, passed stages, the summit flag, streaks. Scarce by design — if gold appears more than twice on a screen, something is wrong. |
| `skyline` | `#5F8496` | Informational: scheduled dates, calendar links, in-progress hints |
| `clay` | `#A6685F` | Gentle warnings, gaps flagged in fit reports. Muted — never alarm-red. |
| `mist` | `#D9DDD6` | Hairline dividers, contour lines at low opacity |

### Night Hike
| Token | Hex | Use |
|---|---|---|
| `paper` | `#151F1A` | Background. Pine-black, not gray-black. |
| `paperRaised` | `#1E2B24` | Cards, panels |
| `ink` | `#E7ECE6` | Primary text |
| `inkSoft` | `#93A399` | Secondary text |
| `pine` | `#7FB894` | Primary (lightened for contrast) |
| `pineTint` | `#24382E` | Fills |
| `summitGold` | `#E5B45A` | Achievement |
| `skyline` | `#8FB2C2` | Informational |
| `clay` | `#C08B82` | Warnings |
| `mist` | `#2C3A32` | Dividers, contours |

```swift
// Shared/DesignSystem/Palette.swift — define via Color assets with
// light/dark variants; expose as:
extension Color {
    static let paper = Color("Paper")
    static let paperRaised = Color("PaperRaised")
    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    static let pine = Color("Pine")
    static let pineTint = Color("PineTint")
    static let summitGold = Color("SummitGold")
    static let skyline = Color("Skyline")
    static let clay = Color("Clay")
    static let mist = Color("Mist")
}
```

Contrast: all text/background pairs above meet WCAG AA at their intended sizes; verify any new pairing before use. `summitGold` on `paper` is for icons/large display only, never body text.

### Stage-kind accent mapping
Stages are color-coded *subtly* (icon + chip tint only, never full-card fills):
screen/recruiter → `skyline` · technical/take-home → `pine` · behavioral/final → `clay`→`pine` neutral · offer → `summitGold` · rejected/withdrawn → `mist` with `inkSoft` text ("closed trail" — dignified, desaturated, never red).

---

## 3. Typography

| Role | Face | Notes |
|---|---|---|
| UI (everything interactive) | **SF Pro** via system text styles | Non-negotiable for native macOS feel. Use Dynamic Type styles (`.body`, `.headline`, `.caption`) — never hardcoded sizes for UI chrome. |
| Narrative & celebration | **New York** (Apple system serif), `.serif` design | The storybook voice. Used for: journey view waypoint notes, debrief narrative summaries, the fit-report prose, empty-state encouragement lines. Ships with macOS — zero licensing friction. |
| Data & timestamps | SF Pro with monospaced digits (`.monospacedDigit()`) | Elapsed times, dates on the timeline |

The serif/sans split *is* the typographic identity: **SF Pro = the tool, New York = the story**. Any text that narrates the user's journey gets the serif; any text that operates the app gets the sans. Hold this line strictly — it's what keeps the warmth from leaking into the chrome or the chrome from deadening the story.

Type scale (celebration view only, fixed sizes acceptable there):
- Summit title: New York, 34pt semibold
- Waypoint headings: New York, 20pt medium
- Waypoint notes: New York, 15pt regular, `inkSoft`
- Trail metadata (dates, elapsed): SF Pro 12pt medium, monospaced digits, tracking +0.4, uppercase eyebrows

---

## 4. Layout, spacing, shape

- 8pt grid; 4pt permitted inside dense components (chips, timeline metadata).
- Corner radius: 10pt continuous for cards, 6pt for chips/controls. One radius family, no mixing.
- Standard macOS three-pane where it fits: sidebar (Applications) / content (Stage timeline or board) / inspector (details, prep pack). Use `NavigationSplitView` and native toolbars — the app should feel like it shipped with the OS.
- Hairlines are `mist` at 1pt. No drop shadows on cards in Daylight; use `paperRaised` + hairline instead. Night Hike may use very soft shadows for depth.
- **Contour motif:** faint topographic contour lines (`mist`, ~40% opacity) appear as background texture in exactly two places — the journey celebration view and the empty states. Nowhere else. This is texture as reward, not wallpaper.

---

## 5. Iconography

- SF Symbols throughout for standard actions.
- One small custom set: **trail blazes** — the stage-kind markers. Simple geometric badges inspired by painted trail markers: circle (screen), diamond (technical), square (behavioral), double-chevron (final), flag (offer). Drawn as SwiftUI `Shape`s so they scale and tint freely. These appear on the board, the timeline, and as the waypoints in the journey view — a single icon language from tracking through to celebration.
- App icon (decided 2026-07): the **trail badge** — the double-chevron blaze stacked into three ladder rungs, cut out of a solid `pine` plaque in `paper`, top rung `summitGold`. (This inverts the original pine-on-paper sketch: the plaque ground won the logo round.) Flat, friendly, confident — no gradients, no glass. Master SVGs live in `docs/brand/`; the menu-bar template icon is the rungs alone in `currentColor`.

---

## 6. Component notes

**Menu bar extra (Capture):** monochrome template icon (blaze outline); recording state = filled blaze pulsing gently in system red (recording indicators must use conventional red for honesty — the one place trail colors yield to convention). Dropdown: level meters as two thin `pine` bars (you/them), elapsed time in monospaced digits.

**Pipeline board:** columns by `ApplicationStatus`. Cards: company + role in SF Pro, next waypoint chip, quiet elapsed-time footer ("12 days on trail"). No progress bars, no percentages.

**Stage timeline (per application):** vertical line in `pine`, blazes as nodes, future stages hollow, completed filled, elapsed-time segments labeled between nodes. This is the everyday, utilitarian sibling of the celebration view — same skeleton, no decoration, so the celebration reads as a *transformation* of something familiar.

**Fit report:** strengths as `pineTint` chips, gaps as `clay` chips, prose summary in New York. Never a numeric score — the visual language is "matched terrain / unfamiliar terrain".

**Empty states:** contour background, one New York line of encouragement, one clear action. E.g. Profile empty: "Every climb starts with a pack. Add your first role." + [Import CV].

**Rejection state:** the application card desaturates to `mist`/`inkSoft`, blaze becomes an outlined marker, copy: "This trail's closed — everything you packed goes with you." Offer a one-click "harvest": pull any debrief drills into the next active application's prep context.

---

## 7. The Summit View (journey celebration) — full spec

**Trigger:** Application status → `.offer`. Full-window takeover (dismissible), plus permanently accessible from the application afterward.

**Composition (vertical scroll, bottom-to-top narrative):**
1. **Base camp** (bottom): applied date, the tailored CV snapshot as a small "permit" card.
2. **The path:** a single hand-drawn-feeling line (variable-width stroke, slight waver — `pine`) climbing through contour-line terrain. Terrain bands subtly shift tone with altitude (paper → pineTint washes).
3. **Waypoints:** each Stage as its trail blaze, with: stage name (New York 20pt), date + elapsed-from-previous (mono eyebrow), and *one* line drawn from its debrief — the best moment, not a summary ("Held your ground on the caching trade-off").
4. **Summit** (top): flag in `summitGold`, offer date, total journey stats set small and proud: days on trail, stages cleared, questions faced. Headline in New York 34pt — generated by journey synthesis, personal, e.g. "Forty-one days. Five waypoints. One summit."
5. **Share/export:** renders to a single tall image or PDF via `ImageRenderer`. Export includes an anonymized variant (company name → "the summit") for public sharing.

**Motion (the one orchestrated moment in the app):** on first reveal, the view starts at base camp and the path *draws itself upward* (`trim` animation on the path shape, spring-eased, ~4s total), each waypoint's blaze filling with a soft spring pop as the line reaches it, summit flag unfurling last with a single slow `summitGold` shimmer. **No confetti.** With Reduce Motion: crossfade to the completed scene, no draw-on.

**Tone check:** this must feel like a keepsake page from an expedition journal — earned, quiet pride — not a gamified victory screen. If a design choice would look at home in a fitness app's streak celebration, cut it.

---

## 8. Motion (everywhere else)

- Default: subtle, spring-based (`.snappy` / `.smooth`), 150–250ms.
- Blazes fill with a small spring when a stage completes — the everyday echo of the summit animation.
- Recording pulse: 2s ease-in-out loop, opacity only.
- Respect `accessibilityReduceMotion` globally: replace movement with crossfades.
- Nothing animates without a state change. No ambient/idle animation outside the Summit View's one-time reveal.

---

## 9. Voice in the interface

Sentence case everywhere. Plain verbs on controls ("Tailor CV", "Record", "Generate prep"). The trail vocabulary appears in *narrative* text (New York contexts) and stays out of *functional* text (SF Pro contexts) — a button never says "Blaze onward", a timeline note may say "12 days on trail". Errors are direct and unapologetic about the fix ("Calendar access is off. Turn it on in System Settings → Privacy to link interviews."). Encouragement is specific, never generic hype — it references the user's actual vault and journey.

---

## 10. Build checklist for Claude Code

- [ ] Color assets with light/dark variants matching §2 exactly; `Palette.swift` accessors
- [ ] `Typography.swift`: helpers `Font.trailNarrative(_:)` (New York) and standard system styles; lint rule of thumb — no `.custom` fonts, no hardcoded UI sizes outside Summit View
- [ ] `Blaze` shape set (circle/diamond/square/chevrons/flag) with `filled`/`hollow`/`closed` states
- [ ] `ContourBackground` view (Canvas-drawn, cached, opacity-parameterized) used only in Summit View + empty states
- [ ] `TrailPath` shape with `trim`-based draw-on animation + Reduce Motion fallback
- [ ] Snapshot tests for both appearances of: board card, timeline, fit report, Summit View
- [ ] Contrast audit script over palette pairs
