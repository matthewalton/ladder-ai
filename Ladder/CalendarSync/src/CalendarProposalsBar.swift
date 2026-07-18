import SwiftData
import SwiftUI

/// The Applications section's calendar strip: proposals awaiting a ruling,
/// the manual refresh action, and the quiet denied-state explainer
/// ([CALSYNC-17]). Renders nothing at all when there is nothing to say —
/// the board never depends on a scan having run.
struct CalendarProposalsBar: View {
    @Bindable var store: CalendarSyncStore
    @State private var reviewing: StageProposal?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("From your calendar")
                    .font(.trailNarrative(.headline))
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                if store.scanState == .scanning {
                    ProgressView()
                        .controlSize(.small)
                }
                // The manual refresh action (decisions/0003) — also the
                // explicit user gesture that first requests access
                // (decisions/0001).
                Button {
                    Task { await store.scan() }
                } label: {
                    Label("Check calendar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            switch store.scanState {
            case .denied:
                deniedExplainer
            default:
                if !store.proposals.isEmpty {
                    proposalList
                }
            }
        }
        .padding(12)
        .background(Color.paper)
        .sheet(item: $reviewing) { proposal in
            StageProposalSheet(store: store, proposal: proposal)
        }
    }

    private var proposalList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.proposals) { proposal in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proposal.event.title)
                            .foregroundStyle(Color.ink)
                        Text(
                            proposal.event.start
                                .formatted(date: .abbreviated, time: .shortened)
                        )
                        .font(.caption)
                        .foregroundStyle(Color.inkSoft)
                    }
                    Spacer()
                    if let guess = proposal.kindGuess {
                        Text(guess.label)
                            .font(.caption)
                            .foregroundStyle(Color.pine)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.pineTint, in: Capsule())
                    }
                    Button("Review…") { reviewing = proposal }
                    Button("Dismiss") { try? store.dismiss(proposal) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.inkSoft)
                }
                .padding(10)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var deniedExplainer: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .foregroundStyle(Color.inkSoft)
            Text("Ladder can't see your calendar, so interviews won't surface here. Everything else works as normal.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
            Spacer()
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
            ) {
                Link("System Settings", destination: url)
                    .font(.callout)
            }
        }
        .padding(10)
    }
}

#Preview("Proposals") {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline,
        service: FixtureCalendarSyncService(events: [
            CalendarEvent(
                identifier: "evt-1",
                title: "Acme system design",
                start: .now.addingTimeInterval(86_400),
                location: "https://acme.zoom.us/j/123"
            )
        ])
    )
    return CalendarProposalsBar(store: store)
        .frame(width: 640)
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

#Preview("Denied") {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline,
        service: FixtureCalendarSyncService(state: .denied)
    )
    return CalendarProposalsBar(store: store)
        .frame(width: 640)
        .task { await store.scan() }
}
