import SwiftUI

/// App shell: standard three-pane layout (ARCHITECTURE.md §5, DESIGN.md §4).
/// Sidebar and detail are placeholders until the Phase 1 slices land.
struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
            }
            .navigationTitle("Ladder")
        } detail: {
            Text("Every climb starts with a pack.")
                .font(.trailNarrative(.title3))
                .foregroundStyle(Color.inkSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.paper)
        }
    }
}

#Preview {
    ContentView()
}
