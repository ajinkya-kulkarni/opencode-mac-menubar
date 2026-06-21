import Foundation

struct ParsedCurlRequest {
    var url: URL
    var method: String
    var headers: [String: String]
    var body: Data?
}

enum CurlParseError: LocalizedError {
    case missingURL
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingURL: return "No URL found in request.curl."
        case .invalidURL(let raw): return "Invalid URL in request.curl: \(raw)"
        }
    }
}

final class CurlRequestParser {
    func parse(_ raw: String) throws -> ParsedCurlRequest {
        let tokens = tokenize(raw)
        var urlString: String?
        var method = "GET"
        var headers: [String: String] = [:]
        var body: Data?

        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            if token == "curl" {
                i += 1
                continue
            }
            if token.hasPrefix("http://") || token.hasPrefix("https://") {
                urlString = token
                i += 1
                continue
            }
            if token == "-X" || token == "--request" {
                if i + 1 < tokens.count { method = tokens[i + 1].uppercased() }
                i += 2
                continue
            }
            if token == "-H" || token == "--header" {
                if i + 1 < tokens.count {
                    let header = tokens[i + 1]
                    if let colon = header.firstIndex(of: ":") {
                        let name = String(header[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = String(header[header.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty { headers[name] = value }
                    }
                }
                i += 2
                continue
            }
            if token == "--data" || token == "--data-raw" || token == "--data-binary" || token == "-d" {
                if i + 1 < tokens.count {
                    body = tokens[i + 1].data(using: .utf8)
                    if method == "GET" { method = "POST" }
                }
                i += 2
                continue
            }
            i += 1
        }

        guard let urlString else { throw CurlParseError.missingURL }
        guard let url = URL(string: urlString) else { throw CurlParseError.invalidURL(urlString) }
        return ParsedCurlRequest(url: url, method: method, headers: headers, body: body)
    }

    private func tokenize(_ raw: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false

        for ch in raw {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" {
                escaped = true
                continue
            }
            if let q = quote {
                if ch == q {
                    quote = nil
                } else {
                    current.append(ch)
                }
                continue
            }
            if ch == "'" || ch == "\"" {
                quote = ch
                continue
            }
            if ch.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll()
                }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
