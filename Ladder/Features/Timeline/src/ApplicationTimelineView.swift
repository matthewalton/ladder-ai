import SwiftData
import SwiftUI

/// Read-only: every date shown is persisted by pipeline-board or calendar-sync.
struct ApplicationTimelineView: View {
    var application: Application
    var asOf: Date = .now

    private static let blazeColumn: CGFloat = 20

    var body: some View {
        let entries = TimelineModel.entries(for: application)
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(application.company)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ink)
                Text(application.roleTitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSoft)

                if entries.isEmpty {
                    Text("No dated activity yet. Add a Stage or an applied date to draw the line.")
                        .font(.trailNarrative(.callout))
                        .foregroundStyle(Color.inkSoft)
                        .padding(.top, 16)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            if index > 0 {
                                segment(from: entries[index - 1], to: entry)
                            }
                            row(for: entry)
                        }
                        if let inStage = TimelineModel.inStageLabel(for: application, asOf: asOf) {
                            trailingLabel(inStage)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Color.paper)
    }

    private func row(for entry: TimelineEntry) -> some View {
        HStack(spacing: 12) {
            BlazeMark(blaze: entry.blaze, filled: entry.isFilled, tint: tint(for: entry))
                .frame(width: Self.blazeColumn)
            Text(entry.label)
                .font(.body)
                .foregroundStyle(Color.ink)
            Spacer()
            if let date = entry.date {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Color.inkSoft)
            }
        }
    }

    /// Stage-kind accent on the node only (DESIGN.md §2): summit gold for the
    /// offer, desaturated "closed trail" for rejected/withdrawn, pine
    /// otherwise.
    private func tint(for entry: TimelineEntry) -> Color {
        switch entry.kind {
        case .stage(let kind): kind.accent
        case .outcome(.offer): .summitGold
        case .outcome(.rejected), .outcome(.withdrawn): .inkSoft
        default: .pine
        }
    }

    private func segment(from: TimelineEntry, to: TimelineEntry) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.pine)
                .frame(width: 2, height: 28)
                .frame(width: Self.blazeColumn)
            if let label = TimelineModel.segmentLabel(from: from, to: to) {
                Text(label)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.inkSoft)
            }
            Spacer()
        }
    }

    private func trailingLabel(_ text: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.mist)
                .frame(width: 2, height: 20)
                .frame(width: Self.blazeColumn)
            Text(text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.inkSoft)
            Spacer()
        }
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let context = ModelContext(container)
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer", jobDescription: "JD",
        status: .active,
        appliedAt: Date(timeIntervalSince1970: 1_770_000_000),
        createdAt: Date(timeIntervalSince1970: 1_770_000_000)
    )
    context.insert(application)
    application.stages = [
        Stage(
            kind: .screen,
            scheduledAt: Date(timeIntervalSince1970: 1_770_000_000 + 5 * 86_400),
            outcome: .passed, sortIndex: 0
        ),
        Stage(
            kind: .technical,
            scheduledAt: Date(timeIntervalSince1970: 1_770_000_000 + 12 * 86_400),
            sortIndex: 1
        ),
    ]
    return ApplicationTimelineView(
        application: application,
        asOf: Date(timeIntervalSince1970: 1_770_000_000 + 14 * 86_400)
    )
    .frame(width: 480, height: 480)
}
