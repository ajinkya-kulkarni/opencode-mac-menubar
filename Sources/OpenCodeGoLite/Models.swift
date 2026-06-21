import Foundation

struct UsageEntry {
    let code: String
    let label: String
    var percent: Int?
    var resetSeconds: TimeInterval?

    var menuPercentText: String {
        guard let percent else { return "--" }
        return "\(percent)%"
    }

    var barPercentText: String {
        guard let percent else { return "--" }
        if percent >= 100 { return "!" }
        return "\(max(0, percent))"
    }

    var barResetText: String {
        guard let resetSeconds else { return "--" }
        return DurationFormatter.compact(seconds: resetSeconds)
    }

    var menuResetText: String {
        guard let resetSeconds else { return "--" }
        return DurationFormatter.longish(seconds: resetSeconds)
    }
}

struct UsageSnapshot {
    var rolling: UsageEntry
    var weekly: UsageEntry
    var monthly: UsageEntry
    var source: String
    var lastUpdated: Date
    var errorMessage: String?

    static func placeholder(error: String? = nil) -> UsageSnapshot {
        UsageSnapshot(
            rolling: UsageEntry(code: "R", label: "Rolling", percent: nil, resetSeconds: nil),
            weekly: UsageEntry(code: "W", label: "Weekly", percent: nil, resetSeconds: nil),
            monthly: UsageEntry(code: "M", label: "Monthly", percent: nil, resetSeconds: nil),
            source: "none",
            lastUpdated: Date(),
            errorMessage: error
        )
    }

    var entries: [UsageEntry] { [rolling, weekly, monthly] }

    var statusLine1: String {
        entries.map { "\($0.code)\($0.barPercentText)" }.joined(separator: " ")
    }

    var statusLine2: String {
        entries.map { $0.barResetText }.joined(separator: " ")
    }
}

enum ConfigPaths {
    static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var configDir: URL {
        home.appendingPathComponent(".config/opencode-go-lite", isDirectory: true)
    }

    static var usageJSON: URL {
        configDir.appendingPathComponent("usage.json")
    }

    static var requestCurl: URL {
        configDir.appendingPathComponent("request.curl")
    }

    static var cacheJSON: URL {
        configDir.appendingPathComponent("last-good.json")
    }

    static var dashboardURL: URL {
        URL(string: "https://opencode.ai/dashboard")!
    }

    static func ensureConfigDir() {
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    }
}
