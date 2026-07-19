import SwiftData
import SwiftUI

struct PipelineRootView: View {
    @Bindable var store: PipelineStore
    /// Passed through to the detail's look-back button; nil renders none.
    var onLookBack: ((Application) -> Void)?

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
                List(store.applications, selection: $selection) { application in
                    VStack(alignment: .leading) {
                        Text(application.company)
                            .foregroundStyle(Color.ink)
                        Text(application.roleTitle)
                            .font(.caption)
                            .foregroundStyle(Color.inkSoft)
                    }
                    .tag(application.persistentModelID)
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
                        .padding()
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

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    return PipelineRootView(store: store)
        .frame(width: 1000, height: 600)
}
