import SwiftData
import SwiftUI

/// The confirmation sheet (slice CONTEXT.md: confirmation) — the one gesture
/// that writes (ARCHITECTURE.md §6). Creates a pending Stage ([CALSYNC-8])
/// or links the event onto a Stage the user already tracks ([CALSYNC-9]);
/// several candidates get the picker ([CALSYNC-6]).
struct StageProposalSheet: View {
    enum Mode: Hashable {
        case create
        case link
    }

    @Bindable var store: CalendarSyncStore
    let proposal: StageProposal

    @Environment(\.dismiss) private var dismiss
    @State private var candidateID: PersistentIdentifier?
    @State private var mode: Mode = .create
    /// Starts from the kind guess (decisions/0005); nil means the user must
    /// pick before confirming ([CALSYNC-16]).
    @State private var kind: StageKind?
    @State private var stageID: PersistentIdentifier?
    /// The possible-interview fields ([CALSYNC-26]): company starts from the
    /// guess ([CALSYNC-24], [CALSYNC-25]) and stays editable; the calendar
    /// knows no role title, so that field starts blank.
    @State private var company: String
    @State private var roleTitle: String = ""

    init(store: CalendarSyncStore, proposal: StageProposal) {
        self.store = store
        self.proposal = proposal
        _candidateID = State(initialValue: proposal.candidates.first?.persistentModelID)
        _kind = State(initialValue: proposal.kindGuess)
        _company = State(initialValue: proposal.companyGuess ?? "")
    }

    private var candidate: Application? {
        proposal.candidates.first { $0.persistentModelID == candidateID }
    }

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canConfirm: Bool {
        if proposal.isPossibleInterview {
            return kind != nil && !isBlank(company) && !isBlank(roleTitle)
        }
        guard candidate != nil else { return false }
        switch mode {
        case .create: return kind != nil
        case .link: return selectedStage != nil
        }
    }

    private var selectedStage: Stage? {
        candidate?.orderedStages.first { $0.persistentModelID == stageID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(proposal.event.title)
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.ink)
                Text(proposal.event.start.formatted(date: .complete, time: .shortened))
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                if let link = proposal.meetingLink {
                    Text(link.absoluteString)
                        .font(.caption)
                        .foregroundStyle(Color.skyline)
                        .lineLimit(1)
                }
            }

            Form {
                if proposal.isPossibleInterview {
                    // The calendar-first confirm ([CALSYNC-26]): one gesture
                    // creates the applied Application and its event-linked
                    // Stage — nothing exists until Confirm.
                    TextField("Company", text: $company)
                    TextField("Role title", text: $roleTitle)
                    Picker("Kind", selection: $kind) {
                        Text("Choose…").tag(StageKind?.none)
                        ForEach(StageKind.knownCases, id: \.self) { known in
                            Text(known.label).tag(Optional(known))
                        }
                    }
                } else if proposal.candidates.count > 1 {
                    Picker("Application", selection: $candidateID) {
                        ForEach(proposal.candidates) { application in
                            Text("\(application.company) — \(application.roleTitle)")
                                .tag(Optional(application.persistentModelID))
                        }
                    }
                } else if let candidate {
                    LabeledContent("Application") {
                        Text("\(candidate.company) — \(candidate.roleTitle)")
                            .foregroundStyle(Color.ink)
                    }
                }

                if !proposal.isPossibleInterview {
                    Picker("Add as", selection: $mode) {
                        Text("New stage").tag(Mode.create)
                        Text("Existing stage").tag(Mode.link)
                    }
                    .pickerStyle(.segmented)
                    .disabled((candidate?.orderedStages.isEmpty) ?? true)

                    switch mode {
                    case .create:
                        Picker("Kind", selection: $kind) {
                            Text("Choose…").tag(StageKind?.none)
                            ForEach(StageKind.knownCases, id: \.self) { known in
                                Text(known.label).tag(Optional(known))
                            }
                        }
                    case .link:
                        Picker("Stage", selection: $stageID) {
                            Text("Choose…").tag(PersistentIdentifier?.none)
                            ForEach(candidate?.orderedStages ?? []) { stage in
                                Text(stageRowLabel(for: stage))
                                    .tag(Optional(stage.persistentModelID))
                            }
                        }
                    }
                }
            }
            .formStyle(.columns)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Confirm") { confirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canConfirm)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
        .background(Color.paper)
    }

    private func stageRowLabel(for stage: Stage) -> String {
        guard let scheduledAt = stage.scheduledAt else { return stage.kind.label }
        return "\(stage.kind.label) — \(scheduledAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func confirm() {
        do {
            if proposal.isPossibleInterview {
                guard let kind else { return }
                try store.confirmCreate(
                    proposal, company: company, roleTitle: roleTitle, kind: kind
                )
                dismiss()
                return
            }
            guard let candidate else { return }
            switch mode {
            case .create:
                guard let kind else { return }
                try store.confirm(proposal, application: candidate, kind: kind)
            case .link:
                guard let selectedStage else { return }
                try store.link(proposal, to: selectedStage)
            }
            dismiss()
        } catch {
            // The store's save failed; leave the sheet open so nothing is
            // silently lost.
        }
    }
}

#Preview {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline, service: FixtureCalendarSyncService()
    )
    let application = Application(
        company: "Acme", roleTitle: "Engineer", jobDescription: "JD",
        status: .applied, appliedAt: .now
    )
    return StageProposalSheet(
        store: store,
        proposal: StageProposal(
            event: CalendarEvent(
                identifier: "evt-1",
                title: "Acme system design",
                start: .now.addingTimeInterval(86_400),
                location: "https://acme.zoom.us/j/123"
            ),
            candidates: [application],
            meetingLink: URL(string: "https://acme.zoom.us/j/123"),
            kindGuess: .systemDesign
        )
    )
}

#Preview("Possible interview") {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline, service: FixtureCalendarSyncService()
    )
    return StageProposalSheet(
        store: store,
        proposal: StageProposal(
            event: CalendarEvent(
                identifier: "evt-2",
                title: "Interview with Hooli",
                start: .now.addingTimeInterval(-86_400),
                location: "https://hooli.zoom.us/j/9"
            ),
            candidates: [],
            meetingLink: URL(string: "https://hooli.zoom.us/j/9"),
            kindGuess: nil,
            companyGuess: "Hooli"
        )
    )
}
