import SwiftData
import SwiftUI

/// The Applications section's calendar strip: proposals awaiting a ruling,
/// the manual refresh action, and the quiet explainers — denied state
/// ([CALSYNC-17]) and empty scan ([CALSYNC-19], [CALSYNC-20]). Before a
/// scan has run it renders only its header — the board never depends on a
/// scan having run.
struct CalendarProposalsBar: View {
    @Bindable var store: CalendarSyncStore
    @State private var reviewing: StageProposal?
    @State private var isBrowsing = false

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
                // The browse fallback ([CALSYNC-27], [CALSYNC-28]) — only
                // once a scan has fetched something to browse.
                if !store.browseEvents.isEmpty {
                    Button {
                        isBrowsing = true
                    } label: {
                        Label("Browse events", systemImage: "list.bullet")
                    }
                    .buttonStyle(.borderless)
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
            case .ready where store.proposals.isEmpty:
                emptyScanExplainer
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
        .sheet(isPresented: $isBrowsing) {
            BrowseEventsSheet(store: store) { event in
                // Picking proposes on demand ([CALSYNC-28]); the normal
                // confirmation flow takes it from here.
                isBrowsing = false
                reviewing = store.proposal(for: event)
            }
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
                    // A proposal with no candidates is the heuristic's work
                    // ([CALSYNC-21], [CALSYNC-22]) — say so, since its
                    // confirmation creates an Application rather than
                    // attaching to one.
                    if proposal.isPossibleInterview {
                        Text("Possible interview")
                            .font(.caption)
                            .foregroundStyle(Color.skyline)
                    }
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

    /// The empty-scan explainers ([CALSYNC-19], [CALSYNC-20]), chosen live
    /// by the tracked-Applications signal (decisions/0006). Only reachable
    /// in `.ready` — idle, scanning, and denied render other branches.
    private var emptyScanExplainer: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.inkSoft)
            Text(
                store.hasTrackedApplications
                    ? "No calendar events matched a tracked company — scans cover a week back and a month ahead."
                    : "Nothing to match yet — matching starts once an application is past Draft. Move one along, or add one to the board."
            )
            .font(.callout)
            .foregroundStyle(Color.inkSoft)
            Spacer()
        }
        .padding(10)
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

#Preview("Empty scan — nothing tracked") {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline,
        service: FixtureCalendarSyncService(events: [])
    )
    return CalendarProposalsBar(store: store)
        .frame(width: 640)
        .task { await store.scan() }
}

#Preview("Empty scan — no matches") {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline,
        service: FixtureCalendarSyncService(events: [])
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
