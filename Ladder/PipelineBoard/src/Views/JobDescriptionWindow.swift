import SwiftData
import SwiftUI

/// The read-only window showing an Application's full job description — the
/// detail form only indicates it is set ([PIPEBOARD-31]). Read-only is
/// deliberate (docs/adr/0003): a set JD changes by re-import, or remove and
/// retype.
struct JobDescriptionWindow: View {
    static let windowID = "job-description"

    var store: PipelineStore
    var applicationID: PersistentIdentifier

    var resolvedApplication: Application? {
        guard let application = store.application(for: applicationID),
            !application.jobDescription.isEmpty
        else { return nil }
        return application
    }

    var body: some View {
        ContentWindow(
            model: resolvedApplication,
            goneMessage: "This job description is no longer set."
        ) { application in
            VStack(alignment: .leading, spacing: 8) {
                Text("Job description — \(application.company)")
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.ink)
                Text(application.jobDescription)
                    .font(.callout)
                    .foregroundStyle(Color.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    let context = ModelContext(store.container)
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability across the fleet.",
        status: .active)
    context.insert(application)
    try! context.save()
    return JobDescriptionWindow(
        store: store, applicationID: application.persistentModelID)
}
