import SwiftUI

/// The browse list ([CALSYNC-27], [CALSYNC-28]): every window event the
/// scan fetched, minus linked and dismissed ones — the fallback for real
/// interviews the heuristic misses. Picking one hands the event back for
/// the normal confirmation flow; this sheet itself never writes.
struct BrowseEventsSheet: View {
    @Bindable var store: CalendarSyncStore
    let onPick: (CalendarEvent) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All calendar events in the scan window")
                .font(.trailNarrative(.headline))
                .foregroundStyle(Color.inkSoft)

            if store.browseEvents.isEmpty {
                Text("Nothing in the window — scans cover a week back and a month ahead.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.browseEvents) { event in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .foregroundStyle(Color.ink)
                                    Text(
                                        event.start
                                            .formatted(date: .abbreviated, time: .shortened)
                                    )
                                    .font(.caption)
                                    .foregroundStyle(Color.inkSoft)
                                }
                                Spacer()
                                Button("Review…") { onPick(event) }
                            }
                            .padding(10)
                            .background(
                                Color.paperRaised,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 280)
        .background(Color.paper)
    }
}

#Preview {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline,
        service: FixtureCalendarSyncService(events: [
            CalendarEvent(
                identifier: "evt-1",
                title: "Coffee with Jane",
                start: .now.addingTimeInterval(3_600)
            ),
            CalendarEvent(
                identifier: "evt-2",
                title: "Interview with Hooli",
                start: .now.addingTimeInterval(86_400),
                location: "https://hooli.zoom.us/j/9"
            ),
        ])
    )
    return BrowseEventsSheet(store: store) { _ in }
        .task { await store.scan() }
}
