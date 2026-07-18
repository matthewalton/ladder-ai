import Foundation

/// Loads the versioned import prompt from the bundled `Prompts/` folder —
/// never an inline string (SPEC.md [CVIMPORT-13], CLAUDE.md).
enum ImportPrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "import", withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
