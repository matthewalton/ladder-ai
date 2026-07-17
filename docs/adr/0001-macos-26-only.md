# Target macOS 26 only

The generated spec originally said macOS 14+ with capture features gated to 14.2+/26 and a WhisperKit fallback for pre-26 transcription. Decided 2026-07-17 to target macOS 26 exclusively: the app is built first for the author's own job hunt on a 26 machine, and dropping older versions deletes the WhisperKit dependency entirely (native `SpeechAnalyzer` is always available), removes all OS-availability gating, and frees current SwiftUI/SwiftData APIs.

## Consequences

- Pre-Tahoe Macs (including the Intel models Tahoe dropped) cannot run Ladder — accepted reach cost for a direct-download tool aimed at tech job-seekers.
- This is one-way in practice: lowering the target later would mean retrofitting availability checks across freely-used 26-only APIs.
- The `Transcriber` protocol abstraction is kept anyway — it earns its place for testing, not for OS fallback.
