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
                PipelineRootView(
                    store: pipelineStore,
                    onLookBack: { application in
                        Task { await calendarStore.lookBack(for: application) }
                    }
                )
                .safeAreaInset(edge: .top, spacing: 0) {
                    CalendarProposalsBar(store: calendarStore)
                }
            }
        }
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
