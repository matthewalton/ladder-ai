import Foundation

enum JobImportError: Error, Equatable {
    case fetchFailed
    case noExtractableText
    case apiKeyRequired
    case resultInvalid
    case requestFailed
}

/// One import at a time: posting in — link or PDF — draft Application out
/// ([PIPEBOARD-35..40]). Any failure creates nothing.
@MainActor
@Observable
final class JobImportStore {
    enum Phase: Equatable {
        case idle
        /// The repair request runs in this phase too — it never gets its own.
        case running
        case failed(JobImportError)
        case created(Application)
    }

    private(set) var phase: Phase = .idle

    private let pipelineStore: PipelineStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// Injected so import criteria run offline ([PIPEBOARD-26]'s stance).
    var fetchLinkData: (URL) async throws -> Data = PipelineStore.fetchOverHTTP

    /// `makeIntelligence` is the seam tests and previews use to substitute a
    /// fixture service.
    init(
        pipelineStore: PipelineStore,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.pipelineStore = pipelineStore
        self.keyStore = keyStore
        self.bundle = bundle
        self.makeIntelligence = makeIntelligence
    }

    func importPosting(fromLink url: URL) async {
        // No key refuses before any fetch or service call ([PIPEBOARD-38],
        // the [TAILOR-4] stance).
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .running
        let data: Data
        do {
            data = try await fetchLinkData(url)
        } catch {
            phase = .failed(.fetchFailed)
            return
        }
        let text: String
        do {
            // A JobPosting structured-data block wins over whole-page text —
            // it is the posting without the nav and footer ([PIPEBOARD-37]).
            text =
                try JobPostingStructuredData.text(fromHTMLData: data)
                ?? FileTextExtractor.extractText(fromFetchedData: data)
        } catch {
            phase = .failed(.noExtractableText)
            return
        }
        await structureAndCreate(postingText: text, source: url.absoluteString, key: key)
    }

    func importPosting(fromFile url: URL) async {
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .running
        let text: String
        do {
            text = try FileTextExtractor.extractText(from: url)
        } catch {
            phase = .failed(.noExtractableText)
            return
        }
        await structureAndCreate(postingText: text, source: url.lastPathComponent, key: key)
    }

    /// LLM structuring always, both doors (decisions/0008): the posting text
    /// is the payload, the validated result is the Application.
    private func structureAndCreate(postingText: String, source: String, key: String) async {
        do {
            let prompt = try JobDetailsPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let request = IntelligenceRequest(prompt: prompt, payload: postingText)
            let response = try await service.complete(request)
            let result: JobDetailsResult
            do {
                result = try JobDetailsResult(json: response)
            } catch let failure as JobDetailsValidationFailure {
                // Exactly one repair attempt ([PIPEBOARD-39]); a repair
                // response failing validation fails the import.
                let repair = IntelligenceRequest(
                    prompt: prompt,
                    payload: Self.repairPayload(
                        original: postingText, response: response, failure: failure
                    )
                )
                let repairResponse = try await service.complete(repair)
                result = try JobDetailsResult(json: repairResponse)
            }
            let application = try pipelineStore.createApplication(
                company: result.company, roleTitle: result.roleTitle,
                jobDescription: result.jobDescription,
                source: source, notes: "", appliedAt: nil
            )
            phase = .created(application)
        } catch is JobDetailsValidationFailure {
            phase = .failed(.resultInvalid)
        } catch is PipelineStoreError {
            // Validation guarantees non-blank fields, so this is defensive.
            phase = .failed(.resultInvalid)
        } catch {
            // A missing bundled prompt or a transport failure — not an
            // invalid result.
            phase = .failed(.requestFailed)
        }
    }

    private static func repairPayload(
        original: String, response: Data, failure: JobDetailsValidationFailure
    ) -> String {
        """
        Your previous response failed validation.

        Failure: \(failure.reason)

        Your previous response was:
        \(String(decoding: response, as: UTF8.self))

        Return corrected JSON for the original posting text, which follows.

        \(original)
        """
    }

    func reset() {
        phase = .idle
    }
}
