import SwiftData
import SwiftUI

struct PipelineRootView<SidebarFooter: View>: View {
    @Bindable var store: PipelineStore
    /// Passed through to the detail's look-back button; nil renders none.
    var onLookBack: ((Application) -> Void)?
    /// Rendered at the bottom of the sidebar list — the slot the calendar
    /// section plugs into (CalendarSync decisions/0009). Unspecced here.
    @ViewBuilder var sidebarFooter: () -> SidebarFooter

    enum ContentPane: String, CaseIterable {
        case board = "Board"
        case timeline = "Timeline"
    }

    @State private var selection: PersistentIdentifier?
    @State private var showInspector = true
    @State private var contentPane: ContentPane = .board
    @State private var isAddingApplication = false

    private var selectedApplication: Application? {
        selection.flatMap { store.application(for: $0) }
    }

    var body: some View {
        Group {
            if store.applications.isEmpty {
                emptyState
            } else {
                shell
            }
        }
        // Attached here so the toolbar and empty-state affordances share it.
        .sheet(isPresented: $isAddingApplication) {
            AddApplicationSheet(store: store)
        }
    }

    private var shell: some View {
            NavigationSplitView {
                List(selection: $selection) {
                    ForEach(store.applications) { application in
                        // Semantic styles, not ink: they invert to white when
                        // the pine selection highlight draws behind the row.
                        VStack(alignment: .leading) {
                            Text(application.company)
                                .foregroundStyle(.primary)
                            Text(application.roleTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(application.persistentModelID)
                    }
                    sidebarFooter()
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } detail: {
                Group {
                    if contentPane == .timeline, let application = selectedApplication {
                        ApplicationTimelineView(application: application)
                    } else {
                        PipelineBoardView(store: store, selection: $selection)
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Button {
                            isAddingApplication = true
                        } label: {
                            Label("Add application", systemImage: "plus")
                        }
                    }
                    ToolbarItem {
                        Picker("View", selection: $contentPane) {
                            ForEach(ContentPane.allCases, id: \.self) { pane in
                                Text(pane.rawValue).tag(pane)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(selectedApplication == nil)
                    }
                    ToolbarItem {
                        Button {
                            showInspector.toggle()
                        } label: {
                            Label("Details", systemImage: "sidebar.trailing")
                        }
                    }
                }
            }
            .inspector(isPresented: $showInspector) {
                if let application = selectedApplication {
                    ApplicationDetailView(
                        store: store, application: application,
                        onLookBack: onLookBack.map { callback in
                            { callback(application) }
                        }
                    )
                    .inspectorColumnWidth(min: 280, ideal: 320)
                } else {
                    Text("Select an application to see its trail.")
                        .font(.trailNarrative())
                        .foregroundStyle(Color.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            ContourBackground()
                                .background(Color.paper)
                        }
                }
            }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No applications on the trail yet.")
                .font(.trailNarrative(.title2))
                .foregroundStyle(Color.inkSoft)
            Text("Tailor a CV from your Profile, or add one by hand.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
            // The shell toolbar (and its add button) does not render here.
            Button("Add application") {
                isAddingApplication = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ContourBackground()
                .background(Color.paper)
        }
    }
}

extension PipelineRootView where SidebarFooter == EmptyView {
    init(store: PipelineStore, onLookBack: ((Application) -> Void)? = nil) {
        self.init(store: store, onLookBack: onLookBack) { EmptyView() }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    return PipelineRootView(store: store)
        .frame(width: 1000, height: 600)
}
