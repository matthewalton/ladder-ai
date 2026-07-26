import SwiftData
import SwiftUI

/// The separate window showing a Stage's full debrief — the Stage form only
/// indicates one exists ([DEBRIEF-18], [DEBRIEF-19]; docs/adr/0003).
struct DebriefWindow: View {
    static let windowID = "debrief"

    var container: ModelContainer
    var debriefID: PersistentIdentifier

    var resolvedDebrief: Debrief? {
        ModelContext(container).existingModel(debriefID)
    }

    var body: some View {
        ContentWindow(
            model: resolvedDebrief,
            goneMessage: "This debrief is no longer on the Stage."
        ) { debrief in
            VStack(alignment: .leading, spacing: 8) {
                Text("Debrief — \(debrief.generatedAt.formatted(date: .long, time: .omitted))")
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.ink)
                DebriefContentView(debrief: debrief)
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let context = ModelContext(container)
    let debrief = Debrief(
        generatedAt: .now,
        themes: [GroundedRemark(
            text: "Reliability ran through the whole conversation",
            quote: "Walked through the incident timeline")],
        drills: ["Rehearse the outage story leading with the incident-command role"]
    )
    context.insert(debrief)
    let question = DebriefQuestion(
        question: "How did you handle the payments outage?",
        answerSummary: "Walked the timeline but never claimed the lead",
        quality: .adequate,
        quote: "Walked through the incident timeline")
    context.insert(question)
    question.debrief = debrief
    try! context.save()
    return DebriefWindow(container: container, debriefID: debrief.persistentModelID)
}
