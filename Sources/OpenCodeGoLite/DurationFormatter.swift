import Foundation

enum DurationFormatter {
    /// Compact status-bar formatting:
    /// - under 60 minutes: nearest minute, e.g. 12m
    /// - under 48 hours: nearest hour, e.g. 5h
    /// - otherwise: nearest day, e.g. 21d
    static func compact(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--" }
        let minutes = max(0, Int((seconds / 60.0).rounded()))
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = max(1, Int((Double(minutes) / 60.0).rounded()))
        if hours < 48 {
            return "\(hours)h"
        }
        let days = max(1, Int((Double(hours) / 24.0).rounded()))
        return "\(days)d"
    }

    static func longish(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--" }
        let totalMinutes = max(0, Int((seconds / 60.0).rounded()))
        if totalMinutes < 60 { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours < 48 {
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        let days = hours / 24
        let remHours = hours % 24
        return remHours == 0 ? "\(days)d" : "\(days)d \(remHours)h"
    }
}

enum DurationParser {
    static func parse(_ value: Any?) -> TimeInterval? {
        guard let value else { return nil }
        if let number = value as? NSNumber {
            // Most APIs expose reset durations in seconds. If the value is tiny, seconds still behaves sensibly.
            return number.doubleValue
        }
        if let int = value as? Int { return TimeInterval(int) }
        if let double = value as? Double { return TimeInterval(double) }
        if let string = value as? String {
            return parseString(string)
        }
        return nil
    }

    static func parseString(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        if let numeric = Double(trimmed) {
            return numeric
        }

        if let date = ISO8601DateFormatter().date(from: raw) {
            return max(0, date.timeIntervalSinceNow)
        }

        let aliases = [
            "days": "d", "day": "d",
            "hours": "h", "hour": "h", "hrs": "h", "hr": "h",
            "minutes": "m", "minute": "m", "mins": "m", "min": "m",
            "seconds": "s", "second": "s", "secs": "s", "sec": "s"
        ]

        var normalized = trimmed
            .replacingOccurrences(of: "~", with: " ")
            .replacingOccurrences(of: "about", with: " ")
            .replacingOccurrences(of: "approximately", with: " ")
            .replacingOccurrences(of: "resets in", with: " ")
            .replacingOccurrences(of: "reset in", with: " ")

        for (word, short) in aliases {
            normalized = normalized.replacingOccurrences(of: word, with: short)
        }

        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([dhms])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = regex.matches(in: normalized, options: [], range: nsRange)
        guard !matches.isEmpty else { return nil }

        var seconds: Double = 0
        for match in matches {
            guard match.numberOfRanges == 3,
                  let numRange = Range(match.range(at: 1), in: normalized),
                  let unitRange = Range(match.range(at: 2), in: normalized),
                  let number = Double(normalized[numRange]) else { continue }
            let unit = String(normalized[unitRange])
            switch unit {
            case "d": seconds += number * 86_400
            case "h": seconds += number * 3_600
            case "m": seconds += number * 60
            case "s": seconds += number
            default: break
            }
        }
        return seconds > 0 ? seconds : nil
    }
}
