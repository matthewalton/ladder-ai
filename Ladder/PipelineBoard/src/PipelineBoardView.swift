import SwiftData
import SwiftUI

struct PipelineBoardView: View {
    @Bindable var store: PipelineStore
    @Binding var selection: PersistentIdentifier?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(ApplicationStatus.allCases, id: \.self) { status in
                    StatusColumnView(store: store, status: status, selection: $selection)
                }
            }
            .padding(12)
        }
        .background(Color.paper)
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    return PipelineBoardView(store: store, selection: .constant(nil))
        .frame(width: 900, height: 500)
}
