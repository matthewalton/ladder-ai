import SwiftData
import SwiftUI

/// An illegal drop is refused by the store's throw — the card snaps back.
struct StatusColumnView: View {
    @Bindable var store: PipelineStore
    var status: ApplicationStatus
    @Binding var selection: PersistentIdentifier?

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.columnTitle)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(store.applications(in: status).count)")
                    .trailMetadata()
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.applications(in: status)) { application in
                        ApplicationCardView(application: application)
                            .draggable(ApplicationDragItem(id: application.persistentModelID))
                            .onTapGesture { selection = application.persistentModelID }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        selection == application.persistentModelID
                                            ? Color.pine : .clear,
                                        lineWidth: 2)
                            )
                    }
                }
                .padding(2)
            }
        }
        .padding(8)
        .frame(width: 236)
        .background(
            isTargeted ? Color.pineTint.opacity(0.5) : Color.paper,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .dropDestination(for: ApplicationDragItem.self) { items, _ in
            guard let item = items.first,
                let application = store.application(for: item.id)
            else { return false }
            do {
                try store.move(application, to: status)
                return true
            } catch {
                return false
            }
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    return StatusColumnView(store: store, status: .applied, selection: .constant(nil))
        .frame(height: 400)
        .padding()
        .background(Color.paper)
}
