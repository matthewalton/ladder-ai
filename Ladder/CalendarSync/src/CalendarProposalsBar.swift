import SwiftData
import SwiftUI

/// Before a scan has run this renders only its header — the board never
/// depends on a scan having run.
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
                if !store.browseEvents.isEmpty {
                    Button {
                        isBrowsing = true
                    } label: {
                        Label("Browse events", systemImage: "list.bullet")
                    }
                    .buttonStyle(.borderless)
                }
                // Also the explicit gesture that first requests calendar
                // access.
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

    /// Only reachable in `.ready` — idle, scanning, and denied render other
    /// branches.
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
