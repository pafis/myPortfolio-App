import Foundation

enum KeywordValidation {
    /// Normalizes and validates a topic keyword.
    /// - Returns: A normalized keyword (exactly two words) or `nil` if invalid.
    static func normalizeTwoWordKeyword(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("-") { value.removeFirst() }
        if value.hasPrefix("•") { value.removeFirst() }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip common punctuation and fence artifacts.
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`[](){}<>.:;!?") )
        guard !value.isEmpty else { return nil }

        // Exactly 2 words.
        let words = value.split(whereSeparator: { $0.isWhitespace }).filter { !$0.isEmpty }
        guard words.count == 2 else { return nil }
        guard value.count <= 32 else { return nil }

        // Guard against JSON fragments like keyword":"Something
        let lowered = value.lowercased()
        if lowered == "keyword" || lowered == "question" {
            return nil
        }
        if lowered.contains("\"keyword\"") || lowered.contains("keyword\"") || lowered.contains("\"question\"") {
            return nil
        }
        if value.contains(":") || value.contains("{") || value.contains("}") {
            return nil
        }

        // Reject sentences/questions.
        if value.contains("?") { return nil }
        if value.contains(".") { return nil }

        // Normalize internal whitespace to single spaces.
        value = words.map { String($0) }.joined(separator: " ")

        // Allow only letters, digits, and spaces.
        let allowed = CharacterSet.letters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: " "))
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        return value
    }
}
