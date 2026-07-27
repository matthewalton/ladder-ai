# 0007 — Tailoring starts from the Applications section

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

The tailor entry lived on the Profile page — but tailoring is not a Profile
activity. The user's model, settled at planning: the Profile holds everything
about you, often more than any one application needs; when applying, you come
to the app with a job description, get a tailored CV, and the application —
with its stored CV — lands on the board and is tracked from there. The
Profile page entry never fit that flow.

## Decision

The Applications shell owns starting a tailored application: a "Tailor a CV"
affordance in the shell toolbar and as the empty state's lead action presents
the Tailor slice's sheet (JD in → tailor run → review → export). The Profile
page's Tailor entry is removed. Export behaviour is untouched — it still
creates the Application with status applied and the CV snapshot attached
([CVEXPORT-1], [CVEXPORT-10]); it simply starts from the board's side.

## Consequences

- The Profile page is purely about curating the Profile; CV import stays its
  only toolbar flow.
- The board has two creation paths side by side: tailor-and-export (with CV)
  and manual add (without, decisions/0004).
- `PipelineRootView` needs the `ProfileStore` to hand the tailor sheet;
  the app shell passes it through.
