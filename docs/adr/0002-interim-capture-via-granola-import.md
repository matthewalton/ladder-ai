# Interim capture via imported transcripts (Granola)

Decided 2026-07-20 to pause the native capture engine and refine the rest of the app first. The recorder slice had shipped (fe22ae5) and the transcription slice was specced, but the remaining engine — on-device transcription, system audio, permissions onboarding — is the heaviest work in the roadmap, and none of it is needed to exercise the loop the app is actually for. In the interim, interview transcripts come from Granola, which the user already runs on every call: a **transcript-import** slice lets a transcript be pasted (or dropped as a text/markdown file) onto a Stage and parsed into `Transcript` + `Segment`.

Ladder itself stays ignorant of Granola. It does not speak MCP (an app-side MCP client with OAuth would cost more than the recorder it replaces) and it does not read Granola's local cache (encrypted since April 2026; Granola's own guidance is to use their MCP). Getting text out of Granola is a manual step — copy from the Granola app, or have an agent fetch it via Granola's official MCP server outside the app.

## Consequences

- The privacy posture in ARCHITECTURE.md ("audio never leaves the machine, transcription fully on-device") is knowingly suspended for the interim: Granola records and transcribes in its cloud, under the user's own account. The posture now binds the deferred native-capture slices, not Phase 3 itself, and re-attaches when they return.
- The recorder slice is deleted from the tree — with it go the `MenuBarExtra` scene, mic entitlement, usage string, and consent flow. It is one commit away from restoration (fe22ae5) and returns with native capture. The specced-but-unbuilt transcription contract is shelved; system-audio and pre-call stay deferred roadmap lines.
- `Transcript`, `Segment`, and the `Stage.transcript` link land in the transcript-import slice instead, in the shape ARCHITECTURE.md §3 defines — imported and natively-captured transcripts are indistinguishable downstream, so nothing Phase 4 builds against them is throwaway.
- Speaker attribution comes from labels in the imported text (Granola marks the speakers) rather than from stream identity (mic = me / system = them).
- When native capture returns, import remains as a fallback path for meetings Ladder didn't record.
- Amended 2026-07-20: public share links (`notes.granola.ai/t/…`) are additionally fetched over plain unauthenticated HTTPS as a third import door — still no MCP, no cache reading, no login; the app reads only what the link already makes public (TranscriptImport decisions/0006).
