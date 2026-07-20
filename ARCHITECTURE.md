# Ladder — Architecture & Product Spec

> Working title: **Ladder**. macOS-native, all-in-one interview companion: career profile → tailored applications → pipeline tracking → interview capture → AI debrief & prep → journey retrospective.

This document is the source of truth for what to build and why. It is written for an agentic coding workflow (Claude Code). Each module lists its acceptance criteria; build in the phase order given.

---

## 1. Product thesis

Job hunting tooling is fragmented: CV edits in ChatGPT, tracking in a spreadsheet, meeting notes in Granola, prep in scattered docs. Ladder unifies the loop, and the loop compounds:

```
Profile (master career history)
      │ tailors
      ▼
Application ──► Stage ──► Stage ──► ... ──► Offer
                 │  ▲
       capture   │  │  prep pack informed by
       + debrief ▼  │  profile + all prior debriefs
              Transcript ──► Debrief
```

The differentiator vs Granola/Teal/etc: the intelligence layer **knows the user's full background**. A debrief can say "you gave the weak version of your X story — the stronger example is on file" because the Profile is the persistent asset everything reads from. (Exactly one Profile exists — the tailor flow is the persona mechanism; see CONTEXT.md.)

### Non-goals (v1)
- No iOS/iPadOS target (macOS only; capture engine requires it anyway)
- No cloud sync, no accounts, no server. Local-first. BYO Anthropic API key.
- No Glassdoor/community-data scraping (ToS risk; revisit later)
- No numeric "probability of offer" scores — debriefs are evidence-based, never speculative percentages

---

## 2. Tech stack

| Concern | Choice | Notes |
|---|---|---|
| UI | SwiftUI, macOS 26 only (ADR 0001) | Menu bar extra + main window |
| Persistence | SwiftData | Local store; schema below |
| Calendar | EventKit | Read-only calendar access |
| Mic capture | AVAudioEngine | User's own voice channel |
| System audio | ScreenCaptureKit audio capture; Core Audio process taps (`kAudioTapAPI`) where per-app capture is preferable | Interviewer channel; no bot joins the call |
| Transcription | On-device only: `SpeechAnalyzer`/`SpeechTranscriber` (no third-party fallback needed on 26 — ADR 0001) | Audio never leaves the machine |
| LLM reasoning | Anthropic Messages API, BYO key stored in Keychain | Tailoring, debrief, prep-pack, journey synthesis |
| PDF output | `ImageRenderer` for v1; Typst pipeline as a later upgrade for typographic control | |
| Distribution | Notarized direct download + Homebrew cask | **Not** Mac App Store (sandbox blocks system-audio capture) |

### Privacy posture (hard requirements)
- Raw audio: never persisted beyond the session unless the user opts in; never uploaded anywhere.
- Transcripts: stored locally; sent to the Anthropic API only when the user triggers an analysis action.
- API key: Keychain, never in UserDefaults or on disk.
- A visible recording indicator whenever capture is live. First-run consent screen explains local processing and reminds the user to follow local recording-consent norms.

---

## 3. Data model (SwiftData)

