import Foundation

final class UsageJSONParser {
    func parse(data: Data, source: String) throws -> UsageSnapshot {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = json as? [String: Any] else {
            throw ParserError.notDictionary
        }

        let rolling = extractWindow(root: root, aliases: ["rolling", "roll", "5h", "5hour", "5_hour", "fivehour", "five_hour"], code: "R", label: "Rolling")
        let weekly = extractWindow(root: root, aliases: ["weekly", "week"], code: "W", label: "Weekly")
        let monthly = extractWindow(root: root, aliases: ["monthly", "month"], code: "M", label: "Monthly")

        if rolling.percent == nil && weekly.percent == nil && monthly.percent == nil {
            throw ParserError.noUsageWindowsFound
        }

        return UsageSnapshot(rolling: rolling, weekly: weekly, monthly: monthly, source: source, lastUpdated: Date(), errorMessage: nil)
    }

    private func extractWindow(root: [String: Any], aliases: [String], code: String, label: String) -> UsageEntry {
        let candidates = findCandidateObjects(in: root, aliases: aliases)
        for candidate in candidates {
            let percent = extractPercent(candidate)
            let reset = extractResetSeconds(candidate)
            if percent != nil || reset != nil {
                return UsageEntry(code: code, label: label, percent: percent, resetSeconds: reset)
            }
        }
        return UsageEntry(code: code, label: label, percent: nil, resetSeconds: nil)
    }

    private func findCandidateObjects(in any: Any, aliases: [String]) -> [[String: Any]] {
        var results: [[String: Any]] = []
        let normalizedAliases = Set(aliases.map { normalize($0) })

        func visit(_ value: Any) {
            if let dict = value as? [String: Any] {
                for (key, nested) in dict {
                    let nKey = normalize(key)
                    if normalizedAliases.contains(nKey) || normalizedAliases.contains(where: { nKey.contains($0) }) {
                        if let nestedDict = nested as? [String: Any] {
                            results.append(nestedDict)
                        } else {
                            results.append(dict)
                        }
                    }
                }

                let nameFields = ["name", "label", "window", "period", "interval", "type", "key"]
                for field in nameFields {
                    if let val = dict[field] as? String {
                        let normalizedVal = normalize(val)
                        if normalizedAliases.contains(normalizedVal) || normalizedAliases.contains(where: { normalizedVal.contains($0) }) {
                            results.append(dict)
                        }
                    }
                }

                for nested in dict.values { visit(nested) }
            } else if let array = value as? [Any] {
                for item in array { visit(item) }
            }
        }

        visit(any)
        return results
    }

    private func extractPercent(_ dict: [String: Any]) -> Int? {
        // Direct percentage fields first.
        let directKeys = [
            "percent", "percentage", "usagepercent", "usagepercentage", "usagepct", "pct",
            "usedpercent", "usedpercentage", "usedpct", "used"
        ]

        for (key, value) in flatten(dict) {
            let normalizedKey = normalize(key)
            if directKeys.contains(normalizedKey) || normalizedKey.contains("percent") || normalizedKey.contains("percentage") || normalizedKey.hasSuffix("pct") {
                if let number = numberValue(value) {
                    let pct = number <= 1.0 ? number * 100.0 : number
                    if pct >= 0 && pct <= 10_000 { return Int(pct.rounded()) }
                }
            }
        }

        // Compute percent from used/cost/spent and limit/cap if present.
        let flat = flatten(dict)
        let usedCandidate = flat.first { pair in
            let key = normalize(pair.0)
            return key.contains("used") || key.contains("usage") || key.contains("spent") || key.contains("cost")
        }.flatMap { numberValue($0.1) }

        let limitCandidate = flat.first { pair in
            let key = normalize(pair.0)
            return key.contains("limit") || key.contains("cap") || key.contains("max") || key.contains("entitlement") || key.contains("quota")
        }.flatMap { numberValue($0.1) }

        if let used = usedCandidate, let limit = limitCandidate, limit > 0 {
            return Int(((used / limit) * 100.0).rounded())
        }

        return nil
    }

    private func extractResetSeconds(_ dict: [String: Any]) -> TimeInterval? {
        let flat = flatten(dict)
        for (key, value) in flat {
            let normalizedKey = normalize(key)
            if normalizedKey.contains("reset") || normalizedKey.contains("remaining") || normalizedKey.contains("next") {
                if let seconds = resetValueSeconds(key: normalizedKey, value: value) {
                    return seconds
                }
            }
        }
        return nil
    }

    private func resetValueSeconds(key: String, value: Any) -> TimeInterval? {
        if let str = value as? String {
            if key.contains("at") || str.contains("T") {
                if let date = ISO8601DateFormatter().date(from: str) {
                    return max(0, date.timeIntervalSinceNow)
                }
            }
            return DurationParser.parseString(str)
        }
        guard let number = numberValue(value) else { return nil }
        // If key says ms/millis, convert. Otherwise assume seconds.
        if key.contains("ms") || key.contains("millis") {
            return number / 1000.0
        }
        return number
    }

    private func flatten(_ dict: [String: Any], prefix: String = "") -> [(String, Any)] {
        var out: [(String, Any)] = []
        for (key, value) in dict {
            let full = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                out.append(contentsOf: flatten(nested, prefix: full))
            } else {
                out.append((full, value))
            }
        }
        return out
    }

    private func numberValue(_ value: Any) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private func normalize(_ string: String) -> String {
        string.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    enum ParserError: LocalizedError {
        case notDictionary
        case noUsageWindowsFound

        var errorDescription: String? {
            switch self {
            case .notDictionary: return "Usage JSON root is not a dictionary."
            case .noUsageWindowsFound: return "Could not find rolling/weekly/monthly usage windows in JSON."
            }
        }
    }
}
