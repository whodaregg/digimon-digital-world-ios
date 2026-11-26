import Foundation

/// Translate display text at presentation time, preserving old journals and stable persisted identifiers.
public enum GameLocalization {
    private struct Entry: Decodable { let source: String; let values: [String:String] }
    private struct Catalog: Decodable { let version: Int; let entries: [Entry] }
    private struct Pattern { let source: String; let regex: NSRegularExpression; let tokens: [String] }
    private static let entries: [Entry] = {
        guard let url = Bundle.module.url(forResource: "translations",withExtension: "json"),
              let data = try? Data(contentsOf: url),let catalog = try? JSONDecoder().decode(Catalog.self,from: data) else { return [] }
        return catalog.entries
    }()
    private static let exact = Dictionary(entries.map { ($0.source,$0.values) },uniquingKeysWith: { _,new in new })
    private static let patterns: [Pattern] = entries.filter { $0.source.contains("{0}") }.sorted { $0.source.count > $1.source.count }.compactMap { entry in
        let source = entry.source
        var expression = NSRegularExpression.escapedPattern(for: source)
        var tokens: [String] = []
        for index in 0..<32 {
            let token = "{\(index)}"
            if source.contains(token) {
                tokens.append(token)
                expression = expression.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: token),with: "(.*?)")
            }
        }
        guard let regex = try? NSRegularExpression(pattern: "\\A"+expression+"\\z",options: .dotMatchesLineSeparators) else { return nil }
        return Pattern(source: source,regex: regex,tokens: tokens)
    }
    public static func text(_ source: String,language: AppLanguage) -> String {
        if let translated = exact[source]?[language.rawValue] { return translated }
        guard language != .simplified else { return source }
        guard source.range(of: "[\\p{Han}]",options: .regularExpression) != nil else { return source }
        let range = NSRange(source.startIndex...,in: source)
        for pattern in patterns {
            guard let match = pattern.regex.firstMatch(in: source,range: range),let translated = exact[pattern.source]?[language.rawValue] else { continue }
            var result = translated
            for (index,token) in pattern.tokens.enumerated() {
                if let r = Range(match.range(at: index+1),in: source) {
                    let captured = String(source[r])
                    result = result.replacingOccurrences(of: token,with: captured == source ? captured : text(captured,language: language))
                }
            }
            return result
        }
        // Joined call messages and old log entries can contain several independently translated sentences.
        if source.contains("\n") { return source.components(separatedBy: "\n").map { text($0,language: language) }.joined(separator: "\n") }
        return source
    }
    public static var coverage: Int { entries.count }
}
