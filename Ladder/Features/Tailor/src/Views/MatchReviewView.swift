import SwiftData
import SwiftUI

struct MatchReviewView: View {
    @Bindable var model: MatchReviewModel
    var onCancel: () -> Void
    var onContinue: () -> Void
    var continueLabel = "Continue to tailoring"

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Match score") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let score = model.score {
                            Text("\(score)%")
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(Color.pine)
                                .contentTransition(.numericText())
                            Text("of the job's asks match your tag vocabulary")
                                .font(.callout)
                                .foregroundStyle(Color.inkSoft)
                        } else {
                            Text("No vocabulary asks found in this job description.")
                                .font(.callout)
                                .foregroundStyle(Color.inkSoft)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if !model.matchedTagNames.isEmpty {
                    Section("Matched tags") {
                        Text(model.matchedTagNames.joined(separator: "  ·  "))
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                            .padding(.vertical, 2)
                    }
                }
                if !model.vocabularyGaps.isEmpty {
                    Section("Vocabulary gaps") {
                        ForEach(model.vocabularyGaps, id: \.self) { gap in
                            Label {
                                Text(gap)
                                    .font(.callout)
                                    .foregroundStyle(Color.ink)
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.clay)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                if !model.suggestions.isEmpty {
                    Section("Suggested vocabulary changes") {
                        ForEach($model.suggestions) { $item in
                            SuggestionRow(item: $item)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Divider()
            HStack {
                Text("Accepted suggestions land in your tag pool — nothing changes until you continue.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                Button("Cancel", action: onCancel)
                Button(continueLabel, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
            }
            .padding(12)
            .background(Color.paperRaised)
        }
    }
}

private struct SuggestionRow: View {
    @Binding var item: MatchReviewModel.SuggestionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $item.isAccepted) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.ink)
            }
            .toggleStyle(.checkbox)

            if let gap = item.proposal.resolves {
                Text("Dissolves the gap “\(gap)”")
                    .font(.caption)
                    .foregroundStyle(Color.pine)
                    .padding(.leading, 20)
            }
            if !item.proposal.rationale.isEmpty {
                Text(item.proposal.rationale)
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                    .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        switch item.proposal.change {
        case .attach(let tagName):
            "Attach “\(tagName)”"
        case .mint(let name):
            "New tag “\(name)”"
        case .alias(let alias, let onTagNamed):
            "Alias “\(alias)” on \(onTagNamed)"
        }
    }
}

#Preview("Match review") {
    let swift = SkillTag(name: "Swift")
    let kubernetes = SkillTag(name: "Kubernetes")
    let match = Match(
        matchedTags: [swift, kubernetes],
        vocabularyGaps: ["GraphQL", "Team leadership"])
    let model = MatchReviewModel(
        match: match,
        suggestions: [
            TagSuggestionProposal(
                id: 0, change: .mint(name: "GraphQL"),
                rationale: "The JD asks for GraphQL and the vocabulary has no entry for it.",
                resolves: "GraphQL"),
            TagSuggestionProposal(
                id: 1, change: .alias("team leadership", onTagNamed: "Leadership"),
                rationale: "The JD's 'team leadership' is the existing Leadership Tag by another name.",
                resolves: "Team leadership"),
            TagSuggestionProposal(
                id: 2, change: .alias("swift ui", onTagNamed: "SwiftUI"),
                rationale: "The JD writes SwiftUI as 'Swift UI'; the alias makes the ask resolve."),
        ])
    return MatchReviewView(model: model, onCancel: {}, onContinue: {})
        .frame(width: 640, height: 520)
        .background(Color.paper)
}
