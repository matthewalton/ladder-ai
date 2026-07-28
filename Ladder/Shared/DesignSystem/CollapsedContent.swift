import SwiftData
import SwiftUI

extension ModelContext {
    /// Resolve a model by ID without trapping on a deleted one — `model(for:)`
    /// returns an invalidated instance that traps on first property access.
    func existingModel<T: PersistentModel>(_ id: PersistentIdentifier) -> T? {
        var descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? fetch(descriptor))?.first
    }
}

struct IndicatorRow<Extras: View>: View {
    var label: String
    var icon: String
    var onOpen: () -> Void
    var onRemove: () -> Void
    @ViewBuilder var extras: () -> Extras

    var body: some View {
        HStack {
            Label {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(Color.ink)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.pine)
            }
            Spacer()
            extras()
            Button("Open", action: onOpen)
            Button("Remove", action: onRemove)
        }
    }
}

extension IndicatorRow where Extras == EmptyView {
    init(
        label: String, icon: String,
        onOpen: @escaping () -> Void, onRemove: @escaping () -> Void
    ) {
        self.init(
            label: label, icon: icon, onOpen: onOpen, onRemove: onRemove,
            extras: { EmptyView() })
    }
}

struct ContentWindow<Model, Content: View>: View {
    var model: Model?
    var goneMessage: String
    @ViewBuilder var content: (Model) -> Content

    var body: some View {
        Group {
            if let model {
                ScrollView {
                    content(model)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.paper)
            } else {
                Text(goneMessage)
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .padding(40)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}

#Preview("Indicator row") {
    Form {
        IndicatorRow(
            label: "Notes set", icon: "note.text",
            onOpen: {}, onRemove: {}
        ) {
            Button("Export…") {}
        }
    }
    .formStyle(.grouped)
    .frame(width: 460)
}

#Preview("Content window") {
    ContentWindow(model: "The content body.", goneMessage: "This content is no longer set.") {
        Text($0)
            .font(.callout)
            .foregroundStyle(Color.ink)
    }
}
