import SwiftUI

enum AppSection: String, CaseIterable {
    case profile
    case applications
}

struct ContentView: View {
    @Bindable var store: ProfileStore
    @Bindable var pipelineStore: PipelineStore
    @Bindable var calendarStore: CalendarSyncStore
    @State private var section: AppSection = .profile

    var body: some View {
        TabView(selection: $section) {
            Tab("Profile", systemImage: "person.crop.rectangle", value: AppSection.profile) {
                ProfileRootView(store: store)
            }
            Tab("Applications", systemImage: "map", value: AppSection.applications) {
                VStack(spacing: 0) {
                    CalendarProposalsBar(store: calendarStore)
                    Divider()
                    PipelineRootView(
                        store: pipelineStore,
                        profileStore: store,
                        onLookBack: { application in
                            Task { await calendarStore.lookBack(for: application) }
                        }
                    ) {
                        CalendarSidebarSection(store: calendarStore)
                    }
                }
            }
        }
        // Pine is the app accent everywhere — selection, buttons, links —
        // so nothing renders in system blue (DESIGN.md §2).
        .tint(Color.pine)
        // The title-bar area joins the paper field instead of system gray.
        .toolbarBackground(Color.paper, for: .windowToolbar)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    let pipelineStore = PipelineStore(container: store.container)
    let calendarStore = CalendarSyncStore(
        pipeline: pipelineStore, service: FixtureCalendarSyncService()
    )
    return ContentView(store: store, pipelineStore: pipelineStore, calendarStore: calendarStore)
}
