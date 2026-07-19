import SwiftUI

/// The MenuBarExtra content: one view per recorder state. The store is the
/// measurable surface; everything here is the visual-verify layer.
struct RecorderPopoverView: View {
    var store: RecorderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.state {
            case .awaitingConsent:
                CaptureConsentView(store: store)
            case .denied:
                MicDeniedView()
            case .recording:
                RecordingView(store: store)
            case .idle:
                RecorderIdleView(store: store)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color.paper)
    }
}

struct RecorderIdleView: View {
    var store: RecorderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recorder")
                .font(.trailNarrative(.headline))
                .foregroundStyle(Color.inkSoft)
            if store.captureFailed {
                Text("The last capture ended unexpectedly.")
                    .font(.caption)
                    .foregroundStyle(Color.clay)
            }
            Button {
                Task { await store.record() }
            } label: {
                Label("Record", systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pine)
        }
    }
}

struct RecordingView: View {
    var store: RecorderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(Color.clay)
                Text("Recording")
                    .font(.trailNarrative(.headline))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text(elapsedText)
                    .trailMetadata()
                    .foregroundStyle(Color.inkSoft)
            }
            LevelMeterView(level: store.meterLevel)
            Button {
                Task { await store.stop() }
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .buttonStyle(.bordered)
        }
    }

    private var elapsedText: String {
        let total = Int(store.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct LevelMeterView: View {
    var level: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.mist)
                Capsule()
                    .fill(Color.pine)
                    .frame(width: max(0, proxy.size.width * min(level, 1)))
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.1), value: level)
    }
}

struct CaptureConsentView: View {
    var store: RecorderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Before your first capture")
                .font(.trailNarrative(.headline))
                .foregroundStyle(Color.ink)
            // The copy is pinned in decisions/0002.
            Text(
                """
                Ladder listens to your microphone only while you record, \
                shows you levels, and keeps nothing — no audio is stored, \
                and nothing leaves this Mac. Transcription, when it \
                arrives, happens on this Mac too.
                """
            )
            .font(.callout)
            .foregroundStyle(Color.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Not now") {
                    store.declineConsent()
                }
                .buttonStyle(.bordered)
                Button("Allow capture") {
                    Task { await store.acceptConsent() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pine)
            }
        }
    }
}

struct MicDeniedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Microphone access is off")
                .font(.trailNarrative(.headline))
                .foregroundStyle(Color.ink)
            Text("Ladder can't hear anything. Everything else works as ever.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Link(
                "Open System Settings",
                destination: URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                )!
            )
            .font(.callout)
        }
    }
}

#Preview("Idle") {
    RecorderPopoverView(
        store: RecorderStore(
            service: FixtureCaptureService(),
            defaults: UserDefaults(suiteName: "RecorderPreview")!
        )
    )
}

#Preview("Consent") {
    CaptureConsentView(
        store: RecorderStore(
            service: FixtureCaptureService(),
            defaults: UserDefaults(suiteName: "RecorderPreview")!
        )
    )
    .padding(16)
    .frame(width: 300)
    .background(Color.paper)
}

#Preview("Recording") {
    RecordingView(
        store: RecorderStore(
            service: FixtureCaptureService(),
            defaults: UserDefaults(suiteName: "RecorderPreview")!
        )
    )
    .padding(16)
    .frame(width: 300)
    .background(Color.paper)
}

#Preview("Level meter") {
    LevelMeterView(level: 0.6)
        .padding(16)
        .frame(width: 300)
}

#Preview("Denied") {
    MicDeniedView()
        .padding(16)
        .frame(width: 300)
        .background(Color.paper)
}
