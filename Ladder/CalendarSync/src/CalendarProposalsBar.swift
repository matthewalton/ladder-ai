import SwiftData
import SwiftUI

/// What the bar shows below its header — never proposals; the calendar
/// section owns those (decisions/0009). By construction this type has no
/// proposals case.
enum CalendarBarContent: Equatable {
    case headerOnly
    case deniedExplainer
    case noTrackedExplainer
    case noMatchesExplainer

    /// The explainer signals stay [CALSYNC-17]/[CALSYNC-19]/[CALSYNC-20]:
    /// denied wins, an empty ready scan explains itself, everything else —
    /// idle, scanning, or proposals pending — is the header row alone.
    static func content(
        scanState: CalendarScanState, hasProposals: Bool, hasTrackedApplications: Bool
    ) -> CalendarBarContent {
        switch scanState {
        case .denied:
            .deniedExplainer
        case .ready where !hasProposals:
            hasTrackedApplications ? .noMatchesExplainer : .noTrackedExplainer
        default:
            .headerOnly
        }
    }
}

/// Before a scan has run this renders only its header — the board never
/// depends on a scan having run.
struct CalendarProposalsBar: View {
    @Bindable var store: CalendarSyncStore
    @State private var showingResults = false

    private var content: CalendarBarContent {
        CalendarBarContent.content(
            scanState: store.scanState,
            hasProposals: !store.proposals.isEmpty,
            hasTrackedApplications: store.hasTrackedApplications
        )
    }

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
                // Also the explicit gesture that first requests calendar
                // access. Only a check opens the results sheet — automatic
                // re-scans never present anything (decisions/0008).
                Button {
                    Task {
                        await store.check()
                        showingResults =
                            store.scanState == .ready
                            && !(store.proposals.isEmpty && store.otherEvents.isEmpty)
                    }
                } label: {
                    Label("Check calendar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            switch content {
            case .headerOnly:
                EmptyView()
            case .deniedExplainer:
                deniedExplainer
            case .noTrackedExplainer:
                emptyScanExplainer(
                    "Nothing to match yet — matching starts once an application is past Draft. Move one along, or add one to the board."
                )
            case .noMatchesExplainer:
                emptyScanExplainer(
                    "No calendar events matched a tracked company — scans cover a week back and a month ahead."
                )
            }
        }
        .padding(12)
        .background(Color.paper)
        .sheet(isPresented: $showingResults, onDismiss: store.discardOtherEvents) {
            CheckResultsSheet(store: store)
        }
    }

    /// Only reachable in `.ready` — idle, scanning, and denied render other
    /// branches.
    private func emptyScanExplainer(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.inkSoft)
            Text(message)
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

#Preview("Proposals pending — header only") {
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
