import Foundation

/// Carried into the repair request so the service is told what to fix.
struct JobDetailsValidationFailure: Error, Equatable {
    var reason: String
}

/// The structured essentials of one job posting ([PIPEBOARD-35]): what the
/// extraction must produce before an Application can be created from it.
struct JobDetailsResult: Equatable, Sendable {
    var company: String
    var roleTitle: String
    var jobDescription: String

    private struct Schema: Decodable {
        var company: String
        var roleTitle: String
        var jobDescription: String
    }

    init(json: Data) throws {
        let json = FencedJSON.stripped(from: json)
        let schema: Schema
        do {
            schema = try JSONDecoder().decode(Schema.self, from: json)
        } catch {
            throw JobDetailsValidationFailure(
                reason: "The response did not match the job-details schema: \(error)"
            )
        }
        func trimmedNonEmpty(_ value: String, field: String) throws -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw JobDetailsValidationFailure(reason: "\(field) must not be empty")
            }
            return trimmed
        }
        company = try trimmedNonEmpty(schema.company, field: "company")
        roleTitle = try trimmedNonEmpty(schema.roleTitle, field: "roleTitle")
        _ = try trimmedNonEmpty(schema.jobDescription, field: "jobDescription")
        // The JD keeps its own whitespace shape — only the guard trims.
        jobDescription = schema.jobDescription
    }
}
