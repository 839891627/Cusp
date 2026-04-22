import Foundation

public enum SubscriptionParser {
    public enum Error: Swift.Error, Equatable {
        case noNodesFound
        case invalidSubscriptionPayload
    }

    public static func parseConfigurations(from text: String) throws -> [ShadowsocksConfiguration] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let directLinks = extractSSURLs(from: trimmed)
        if !directLinks.isEmpty {
            return try directLinks.map(SSURLParser.parse)
        }

        let compact = trimmed.replacingOccurrences(of: "\r", with: "")
        if let data = decodeBase64URLString(compact),
           let decoded = String(data: data, encoding: .utf8) {
            let decodedLinks = extractSSURLs(from: decoded)
            if !decodedLinks.isEmpty {
                return try decodedLinks.map(SSURLParser.parse)
            }
        }

        let clashConfigurations = parseClashConfigurations(from: compact)
        if !clashConfigurations.isEmpty {
            return clashConfigurations
        }

        if trimmed.contains("ss://") {
            throw Error.invalidSubscriptionPayload
        }

        throw Error.noNodesFound
    }

    static func extractSSURLs(from text: String) -> [String] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { token -> String? in
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let range = trimmed.range(of: "ss://") else {
                    return nil
                }
                return String(trimmed[range.lowerBound...])
            }
            .filter { !$0.isEmpty }
    }

    private static func decodeBase64URLString(_ value: String) -> Data? {
        let normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - normalized.count % 4) % 4
        return Data(base64Encoded: normalized + String(repeating: "=", count: padding))
    }

    private static func parseClashConfigurations(from text: String) -> [ShadowsocksConfiguration] {
        let lines = text.components(separatedBy: .newlines)
        var configurations: [ShadowsocksConfiguration] = []
        var insideProxiesSection = false
        var currentBlock: [String: String] = [:]

        func flushCurrentBlock() {
            guard !currentBlock.isEmpty else {
                return
            }
            if let configuration = configuration(from: currentBlock) {
                configurations.append(configuration)
            }
            currentBlock = [:]
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "proxies:" {
                flushCurrentBlock()
                insideProxiesSection = true
                continue
            }

            guard insideProxiesSection else {
                continue
            }

            if trimmed.isEmpty {
                continue
            }

            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                flushCurrentBlock()
                insideProxiesSection = false
                continue
            }

            if let inlineMap = extractInlineProxyMap(from: trimmed) {
                flushCurrentBlock()
                if let configuration = configuration(from: inlineMap) {
                    configurations.append(configuration)
                }
                continue
            }

            if trimmed.hasPrefix("- ") {
                flushCurrentBlock()
                let remainder = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let (key, value) = parseKeyValue(remainder) {
                    currentBlock[key] = value
                }
                continue
            }

            if let (key, value) = parseKeyValue(trimmed) {
                currentBlock[key] = value
            }
        }

        flushCurrentBlock()
        return configurations
    }

    private static func extractInlineProxyMap(from trimmedLine: String) -> [String: String]? {
        guard trimmedLine.hasPrefix("- {"), trimmedLine.hasSuffix("}") else {
            return nil
        }

        let raw = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        return parseInlineMap(raw)
    }

    private static func parseInlineMap(_ text: String) -> [String: String] {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("{") {
            body.removeFirst()
        }
        if body.hasSuffix("}") {
            body.removeLast()
        }
        body = body.trimmingCharacters(in: .whitespacesAndNewlines)

        var result: [String: String] = [:]
        for entry in splitTopLevel(body, separator: ",") {
            if let (key, value) = parseKeyValue(entry) {
                result[key] = value
            }
        }
        return result
    }

    private static func parseKeyValue(_ text: String) -> (String, String)? {
        guard let index = firstTopLevelSeparator(in: text, separator: ":") else {
            return nil
        }

        let key = text[..<index]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let valueStart = text.index(after: index)
        let value = text[valueStart...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty, !value.isEmpty else {
            return nil
        }

        return (key, yamlScalarValue(from: value))
    }

    private static func firstTopLevelSeparator(in text: String, separator: Character) -> String.Index? {
        var quote: Character?
        var squareDepth = 0
        var curlyDepth = 0
        var previous: Character?

        for index in text.indices {
            let character = text[index]
            if let currentQuote = quote {
                if character == currentQuote && previous != "\\" {
                    quote = nil
                }
            } else {
                switch character {
                case "'", "\"":
                    quote = character
                case "[":
                    squareDepth += 1
                case "]":
                    squareDepth = max(0, squareDepth - 1)
                case "{":
                    curlyDepth += 1
                case "}":
                    curlyDepth = max(0, curlyDepth - 1)
                default:
                    break
                }

                if character == separator && squareDepth == 0 && curlyDepth == 0 {
                    return index
                }
            }

            previous = character
        }

        return nil
    }

    private static func splitTopLevel(_ text: String, separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var quote: Character?
        var squareDepth = 0
        var curlyDepth = 0
        var previous: Character?

        for character in text {
            if let currentQuote = quote {
                current.append(character)
                if character == currentQuote && previous != "\\" {
                    quote = nil
                }
                previous = character
                continue
            }

            switch character {
            case "'", "\"":
                quote = character
            case "[":
                squareDepth += 1
            case "]":
                squareDepth = max(0, squareDepth - 1)
            case "{":
                curlyDepth += 1
            case "}":
                curlyDepth = max(0, curlyDepth - 1)
            default:
                break
            }

            if character == separator && squareDepth == 0 && curlyDepth == 0 {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append(trimmed)
                }
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(character)
            }

            previous = character
        }

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        }

        return parts
    }

    private static func yamlScalarValue(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return trimmed
        }

        if (trimmed.hasPrefix("'") && trimmed.hasSuffix("'"))
            || (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) {
            let inner = trimmed.dropFirst().dropLast()
            return String(inner)
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }

        return trimmed
    }

    private static func configuration(from fields: [String: String]) -> ShadowsocksConfiguration? {
        guard
            let type = fields["type"]?.lowercased(),
            let host = fields["server"],
            let portValue = fields["port"],
            let port = Int(portValue)
        else {
            return nil
        }

        let remark = fields["name"]

        switch type {
        case "ss":
            guard let cipher = fields["cipher"], let password = fields["password"] else {
                return nil
            }
            return ShadowsocksConfiguration(
                host: host,
                port: port,
                method: cipher,
                password: password,
                remark: remark,
                protocolType: .shadowsocks,
                udp: parseBool(fields["udp"])
            )
        case "vless":
            guard let uuid = fields["uuid"] else {
                return nil
            }
            return ShadowsocksConfiguration(
                host: host,
                port: port,
                remark: remark,
                protocolType: .vless,
                uuid: uuid,
                tls: parseBool(fields["tls"]) ?? false,
                skipCertVerify: parseBool(fields["skip-cert-verify"]),
                flow: fields["flow"],
                clientFingerprint: fields["client-fingerprint"],
                serverName: fields["servername"] ?? fields["sni"],
                udp: parseBool(fields["udp"])
            )
        case "vmess":
            guard let uuid = fields["uuid"] else {
                return nil
            }
            let wsOptions = fields["ws-opts"].map(parseInlineMap) ?? [:]
            let wsHeaders = wsOptions["headers"].map(parseInlineMap) ?? [:]
            return ShadowsocksConfiguration(
                host: host,
                port: port,
                method: fields["cipher"] ?? "auto",
                remark: remark,
                protocolType: .vmess,
                uuid: uuid,
                tls: parseBool(fields["tls"]) ?? false,
                skipCertVerify: parseBool(fields["skip-cert-verify"]),
                serverName: fields["servername"] ?? fields["sni"],
                udp: parseBool(fields["udp"]),
                alterID: Int(fields["alterId"] ?? fields["alterID"] ?? ""),
                network: fields["network"],
                wsPath: wsOptions["path"],
                wsHost: wsHeaders["Host"] ?? wsHeaders["host"]
            )
        case "trojan":
            guard let password = fields["password"] else {
                return nil
            }
            return ShadowsocksConfiguration(
                host: host,
                port: port,
                password: password,
                remark: remark,
                protocolType: .trojan,
                tls: true,
                skipCertVerify: parseBool(fields["skip-cert-verify"]),
                serverName: fields["servername"] ?? fields["sni"],
                udp: parseBool(fields["udp"])
            )
        default:
            return nil
        }
    }

    private static func parseBool(_ value: String?) -> Bool? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }

        switch normalized {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }
}
