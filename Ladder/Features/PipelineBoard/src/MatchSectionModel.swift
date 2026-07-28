import Foundation
import SwiftData

/// The scan machinery and the review's semantics are Tailor's; this model
/// only drives them from the detail.
@MainActor
@Observable
final class MatchSectionModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case review
        case failed(JDScanError)
    }

    struct Summary: Equatable {
        var score: Int?
        var matchedTagNames: [String]
        var vocabularyGaps: [String]
        var scannedAt: Date
    }

    private(set) var phase: Phase = .idle
    private(set) var matchReview: MatchReviewModel?
    private(set) var confirmationNotes: [String] = []

    private let scanStore: JDScanStore
    private let application: Application

    init(
        application: Application,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.application = application
        scanStore = JDScanStore(
            keyStore: keyStore, bundle: bundle, makeIntelligence: makeIntelligence)
    }

    /// Any status, snapshot or not — deliberately unlike Create CV's gate
    /// ([PIPEBOARD-42]).
    static func offersMatchSection(jobDescription: String) -> Bool {
        !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func summary(of application: Application) -> Summary? {
        guard let match = application.match else { return nil }
        return Summary(
            score: match.score,
            matchedTagNames: match.matchedTags.map(\.name),
            vocabularyGaps: match.vocabularyGaps,
            scannedAt: match.scannedAt)
    }

    var summary: Summary? { Self.summary(of: application) }

    func scan() async {
        phase = .scanning
        matchReview = nil
        confirmationNotes = []
        await scanStore.scan(application)
        switch scanStore.phase {
        case .scanned:
            guard let match = application.match else {
                phase = .failed(.requestFailed(detail: "the scan stored no Match"))
                return
            }
            matchReview = MatchReviewModel(match: match, suggestions: scanStore.suggestions)
            phase = .review
        case .failed(let error):
            phase = .failed(error)
        case .idle, .scanning:
            phase = .failed(.requestFailed(detail: "the scan never completed"))
        }
    }

    func confirmReview() {
        guard phase == .review, let matchReview else { return }
        do {
            confirmationNotes = try MatchReviewConfirmation.apply(
                matchReview, to: application)
            self.matchReview = nil
            phase = .idle
        } catch {
            self.matchReview = nil
            phase = .failed(.requestFailed(detail: "saving the confirmed review failed"))
        }
    }

    func cancelReview() {
        matchReview = nil
        phase = .idle
    }

    func retry() async {
        await scan()
    }
}
