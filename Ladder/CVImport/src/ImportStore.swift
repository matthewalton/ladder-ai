import Foundation

/// One import runs at a time.
@MainActor
@Observable
final class ImportStore {
    enum Phase: Equatable {
        case idle
        case importing
        /// `review` is non-nil while in this phase.
        case review
        case replacing
        case replaced
        case failed(ImportError)
    }

    private(set) var phase: Phase = .idle
    private(set) var review: ImportReview?

    private let profileStore: ProfileStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` receives the stored API key — the live service in
    /// production, a fixture in tests and previews.
    init(
        profileStore: ProfileStore,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.profileStore = profileStore
        self.keyStore = keyStore
        self.bundle = bundle
        self.makeIntelligence = makeIntelligence
    }

    /// Import is a hard refresh (decisions/0007): onto an existing Profile
    /// the run must be confirmed before it starts — before extraction and
    /// before any paid service call. The view gates on this and shows the
    /// dialog; declining simply never calls `startImport`.
    var needsReplaceConfirmation: Bool {
        profileStore.profile != nil
    }

    func startImport(of url: URL) async {
        // No stored key means no live run — never a fixture fallback.
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .importing
        review = nil
        do {
            let text: String
            do {
                text = try FileTextExtractor.extractText(from: url)
            } catch TextExtractionError.unsupportedFileType {
                throw ImportError.unsupportedFileType
            } catch {
                throw ImportError.extractionFailed
            }
            let prompt = try ImportPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let response: Data
            do {
                response = try await service.complete(
                    IntelligenceRequest(prompt: prompt, payload: text)
                )
            } catch AnthropicIntelligenceService.LiveServiceError.truncated {
                // A length problem, not a transport one — retrying truncates again.
                throw ImportError.responseTruncated
            } catch {
                throw ImportError.requestFailed(detail: Self.requestFailureDetail(for: error))
            }
            var proposal = try ImportProposal(json: response)
            // Contact detection (decisions/0009): detected email/phone/link
            // override the model's proposal before the review is shown.
            let detected = DetectedContact.detect(in: text, fileURL: url)
            proposal.identity.contact = detected.overriding(proposal.identity.contact)
            review = ImportReview(proposal: proposal)
            phase = .review
        } catch {
            // Only a missing bundled prompt reaches this fallback — a
            // packaging bug; every other failure is already an ImportError.
            phase = .failed(
                (error as? ImportError)
                    ?? .proposalInvalid(reason: "the import prompt could not be loaded from the app bundle")
            )
        }
    }

    private static func requestFailureDetail(for error: Error) -> String {
        switch error {
        case AnthropicIntelligenceService.LiveServiceError.httpFailure(let status):
            "HTTP \(status)"
        case AnthropicIntelligenceService.LiveServiceError.emptyResponse:
            "the service returned an empty response"
        default:
            (error as NSError).localizedDescription
        }
    }

    /// The hard refresh ([CVIMPORT-20], [CVIMPORT-21]): the included items
    /// become the Profile's entire content through the replace pathway —
    /// creating the Profile when none exists. Nothing lands before this
    /// confirmation; not-imported sections are never written anywhere.
    func confirmReview() {
        guard phase == .review, let review else { return }
        phase = .replacing
        do {
            try profileStore.replaceProfile(with: Self.replacement(from: review))
            self.review = nil
            phase = .replaced
        } catch {
            // Unreachable in practice: the proposal already rejected an
            // empty name at validation ([CVIMPORT-23]).
            self.review = nil
            phase = .failed(.proposalInvalid(reason: "the CV's name is missing"))
        }
    }

    private static func replacement(from review: ImportReview) -> ProfileReplacement {
        func point(_ achievement: ReviewedAchievement) -> ReplacementPoint {
            ReplacementPoint(
                title: achievement.proposed.title,
                text: achievement.proposed.text,
                impactMetric: achievement.proposed.impactMetric,
                tech: achievement.proposed.tech,
                skills: achievement.skills.filter(\.included).map(\.name)
            )
        }
        return ProfileReplacement(
            name: review.identity.name,
            headline: review.identity.headline ?? "",
            contact: ContactInfo(
                email: review.identity.contact.email ?? "",
                phone: review.identity.contact.phone ?? "",
                location: review.identity.contact.location ?? "",
                link: review.identity.contact.link ?? ""
            ),
            roles: review.roles.filter(\.included).map { role in
                ReplacementRole(
                    company: role.proposed.company,
                    title: role.proposed.title,
                    start: role.proposed.start,
                    end: role.proposed.end,
                    achievements: role.achievements.filter(\.included).map(point)
                )
            },
            education: review.education.filter(\.included).map { education in
                ReplacementEducation(
                    institution: education.proposed.institution,
                    qualification: education.proposed.qualification,
                    start: education.proposed.start,
                    end: education.proposed.end,
                    detail: education.proposed.detail ?? ""
                )
            },
            projects: review.projects.filter(\.included).map { project in
                ReplacementProject(
                    name: project.proposed.name,
                    link: project.proposed.link ?? "",
                    summary: project.proposed.summary ?? "",
                    details: project.proposed.description ?? "",
                    skills: project.skills.filter(\.included).map(\.name)
                )
            },
            interests: review.interests.filter(\.included).map(\.name)
        )
    }

    func reset() {
        phase = .idle
        review = nil
    }
}
