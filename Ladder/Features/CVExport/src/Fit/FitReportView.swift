import SwiftUI

struct FitReportView: View {
    var report: FitReport
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Why these were selected") {
                    Text(report.rationale)
                        .font(.trailNarrative())
                        .foregroundStyle(Color.ink)
                        .padding(.vertical, 4)
                }
                Section("Strengths") {
                    ForEach(report.strengths, id: \.self) { strength in
                        chip(strength, icon: "checkmark.circle", tint: Color.pine)
                    }
                }
                if !report.gaps.isEmpty {
                    Section("Gaps") {
                        ForEach(report.gaps, id: \.self) { gap in
                            chip(gap, icon: "exclamationmark.circle", tint: Color.clay)
                        }
                    }
                }
                if !report.trimmed.isEmpty {
                    // Nothing the fit loop dropped is silently gone
                    // ([CVEXPORT-28]).
                    Section("Trimmed to fit two pages") {
                        ForEach(report.trimmed, id: \.self) { item in
                            chip(item, icon: "scissors", tint: Color.inkSoft)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Divider()
            HStack {
                Text("Your CV was saved and this application is on record.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
            }
            .padding(12)
            .background(Color.paperRaised)
        }
        .background(Color.paper)
    }

    private func chip(_ text: String, icon: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.ink)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    FitReportView(
        report: FitReport(
            outcome: ReviewedOutcome(
                items: [
                    .init(
                        canonicalText: "Cut CI build times across every product target",
                        text: "Drove CI build times down across every product target"
                    )
                ],
                gaps: ["The JD asks for Kubernetes; nothing on file mentions it"],
                rationale: "CI work maps directly to the JD's platform focus — the strongest achievements on file are exactly the ones this role screens for."
            )
        ),
        onDone: {}
    )
    .frame(width: 640, height: 480)
}
