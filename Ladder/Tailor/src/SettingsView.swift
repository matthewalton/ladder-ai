import SwiftUI

/// The stored key lives only in the Keychain and is never displayed back or
/// logged.
struct SettingsView: View {
    private let keyStore: any APIKeyStore

    @State private var enteredKey = ""
    @State private var hasStoredKey = false

    init(keyStore: any APIKeyStore = KeychainAPIKeyStore()) {
        self.keyStore = keyStore
    }

    var body: some View {
        Form {
            Section("Anthropic API key") {
                SecureField("sk-ant-…", text: $enteredKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save key") {
                        let key = enteredKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !key.isEmpty else { return }
                        try? keyStore.save(key: key)
                        enteredKey = ""
                        refresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
                    .disabled(enteredKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if hasStoredKey {
                        Button("Remove key") {
                            try? keyStore.deleteKey()
                            refresh()
                        }
                    }
                }
                Text(hasStoredKey
                    ? "A key is saved in your Keychain. Tailoring is on."
                    : "No key saved. Tailoring stays off until you add one.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                Text("Stored only in your macOS Keychain — never on disk, never logged. Used only when you run a tailor.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .onAppear(perform: refresh)
    }

    private func refresh() {
        hasStoredKey = ((try? keyStore.readKey()) ?? nil)?.isEmpty == false
    }
}

#Preview {
    SettingsView(keyStore: InMemoryAPIKeyStore())
}
