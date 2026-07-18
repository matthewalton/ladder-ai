import Foundation

/// Loads the versioned tailor prompt from the bundled `Prompts/` folder —
/// never an inline string (SPEC.md [TAILOR-5], CLAUDE.md).
enum TailorPrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "tailor", withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
