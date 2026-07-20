import SwiftData
import SwiftUI

/// The calendar section (decisions/0009): rendered inside the Applications
/// sidebar beneath the tracked-applications list. Renders nothing at all
/// when no proposal is pending.
struct CalendarSidebarSection: View {
    @Bindable var store: CalendarSyncStore

    var body: some View {
        let rows = CalendarSection.rows(from: store.proposals)
        if !rows.isEmpty {
            Divider()
            ForEach(rows) { row in
                CalendarSidebarRow(store: store, row: row)
            }
        }
    }
}

/// Compact for the narrow sidebar: clicking opens the confirmation sheet;
/// dismissal is the hover ✕ or the context menu, both through
/// `CalendarSyncStore.dismiss`.
private struct CalendarSidebarRow: View {
    @Bindable var store: CalendarSyncStore
    let row: CalendarSectionRow
    @State private var isHovered = false
    @State private var isReviewing = false

    private var proposal: StageProposal? {
        store.proposals.first { $0.id == row.id }
    }

    var body: some View {
        Button {
            isReviewing = true
        } label: {
            HStack(alignment: .top, spacing: 6) {
                // Semantic styles so the text inverts on the selection
                // highlight.
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(row.start.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    badge
                }
                Spacer(minLength: 0)
                if isHovered {
                    Button {
                        dismissProposal()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.inkSoft)
                    }
                    .buttonStyle(.borderless)
                    .help("Dismiss")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Review…") { isReviewing = true }
            Button("Dismiss") { dismissProposal() }
        }
        .sheet(isPresented: $isReviewing) {
            if let proposal {
                StageProposalSheet(store: store, proposal: proposal)
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if row.isPossibleInterview {
            Text("Possible interview")
                .font(.caption2)
                .foregroundStyle(Color.skyline)
        } else if let guess = row.kindGuess {
            StageKindChip(kind: guess)
        }
    }

    private func dismissProposal() {
        if let proposal {
            try? store.dismiss(proposal)
        }
    }
}

#Preview {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline,
        service: FixtureCalendarSyncService(events: [
            CalendarEvent(
                identifier: "evt-1",
                title: "Acme system design",
                start: .now.addingTimeInterval(86_400),
                location: "https://acme.zoom.us/j/123"
            ),
            CalendarEvent(
                identifier: "evt-2",
                title: "Interview with Hooli",
                start: .now.addingTimeInterval(172_800),
                location: "https://hooli.zoom.us/j/9"
            ),
        ])
    )
    return List {
        Text("Acme — Engineer")
        CalendarSidebarSection(store: store)
    }
    .frame(width: 220, height: 400)
    .task {
        let context = ModelContext(pipeline.container)
        context.insert(
            Application(
                company: "Acme", roleTitle: "Engineer", jobDescription: "JD",
                status: .applied, appliedAt: .now
            )
        )
        try? context.save()
        try? pipeline.load()
        await store.scan()
    }
}
