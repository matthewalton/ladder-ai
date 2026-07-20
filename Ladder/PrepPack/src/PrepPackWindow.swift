import SwiftData
import SwiftUI

/// The separate window showing a Stage's full prep pack — the Stage form
/// only indicates one exists ([PREP-20], [PREP-21]; docs/adr/0003).
struct PrepPackWindow: View {
    static let windowID = "prep-pack"

    var container: ModelContainer
    var packID: PersistentIdentifier

    var resolvedPack: PrepPack? {
        ModelContext(container).existingModel(packID)
    }

    var body: some View {
        ContentWindow(
            model: resolvedPack,
            goneMessage: "This prep pack is no longer on the Stage."
        ) { pack in
            VStack(alignment: .leading, spacing: 8) {
                Text("Prep pack — \(pack.generatedAt.formatted(date: .long, time: .omitted))")
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.ink)
                PrepPackContentView(pack: pack)
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let context = ModelContext(container)
    let pack = PrepPack(
        generatedAt: .now,
        likelyQuestions: [
            "Walk me through a production incident you owned end to end."
        ],
        companyBrief: "Summit Labs is hiring a Platform Engineer to own reliability.",
        mockTasks: [
            MockTask(
                title: "Design a rate limiter",
                brief: "Sketch a rate limiter for a multi-tenant API.")
        ])
    context.insert(pack)
    let point = PrepTalkingPoint(text: "Lead with the payments-outage incident command story")
    context.insert(point)
    point.prepPack = pack
    try! context.save()
    return PrepPackWindow(container: container, packID: pack.persistentModelID)
}
