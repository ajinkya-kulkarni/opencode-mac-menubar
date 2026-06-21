import Foundation

final class UsageReader {
    typealias Completion = (UsageSnapshot) -> Void

    private let parser = UsageJSONParser()
    private let curlParser = CurlRequestParser()

    func load(completion: @escaping Completion) {
        ConfigPaths.ensureConfigDir()

        if FileManager.default.fileExists(atPath: ConfigPaths.requestCurl.path) {
            fetchFromCurl { [weak self] result in
                switch result {
                case .success(let snapshot):
                    self?.saveLastGood(snapshot)
                    completion(snapshot)
                case .failure(let error):
                    if let fallback = self?.readLocalUsage(source: "usage.json") {
                        var withError = fallback
                        withError.errorMessage = "Dashboard fetch failed: \(error.localizedDescription)"
                        completion(withError)
                    } else if let cached = self?.readCache(error: error.localizedDescription) {
                        completion(cached)
                    } else {
                        completion(.placeholder(error: error.localizedDescription))
                    }
                }
            }
        } else if let snapshot = readLocalUsage(source: "usage.json") {
            completion(snapshot)
        } else if let cached = readCache(error: nil) {
            completion(cached)
        } else {
            completion(.placeholder(error: "Create ~/.config/opencode-go-lite/usage.json or request.curl"))
        }
    }

    private func fetchFromCurl(completion: @escaping (Result<UsageSnapshot, Error>) -> Void) {
        do {
            let raw = try String(contentsOf: ConfigPaths.requestCurl, encoding: .utf8)
            let parsed = try curlParser.parse(raw)
            var request = URLRequest(url: parsed.url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)
            request.httpMethod = parsed.method
            request.httpBody = parsed.body
            for (name, value) in parsed.headers {
                request.setValue(value, forHTTPHeaderField: name)
            }

            URLSession.shared.dataTask(with: request) { [parser] data, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    completion(.failure(NetworkError.badStatus(http.statusCode)))
                    return
                }
                guard let data else {
                    completion(.failure(NetworkError.emptyResponse))
                    return
                }
                do {
                    let snapshot = try parser.parse(data: data, source: "dashboard cURL")
                    completion(.success(snapshot))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    private func readLocalUsage(source: String) -> UsageSnapshot? {
        guard FileManager.default.fileExists(atPath: ConfigPaths.usageJSON.path),
              let data = try? Data(contentsOf: ConfigPaths.usageJSON) else { return nil }
        return try? parser.parse(data: data, source: source)
    }

    private func readCache(error: String?) -> UsageSnapshot? {
        guard FileManager.default.fileExists(atPath: ConfigPaths.cacheJSON.path),
              let data = try? Data(contentsOf: ConfigPaths.cacheJSON),
              var snapshot = try? parser.parse(data: data, source: "last-good cache") else { return nil }
        snapshot.errorMessage = error.map { "Using cache. Last error: \($0)" }
        return snapshot
    }

    private func saveLastGood(_ snapshot: UsageSnapshot) {
        func entryPayload(_ entry: UsageEntry) -> [String: Any] {
            var out: [String: Any] = [:]
            if let percent = entry.percent { out["percent"] = percent }
            if let resetSeconds = entry.resetSeconds { out["resetSeconds"] = resetSeconds }
            return out
        }
        let payload: [String: Any] = [
            "rolling": entryPayload(snapshot.rolling),
            "weekly": entryPayload(snapshot.weekly),
            "monthly": entryPayload(snapshot.monthly)
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else { return }
        try? data.write(to: ConfigPaths.cacheJSON, options: [.atomic])
    }

    enum NetworkError: LocalizedError {
        case badStatus(Int)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "HTTP \(code)"
            case .emptyResponse: return "Empty dashboard response"
            }
        }
    }
}
