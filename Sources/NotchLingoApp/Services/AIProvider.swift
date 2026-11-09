import Foundation
import Security
import NotchLingoCore

protocol AIProvider {
    func complete(_ prompt: String) async throws -> String
}

enum KeyStore {
    private static let service = "org.notchlingo.ai"
    static func save(_ value: String, provider: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: provider]
        if value.isEmpty { SecItemDelete(query as CFDictionary); return }
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(value.utf8)] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query; insert[kSecValueData as String] = Data(value.utf8)
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let result = SecItemAdd(insert as CFDictionary, nil)
            guard result == errSecSuccess else { throw DeckError.invalid("Keychain error: \(result)") }
        } else if status != errSecSuccess { throw DeckError.invalid("Keychain error: \(status)") }
    }
    static func read(provider: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: provider,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Opt-in requests only. Providers never receive the deck library or review history automatically.
struct ConfiguredAIProvider: AIProvider {
    let preferences: Preferences
    func complete(_ prompt: String) async throws -> String {
        guard preferences.aiEnabled else { throw DeckError.invalid("AI is disabled. / Yapay zekâ kapalı.") }
        let provider = preferences.aiProvider
        let url: URL
        var body: [String: Any]
        let model = preferences.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw DeckError.invalid("Enter a model name. / Model adı girin.") }
        if provider == "openai" {
            url = URL(string: "https://api.openai.com/v1/responses")!
            body = ["model": model, "input": prompt, "store": false, "max_output_tokens": 3000]
        } else if provider == "anthropic" {
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            body = ["model": model, "max_tokens": 3000, "messages": [["role": "user", "content": prompt]]]
        } else {
            guard let base = URL(string: preferences.aiURL),
                  ["localhost", "127.0.0.1", "::1", "[::1]"].contains(base.host ?? ""),
                  ["http", "https"].contains(base.scheme ?? "") else {
                throw DeckError.invalid("Local Ollama must use localhost or a loopback address.")
            }
            url = base.appendingPathComponent("api/chat")
            body = ["model": model, "stream": false, "messages": [["role": "user", "content": prompt]]]
        }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if provider != "ollama" {
            guard let key = KeyStore.read(provider: provider), !key.isEmpty else { throw DeckError.invalid("Save an API key first. / Önce API anahtarını kaydedin.") }
            request.setValue(provider == "openai" ? "Bearer \(key)" : key,
                             forHTTPHeaderField: provider == "openai" ? "Authorization" : "x-api-key")
            if provider == "anthropic" { request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DeckError.invalid("AI request failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)). Check the model, key, and provider availability.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DeckError.invalid("Invalid AI response.") }
        let output: String
        if provider == "openai" {
            output = (json["output"] as? [[String: Any]] ?? []).flatMap { $0["content"] as? [[String: Any]] ?? [] }
                .filter { $0["type"] as? String == "output_text" }.compactMap { $0["text"] as? String }.joined(separator: "\n")
        } else if provider == "anthropic" {
            output = (json["content"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined(separator: "\n")
        } else { output = (json["message"] as? [String: Any])?["content"] as? String ?? "" }
        guard !output.isEmpty else { throw DeckError.invalid("The provider returned no text.") }
        return output
    }
}