```swift
@Model final class Profile {
    var name: String
    var headline: String
    var contact: ContactInfo          // struct, Codable
    var roles: [Role]                 // cascade
    var education: [Education]
    var projects: [Project]
    var skills: [SkillTag]
    var updatedAt: Date
}

@Model final class Role {
    var company: String
    var title: String
    var start: Date
    var end: Date?                    // nil = current
    var achievements: [Achievement]   // cascade
}

// The atomic unit of the Profile. Tailoring selects + rephrases these,
// it never free-writes career history.
@Model final class Achievement {
    var text: String                  // canonical, user-owned wording
    var skills: [SkillTag]
    var impactMetric: String?         // "reduced build time 40%"
    var tech: [String]
    var strengthNotes: String?        // user's own context / STAR expansion
}

@Model final class Application {
    var company: String
    var roleTitle: String
    var jobDescription: String
    var source: String?               // referral, LinkedIn, direct…
    var status: ApplicationStatus     // .draft, .applied, .active, .offer, .rejected, .withdrawn
    var appliedAt: Date?
    var cvSnapshot: Data?             // exact PDF sent — immutable record
    var cvSelectionRationale: String? // LLM's stated reasoning, for transparency
    var stages: [Stage]               // cascade, ordered
    var notes: String
}

@Model final class Stage {
    var kind: StageKind               // .screen, .recruiter, .technical, .systemDesign, .takeHome, .behavioral, .final, .offer, .other(String)
    var scheduledAt: Date?
    var calendarEventID: String?      // EventKit link
    var meetingURL: URL?
    var prepContext: String           // freeform: recruiter emails, task briefs, anything pasted in
    var prepPack: PrepPack?           // generated
    var transcript: Transcript?
    var debrief: Debrief?
    var outcome: StageOutcome         // .pending, .passed, .failed, .noResponse
    var heardBackAt: Date?
}

@Model final class Transcript {
    var recordedAt: Date
    var durationSec: Int
    var segments: [Segment]           // struct: speaker (.me/.them), text, tStart, tEnd
    var sourceApp: String?            // "zoom.us", "Google Meet"…
}

@Model final class Debrief {
    var generatedAt: Date
    var questionsAsked: [QAItem]      // question, answerSummary, quality (.strong/.adequate/.weak), missedAmmo: [Achievement.id]
    var themes: [String]              // what they probed on
    var signals: [String]             // follow-up cues, interviewer reactions in transcript
    var drills: [String]              // concrete practice suggestions
}

@Model final class PrepPack {
    var generatedAt: Date
    var likelyQuestions: [String]
    var talkingPoints: [String]       // mapped to Achievement ids
    var mockTasks: [MockTask]?        // for technical stages
    var companyBrief: String?         // from JD + user-pasted context only (no scraping)
}
```

Key invariants:
- `cvSnapshot` is written once at submit time and never mutated — the historical record must be exact.
- `Achievement.text` is user-owned canon; the LLM proposes rephrasings per-application but never edits the Profile silently.
- Every Stage timestamp (`scheduledAt`, `heardBackAt`) feeds the journey view; capture them opportunistically (calendar sync, email-paste parsing in `prepContext`).

---

## 4. Modules & build phases

