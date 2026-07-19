import SwiftUI

/// The shell's two sections ([PIPEBOARD-14]): the Profile slice and the
/// Applications board.
enum AppSection: String, CaseIterable {
    case profile
    case applications
}

/// App shell. Phase 2: two sections — Profile keeps its Phase 1 window,
/// Applications shows the pipeline board.
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
                    // The on-demand look-back ([CALSYNC-29], [CALSYNC-30]):
                    // proposals land in the bar like any others.
                    onLookBack: { application in
                        Task { await calendarStore.lookBack(for: application) }
                    }
                )
                // calendar-sync's strip: proposals, the manual check,
                // and the denied explainer ([CALSYNC-17]).
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
