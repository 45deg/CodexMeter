// Refreshes Codex snapshots, delivers notifications, and builds the status item and settings menus.
import Cocoa
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var item: NSStatusItem!
    private var timer: Timer?
    private var latest: Snapshot?
    private var previous: Snapshot?
    private var busy = false
    private var failure: String?
    private let defaults = UserDefaults.standard
    private var showUsed: Bool { defaults.bool(forKey: "showUsed") }
    private var notificationsEnabled: Bool { defaults.object(forKey: "notifications") as? Bool ?? true }
    private var scheduledEnabled: Bool { defaults.object(forKey: "scheduled") as? Bool ?? true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        if let data = defaults.data(forKey: "snapshot") {
            previous = try? JSONDecoder().decode(Snapshot.self, from: data)
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        rebuild()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.refresh() }
        if notificationsEnabled { requestPermission() }
    }
    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    @objc private func refresh() {
        guard !busy else { return }
        busy = true
        rebuild()
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try fetchLimits() }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let snapshot):
                    for (title, body) in recoveryEvents(
                        previous: self.previous, current: snapshot, scheduled: self.scheduledEnabled)
                    { self.notify(title, body) }
                    self.previous = snapshot
                    self.latest = snapshot
                    self.failure = nil
                    if let data = try? JSONEncoder().encode(snapshot) { self.defaults.set(data, forKey: "snapshot") }
                case .failure(let error): self.failure = error.localizedDescription
                }
                self.rebuild()
            }
        }
    }
    private func notify(_ title: String, _ body: String) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) { handler([.banner, .sound]) }
    private func rebuild() {
        updateStatusItem()
        item.menu = makeMenu()
    }

    private func updateStatusItem() {
        let windows = latest?.windows ?? []
        let percent = windows.map { window -> String in
            let value = showUsed ? 100 - window.remaining : window.remaining
            guard windows.count > 1 else { return "\(value)%" }
            let label = window.windowDurationMins == 10080 ? localized("Wk") : window.label
            return "\(label) \(value)%"
        }.joined(separator: " · ")
        item.button?.title = windows.isEmpty ? (failure == nil ? "…" : "!") : percent + (failure == nil ? "" : " !")
        let rings = RingState(windows: windows, showUsed: showUsed)
        item.button?.image = ringImage(state: rings)
        item.button?.imagePosition = .imageLeading
        let ringLegend: String
        if rings.isDouble {
            ringLegend = rings.outer == nil
                ? localized("Outer: 5-hour limit unavailable (dashed) / Inner: weekly limit")
                : localized("Outer: 5-hour limit / Inner: weekly limit")
        } else if let window = windows.first {
            ringLegend = localized("Ring: %@", window.label)
        } else {
            ringLegend = localized("Usage unavailable")
        }
        let usage = showUsed ? localized("%@ used", percent) : localized("%@ remaining", percent)
        let tooltip = percent.isEmpty ? ringLegend : "\(usage)\n\(ringLegend)"
        item.button?.toolTip = failure ?? tooltip
        item.button?.setAccessibilityLabel(
            failure.map { localized("Codex Meter. Usage error: %@", $0) } ?? "Codex Meter. \(tooltip)")
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 284
        func row(_ text: String, _ action: Selector? = nil) -> NSMenuItem {
            let entry = NSMenuItem(title: text, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
            return entry
        }
        if let latest {
            for window in latest.windows {
                let card = NSMenuItem()
                card.view = WindowCard(window: window, showUsed: showUsed)
                menu.addItem(card)
            }
            menu.addItem(.separator())
            let count = latest.count.map { localized("%lld", $0) } ?? "—"
            let credits = row(localized("Reset Tickets: %@", count))
            credits.submenu = CreditListMenu(snapshot: latest)
        }
        if failure != nil { _ = row(localized("Connection Error…"), #selector(showError)) }
        menu.addItem(.separator())
        let refreshItem = row(busy ? localized("Refreshing…") : localized("Refresh"), #selector(refresh))
        refreshItem.isEnabled = !busy
        refreshItem.keyEquivalent = "r"
        if !busy, let updated = latest?.date {
            let title = NSMutableAttributedString(string: localized("Refresh"), attributes: [.font: NSFont.menuFont(ofSize: 0)])
            title.append(
                NSAttributedString(
                    string: localized("  Last updated %@", formatDate(updated, template: "jm")),
                    attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]))
            refreshItem.attributedTitle = title
        }
        let settings = row(localized("Settings"))
        settings.submenu = makeSettingsMenu()
        menu.addItem(.separator())
        row(localized("Quit Codex Meter"), #selector(quit)).keyEquivalent = "q"
        return menu
    }

    private func makeSettingsMenu() -> NSMenu {
        let submenu = NSMenu()
        func setting(_ text: String, _ action: Selector?) -> NSMenuItem {
            let entry = NSMenuItem(title: text, action: action, keyEquivalent: "")
            entry.target = self
            submenu.addItem(entry)
            return entry
        }
        let display = setting(localized("Display"), nil)
        let displayMenu = NSMenu()
        for (title, action, selected) in [
            (localized("Remaining"), #selector(showRemaining), !showUsed), (localized("Usage"), #selector(showUsage), showUsed),
        ] {
            let option = NSMenuItem(title: title, action: action, keyEquivalent: "")
            option.target = self
            option.state = selected ? .on : .off
            displayMenu.addItem(option)
        }
        display.submenu = displayMenu
        submenu.addItem(.separator())
        let notify = setting(localized("Notifications"), #selector(toggleNotifications))
        notify.state = notificationsEnabled ? .on : .off
        let scheduled = setting(localized("Scheduled Resets"), #selector(toggleScheduled))
        scheduled.state = scheduledEnabled ? .on : .off
        submenu.addItem(.separator())
        _ = setting(localized("Test Notification"), #selector(testNotification))
        _ = setting(localized("Notification Settings…"), #selector(openSettings))
        return submenu
    }
    @objc private func showRemaining() {
        defaults.set(false, forKey: "showUsed")
        rebuild()
    }
    @objc private func showUsage() {
        defaults.set(true, forKey: "showUsed")
        rebuild()
    }
    @objc private func toggleScheduled() {
        defaults.set(!scheduledEnabled, forKey: "scheduled")
        rebuild()
    }
    @objc private func toggleNotifications() {
        defaults.set(!notificationsEnabled, forKey: "notifications")
        if notificationsEnabled { requestPermission() }
        rebuild()
    }
    @objc private func testNotification() {
        requestPermission()
        notify(
            "Codex Meter",
            localized("This is a test. Codex Meter can notify you about early resets and new reset tickets."))
    }
    @objc private func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }
    @objc private func showError() {
        let alert = NSAlert()
        alert.messageText = localized("Could Not Fetch Usage")
        alert.informativeText = failure ?? ""
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