### Phase 1 — Profile + Tailor  *(pure SwiftUI + API; ship first, immediately useful)*
1. **Import**: drop a PDF/docx CV → parse → propose Achievement graph → mandatory human review/edit screen before save. (PDFKit for text extraction; LLM structures it.)
2. **Profile editor**: browse/edit roles & achievements; tag skills; add strength notes.
3. **Tailor flow**: paste JD → LLM selects best-fit achievements, proposes per-application rephrasing, flags gaps ("JD wants Kubernetes; nothing in profile") → side-by-side review → render PDF.
4. **Fit report**: per-JD strengths/weaknesses summary derived from the selection step (this replaces vague "CV stats" — it's grounded in the actual matching).

*Accept:* import → tailored PDF round-trip in under 5 minutes; snapshot stored on Application.

### Phase 2 — Pipeline Tracker
1. CRUD for Applications/Stages; kanban-ish board by status (reuse Baton patterns where sensible).
2. **EventKit sync**: scan upcoming events for meeting URLs (Zoom/Meet/Teams regex on location+notes); match to Applications by company name / attendee domain; offer to create/link a Stage. Runs on a background refresh + manual refresh.
3. Timeline view per Application: applied → heard back → each stage → outcome, with elapsed-time annotations.

*Accept:* a calendar invite from a tracked company surfaces as a proposed Stage with zero typing.

### Phase 3 — Capture Engine

> **Deferred in the interim (ADR 0002):** the engine below is paused; transcripts arrive by importing Granola output onto a Stage (the transcript-import slice, which owns `Transcript`/`Segment`). The privacy posture's on-device capture requirements bind the deferred slices, not the import path. This section stays as the definition of what returns.

1. Menu bar extra with record control + level meters + elapsed time.
2. Pre-call notification via EventKit ("Interview with {company} at 14:00 — record?").
3. Dual-stream capture: mic (AVAudioEngine) + system audio (ScreenCaptureKit audio / process tap). Streams kept separate → free speaker attribution (mic = me, system = them).
4. On-device transcription per stream; merge segments by timestamp into Transcript.
5. Permissions onboarding: mic, screen recording (required for system audio — needs careful explanatory copy), calendar. Detect-and-guide, never crash on denial.

*Accept:* record a Zoom call → attributed transcript attached to the right Stage, fully offline.

### Phase 4 — Intelligence Layer
All calls: Anthropic Messages API, structured-output prompts returning JSON matched to the models above. Prompts live in versioned files in-repo, not inline strings.
1. **Debrief**: Transcript + Stage context + CareerProfile → Debrief. Must cite transcript segments for every claim ("weak answer" links to the segment). No score, no offer probability — evidence and drills only.
2. **Prep pack**: next Stage kind + JD + `prepContext` + all prior Debriefs in this Application → PrepPack. For technical stages, generate mock tasks tuned to the JD's stack.
3. **Journey synthesis**: on `.offer`, generate the retrospective narrative over the full Stage chain (feeds the celebration view, §5).

*Accept:* debrief of a real transcript surfaces at least one "missed ammo" link back to a Profile Achievement.

### Phase 5 — Journey & polish
Journey celebration view (§5), stats across applications (response rates, stage conversion, time-in-stage), export.

---

## 5. Design direction

**Vibe:** friendly, warm, human. This app lives alongside one of the most stressful things people do; it should feel like a supportive coach, not an ATS. Explicitly *not*: corporate dashboard blue, dense data-grid energy, gamified confetti-spam.

- **Metaphor:** the climb / the path. The app is named for it. Progress is vertical and earned.
- **Tone of copy:** encouraging but honest, sentence case, plain verbs. Rejections are handled with dignity ("This one's closed — everything you prepped goes with you").
- **Journey celebration (signature element):** when an Application reaches `.offer`, render the full timeline as an illustrated vertical path — base camp (application) to summit (offer) — each Stage a waypoint with its date, elapsed time, and one line from its debrief. Generated as a shareable image/PDF. Style: warm, storybook-illustrated rather than chart-like; this is the emotional payoff of all that timestamp capture and should feel like a keepsake, not a report.
- **Everyday UI:** calm and quiet so the celebration moment lands. Restraint everywhere else; spend the boldness in one place.
- Respect reduced-motion; keyboard-navigable; native macOS feel (toolbars, inspector panels, menu bar idioms).

Detailed visual language (palette, type) to be developed in a separate design pass — treat this section as the brief for it.

---

## 6. Risks & open questions

| Risk | Mitigation |
|---|---|
| Screen-recording permission scares users | Onboarding explains *why* (system audio), shows exactly what is/isn't captured |
| Recording consent norms vary by jurisdiction | First-run notice; user's responsibility acknowledged; no default-on recording |
| ~~macOS 26 SpeechAnalyzer availability~~ | Resolved by ADR 0001 (macOS 26-only); `Transcriber` protocol kept for testability |
| LLM structured output drift | JSON-schema-validated responses; retry-with-repair loop |
| Calendar matching false positives | Always confirm with user before linking a Stage; never auto-create silently |
| Scope creep | Phase gates above are hard; nothing from a later phase starts before the prior phase's accept criteria pass |

Open questions to resolve during build:
- Email parsing for "heard back" timestamps (Mail.app AppleScript? paste-in only for v1?) — v1: paste-in only.
- Whether PrepPack mock tasks should be interactive (in-app answering) or exported — v1: exported markdown.

---

## 7. Repo conventions

- SwiftUI + SwiftData, MVVM-lite (views + observable stores; no heavyweight architecture).
- Feature folders are per-slice siblings: `Profile/`, `CVImport/`, `Tailor/`, `CVExport/`, `PipelineBoard/` (further Phase 2 slices join as siblings), `Recorder/` (further Phase 3 slices join as siblings — no umbrella `Capture/`), `Intelligence/`, `Journey/`, plus `Shared/`.
- Prompts in `Prompts/*.md`, versioned, loaded at runtime.
- All LLM calls behind `IntelligenceService` protocol → testable with fixtures.
- Capture code behind `CaptureService` protocol → UI developable without permissions granted.
