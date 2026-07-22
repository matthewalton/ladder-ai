import SwiftData
import SwiftUI

struct PipelineRootView<SidebarFooter: View>: View {
    @Bindable var store: PipelineStore
    /// Tailoring starts from this shell (decisions/0007); nil renders no
    /// tailor affordance (tests that only exercise the board).
    var profileStore: ProfileStore?
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
    @State private var isImporting = false
    @State private var tailoringApplication: Application?

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
        .sheet(isPresented: $isImporting) {
            // Pause at the application ([PIPEBOARD-42]): the created draft
            // is selected with its detail open — Create CV lives there.
            JobImportSheet(
                pipelineStore: store,
                onCreated: { application in
                    try? store.load()
                    selection = application.persistentModelID
                    showInspector = true
                }
            )
        }
        .sheet(item: $tailoringApplication) { application in
            if let profileStore {
                // The export attaches the CV to this application; the store
                // reloads on dismiss so the draft → applied move re-columns
                // the card without a relaunch.
                TailorView(profileStore: profileStore, application: application)
                    .onDisappear { try? store.load() }
            }
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
                    // The one creation door ([PIPEBOARD-41]) — deliberately
                    // the only prominent toolbar action.
                    ToolbarItem {
                        Button {
                            isImporting = true
                        } label: {
                            Label("Create CV for new application", systemImage: "doc.badge.plus")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pine)
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
                        },
                        // Tailoring needs the Profile; nil renders no
                        // Create CV ([PIPEBOARD-42]).
                        onCreateCV: profileStore == nil
                            ? nil
                            : { tailoringApplication = application }
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
            Text("Paste a job posting's link or drop its PDF — Ladder files the application and starts your CV.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
            // The shell toolbar (and its button) does not render here.
            Button("Create CV for new application") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.pine)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ContourBackground()
                .background(Color.paper)
        }
    }
}

extension PipelineRootView where SidebarFooter == EmptyView {
    init(
        store: PipelineStore,
        profileStore: ProfileStore? = nil,
        onLookBack: ((Application) -> Void)? = nil
    ) {
        self.init(store: store, profileStore: profileStore, onLookBack: onLookBack) { EmptyView() }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    return PipelineRootView(store: store)
        .frame(width: 1000, height: 600)
}
