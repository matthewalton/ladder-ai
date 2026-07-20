import SwiftUI

/// The check's results, shown once per check (decisions/0008): proposals
/// prominent on top, everything else behind the collapsed disclosure.
/// Reviewing never writes — confirmation stays the only write gesture —
/// and closing discards the other events.
struct CheckResultsSheet: View {
    @Bindable var store: CalendarSyncStore
    @State private var reviewing: StageProposal?
    @State private var isShowingOthers = false
    @State private var filterText = ""

    @Environment(\.dismiss) private var dismiss

    private var filteredOthers: [CalendarEvent] {
        OtherEventsFilter.filtered(store.otherEvents, titleContains: filterText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar check results")
                .font(.trailNarrative(.headline))
                .foregroundStyle(Color.inkSoft)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if store.proposals.isEmpty {
                        Text("Nothing in this check looked like an interview.")
                            .font(.callout)
                            .foregroundStyle(Color.inkSoft)
                    } else {
                        ForEach(store.proposals) { proposal in
                            ProposalRow(
                                proposal: proposal,
                                onReview: { reviewing = proposal },
                                onDismiss: { try? store.dismiss(proposal) }
                            )
                        }
                    }

                    if !store.otherEvents.isEmpty {
                        DisclosureGroup(isExpanded: $isShowingOthers) {
                            otherEventsList
                        } label: {
                            Text("Other events (\(store.otherEvents.count))")
                                .font(.callout)
                                .foregroundStyle(Color.inkSoft)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 320)
        .background(Color.paper)
        .sheet(item: $reviewing) { proposal in
            StageProposalSheet(store: store, proposal: proposal)
        }
    }

    private var otherEventsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Filter by title", text: $filterText)
                .textFieldStyle(.roundedBorder)
            if filteredOthers.isEmpty {
                Text("No event title matches the filter.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            } else {
                ForEach(filteredOthers) { event in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .foregroundStyle(Color.ink)
                            Text(
                                event.start
                                    .formatted(date: .abbreviated, time: .shortened)
                            )
                            .font(.caption)
                            .foregroundStyle(Color.inkSoft)
                        }
                        Spacer()
                        Button("Review…") { reviewing = store.proposal(for: event) }
                    }
                    .padding(10)
                    .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.top, 6)
    }
}

/// One proposal, the same row on the bar and in the check-results sheet.
struct ProposalRow: View {
    let proposal: StageProposal
    let onReview: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(proposal.event.title)
                    .foregroundStyle(Color.ink)
                Text(
                    proposal.event.start
                        .formatted(date: .abbreviated, time: .shortened)
                )
                .font(.caption)
                .foregroundStyle(Color.inkSoft)
            }
            Spacer()
            if proposal.isPossibleInterview {
                Text("Possible interview")
                    .font(.caption)
                    .foregroundStyle(Color.skyline)
            }
            if let guess = proposal.kindGuess {
                Text(guess.label)
                    .font(.caption)
                    .foregroundStyle(Color.pine)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.pineTint, in: Capsule())
            }
            Button("Review…", action: onReview)
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.inkSoft)
        }
        .padding(10)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let pipeline = PipelineStore(container: try! ProfileStore.container(inMemory: true))
    let store = CalendarSyncStore(
        pipeline: pipeline,
        service: FixtureCalendarSyncService(events: [
            CalendarEvent(
                identifier: "evt-1",
                title: "Interview with Hooli",
                start: .now.addingTimeInterval(86_400),
                location: "https://hooli.zoom.us/j/9"
            ),
            CalendarEvent(
                identifier: "evt-2",
                title: "Coffee with Jane",
                start: .now.addingTimeInterval(3_600)
            ),
            CalendarEvent(
                identifier: "evt-3",
                title: "Team standup",
                start: .now.addingTimeInterval(7_200)
            ),
        ])
    )
    return CheckResultsSheet(store: store)
        .task { await store.check() }
}
