import SwiftUI
import UniformTypeIdentifiers

struct ImportCVView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: ImportStore
    @State private var isPickingFile = false

    /// Live by default; tests and previews inject fakes — production never
    /// falls back to fixtures.
    init(
        profileStore: ProfileStore,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil
    ) {
        if let makeIntelligence {
            _store = State(initialValue: ImportStore(
                profileStore: profileStore, keyStore: keyStore, makeIntelligence: makeIntelligence
            ))
        } else {
            _store = State(initialValue: ImportStore(
                profileStore: profileStore, keyStore: keyStore
            ))
        }
    }

    private static let docxType = UTType(filenameExtension: "docx") ?? .data

    var body: some View {
        Group {
            switch store.phase {
            case .idle:
                dropZone
            case .importing:
                progress("Reading your CV…")
            case .review:
                if let review = store.review {
                    ImportReviewView(
                        review: review,
                        onCancel: { store.reset() },
                        onConfirm: { store.confirmReview() }
                    )
                }
            case .merging:
                progress("Adding to your Profile…")
            case .merged:
                merged
            case .failed(let error):
                failed(error)
            }
        }
        .frame(minWidth: 560, minHeight: 440)
        .background(Color.paper)
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.document")
                .font(.largeTitle)
                .foregroundStyle(Color.pine)
            Text("Drop your CV here")
                .font(.title3)
                .foregroundStyle(Color.ink)
            Text("PDF or Word (.docx). You review every item before anything is added.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)
            Button("Choose file…") {
                isPickingFile = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pine)
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.inkSoft)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            importFile(at: url)
            return true
        }
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.pdf, Self.docxType]
        ) { result in
            if case .success(let url) = result {
                importFile(at: url)
            }
        }
    }

    private func importFile(at url: URL) {
        Task {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            await store.startImport(of: url)
        }
    }

    private func progress(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var merged: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Color.pine)
            Text("Added to your Profile.")
                .font(.trailNarrative(.title2))
                .foregroundStyle(Color.ink)
            Text("Everything you confirmed is on file — ready for tailoring.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.pine)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failed(_ error: ImportError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color.clay)
            Text(message(for: error))
                .font(.callout)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            HStack {
                if error == .apiKeyRequired {
                    SettingsLink {
                        Text("Open Settings…")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
                    Button("Close") { dismiss() }
                } else {
                    Button("Try again") { store.reset() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pine)
                    Button("Close") { dismiss() }
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func message(for error: ImportError) -> String {
        switch error {
        case .profileRequired:
            "Create your Profile first — import adds to it, it never starts one."
        case .unsupportedFileType:
            "That file isn't a PDF or Word document (.docx)."
        case .extractionFailed:
            "No text could be read from that file. If it's a scanned CV, try an exported PDF instead."
        case .apiKeyRequired:
            "Importing needs your Anthropic API key. Add it in Settings — it's stored only in your Keychain."
        case .requestFailed(let detail):
            "The import request couldn't be completed (\(detail)). Check your connection and try again."
        case .responseTruncated:
            "The response was cut off at the model's length limit — your CV may be too long to import whole. Trying again won't help; try a shorter version of the CV."
        case .proposalInvalid(let reason):
            "The proposal didn't come back in a shape Ladder could read — \(reason). Nothing was changed."
        }
    }
}

struct ImportReviewView: View {
    @Bindable var review: ImportReview
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(review.roles) { role in
                    ReviewedRoleSection(role: role)
                }
                if !review.notImportedSections.isEmpty {
                    Section("Not imported") {
                        ForEach(review.notImportedSections, id: \.name) { section in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.name)
                                    .font(.headline)
                                    .foregroundStyle(Color.inkSoft)
                                Text(section.content)
                                    .font(.callout)
                                    .foregroundStyle(Color.inkSoft)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Divider()
            HStack {
                Text("Only what you keep is added — your Profile stays yours.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Add to Profile", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
            }
            .padding(12)
            .background(Color.paperRaised)
        }
    }
}

private struct ReviewedRoleSection: View {
    @Bindable var role: ReviewedRole

    var body: some View {
        Section {
            ForEach(role.achievements) { achievement in
                ReviewedAchievementRow(achievement: achievement)
                    .disabled(!role.included)
                    .opacity(role.included ? 1 : 0.4)
            }
        } header: {
            Toggle(isOn: $role.included) {
                Text("\(role.proposed.title) — \(role.proposed.company)")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
            }
            .toggleStyle(.checkbox)
        }
    }
}

private struct ReviewedAchievementRow: View {
    @Bindable var achievement: ReviewedAchievement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $achievement.included) {
                Text(achievement.proposed.text)
                    .font(.body)
                    .foregroundStyle(Color.ink)
            }
            .toggleStyle(.checkbox)

            if let metric = achievement.proposed.impactMetric {
                Text(metric)
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            }

            if !achievement.skills.isEmpty {
                HStack(spacing: 4) {
                    ForEach(achievement.skills) { skill in
                        ReviewedSkillChip(skill: skill)
                            .disabled(!achievement.included)
                    }
                }
                .opacity(achievement.included ? 1 : 0.4)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Rendering only — the SkillTag is created at merge time.
private struct ReviewedSkillChip: View {
    @Bindable var skill: ReviewedSkill

    var body: some View {
        Button {
            skill.included.toggle()
        } label: {
            Text(skill.name)
                .font(.caption)
                .foregroundStyle(skill.included ? Color.ink : Color.inkSoft)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    skill.included ? Color.pineTint : Color.mist,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Drop zone") {
    let profileStore = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    return ImportCVView(
        profileStore: profileStore,
        keyStore: InMemoryAPIKeyStore(key: "preview-key"),
        makeIntelligence: { _ in FixtureIntelligenceService.importFixture() }
    )
}

#Preview("Review") {
    let json = Data("""
    {
      "roles": [
        {
          "company": "Acme",
          "title": "Senior Engineer",
          "start": "2021-04",
          "end": null,
          "achievements": [
            {
              "text": "Cut CI build times across every product target",
              "impactMetric": "reduced build time 40%",
              "tech": ["Swift", "Bazel"],
              "skills": ["Swift", "CI"]
            }
          ]
        }
      ],
      "notImportedSections": [
        { "name": "Education", "content": "BSc Computer Science, University of Leeds" }
      ]
    }
    """.utf8)
    let review = ImportReview(proposal: try! ImportProposal(json: json))
    return ImportReviewView(review: review, onCancel: {}, onConfirm: {})
        .frame(width: 560, height: 440)
}
