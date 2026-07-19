import Foundation

/// The prompt ships as a bundled file, never an inline string.
enum ImportPrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "import", withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
