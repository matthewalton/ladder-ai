import Foundation

enum JobImportError: Error, Equatable {
    case fetchFailed
    case noExtractableText
    case apiKeyRequired
    case resultInvalid
    case requestFailed
}

@MainActor
@Observable
final class JobImportStore {
    enum Phase: Equatable {
        case idle
        case running
        case failed(JobImportError)
        case created(Application)
    }

    private(set) var phase: Phase = .idle

    private let pipelineStore: PipelineStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    var fetchLinkData: (URL) async throws -> Data = PipelineStore.fetchOverHTTP

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
