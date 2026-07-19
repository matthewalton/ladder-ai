import Foundation

/// The prompt is versioned on disk — never an inline string.
enum TailorPrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "tailor", withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
