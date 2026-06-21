import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let renderer = StatusImageRenderer()
    private let reader = UsageReader()
    private var snapshot = UsageSnapshot.placeholder(error: "Loading…")
    private var timer: Timer?

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.menu = buildMenu()
        updateStatusImage()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        reader.load { [weak self] next in
            DispatchQueue.main.async {
                self?.snapshot = next
                self?.updateStatusImage()
                self?.statusItem.menu = self?.buildMenu()
            }
        }
    }

    private func updateStatusImage() {
        statusItem.button?.image = renderer.image(line1: snapshot.statusLine1, line2: snapshot.statusLine2)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let title = NSMenuItem(title: "OpenCode Go Usage", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        for entry in snapshot.entries {
            let paddedLabel = entry.label.padding(toLength: 7, withPad: " ", startingAt: 0)
            let text = "\(paddedLabel) \(entry.menuPercentText)   resets \(entry.menuResetText)"
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let source = NSMenuItem(title: "Source: \(snapshot.source)", action: nil, keyEquivalent: "")
        source.isEnabled = false
        menu.addItem(source)

        let updated = RelativeDateTimeFormatter()
        updated.unitsStyle = .short
        let updatedText = updated.localizedString(for: snapshot.lastUpdated, relativeTo: Date())
        let last = NSMenuItem(title: "Updated: \(updatedText)", action: nil, keyEquivalent: "")
        last.isEnabled = false
        menu.addItem(last)

        if let error = snapshot.errorMessage, !error.isEmpty {
            let err = NSMenuItem(title: "⚠ \(error)", action: nil, keyEquivalent: "")
            err.isEnabled = false
            menu.addItem(err)
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let openDashboard = NSMenuItem(title: "Open OpenCode Dashboard", action: #selector(openDashboardNow), keyEquivalent: "")
        openDashboard.target = self
        menu.addItem(openDashboard)

        let config = NSMenuItem(title: "Open Config Folder", action: #selector(openConfigFolder), keyEquivalent: "")
        config.target = self
        menu.addItem(config)

        let sample = NSMenuItem(title: "Create Sample usage.json", action: #selector(createSampleUsage), keyEquivalent: "")
        sample.target = self
        menu.addItem(sample)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func openDashboardNow() {
        NSWorkspace.shared.open(ConfigPaths.dashboardURL)
    }

    @objc private func openConfigFolder() {
        ConfigPaths.ensureConfigDir()
        NSWorkspace.shared.open(ConfigPaths.configDir)
    }

    @objc private func createSampleUsage() {
        ConfigPaths.ensureConfigDir()
        let sample = """
        {
          "rolling": {"percent": 0, "resetsIn": "4h 49m"},
          "weekly": {"percent": 2, "resetsIn": "8h 51m"},
          "monthly": {"percent": 1, "resetsIn": "21d 5h"}
        }
        """
        try? sample.write(to: ConfigPaths.usageJSON, atomically: true, encoding: .utf8)
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
