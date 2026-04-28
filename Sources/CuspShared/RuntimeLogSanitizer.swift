import Foundation

public enum RuntimeLogSanitizer {
    public static func sanitize(_ text: String) -> String {
        var sanitized = text
        sanitized = replace(pattern: #"(?i)([?&](?:token|password|passwd|secret|key)=)[^&\s]+"#, in: sanitized, with: "$1<redacted>")
        sanitized = replace(pattern: #"(?im)^(\s*(?:password|secret|uuid)\s*:\s*).+$"#, in: sanitized, with: "$1<redacted>")
        sanitized = replace(pattern: #"(?i)(Authorization:\s*Bearer\s+)[^\s]+"#, in: sanitized, with: "$1<redacted>")
        sanitized = replace(pattern: #"(?i)(Bearer\s+)[A-Za-z0-9._~+/\-=]+"#, in: sanitized, with: "$1<redacted>")
        return sanitized
    }

    private static func replace(pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
