import SwiftData
import SwiftUI

/// The Applications section's root: empty state until the first Application
/// exists, then the DESIGN.md §4 three-pane — sidebar list, board, inspector
/// detail for the selection.
struct PipelineRootView: View {
    @Bindable var store: PipelineStore

    @State private var selection: PersistentIdentifier?
    @State private var showInspector = true

    private var selectedApplication: Application? {
        selection.flatMap { store.application(for: $0) }
    }

    var body: some View {
        if store.applications.isEmpty {
            emptyState
        } else {
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
                PipelineBoardView(store: store, selection: $selection)
                    .toolbar {
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
                    ApplicationDetailView(store: store, application: application)
                        .inspectorColumnWidth(min: 280, ideal: 320)
                } else {
                    Text("Select an application to see its trail.")
                        .font(.trailNarrative())
                        .foregroundStyle(Color.inkSoft)
                        .padding()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No applications on the trail yet.")
                .font(.trailNarrative(.title2))
                .foregroundStyle(Color.inkSoft)
            Text("Tailor a CV from your Profile to start one.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
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
