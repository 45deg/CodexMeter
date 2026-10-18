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
            let prefix = windows.count > 1 ? (window.windowDurationMins == 10080 ? "週 " : window.label + " ") : ""
            return "\(prefix)\(value)%"
        }.joined(separator: " · ")
        item.button?.title = windows.isEmpty ? (failure == nil ? "…" : "!") : percent + (failure == nil ? "" : " !")
        let rings = RingState(windows: windows, showUsed: showUsed)
        item.button?.image = ringImage(state: rings)
        item.button?.imagePosition = .imageLeading
        let ringLegend =
            rings.isDouble
            ? "外：5時間\(rings.outer == nil ? "（未取得・点線）" : "") ／ 内：週間" : "リング：\(windows.first?.label ?? "未取得")"
        item.button?.toolTip = failure ?? "Codex · \(showUsed ? "使用済み" : "残り") \(percent)\n\(ringLegend)"
        item.button?.setAccessibilityLabel(
            failure.map { "Codex Meter、取得エラー。\($0)" }
                ?? "Codex Meter、\(showUsed ? "使用済み" : "残り") \(percent)。\(ringLegend)")
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
            let credits = row("リセット券　\(latest.count.map { "\($0)枚" } ?? "—")")
            credits.submenu = CreditListMenu(snapshot: latest)
        }
        if failure != nil { _ = row("接続エラー…", #selector(showError)) }
        menu.addItem(.separator())
        let refreshItem = row(busy ? "更新中…" : "更新", #selector(refresh))
        refreshItem.isEnabled = !busy
        refreshItem.keyEquivalent = "r"
        if !busy, let updated = latest?.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let title = NSMutableAttributedString(string: "更新", attributes: [.font: NSFont.menuFont(ofSize: 0)])
            title.append(
                NSAttributedString(
                    string: "  最終更新 \(formatter.string(from: updated))",
                    attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]))
            refreshItem.attributedTitle = title
        }
        let settings = row("設定")
        settings.submenu = makeSettingsMenu()
        menu.addItem(.separator())
        row("Codex Meterを終了", #selector(quit)).keyEquivalent = "q"
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
        let display = setting("表示", nil)
        let displayMenu = NSMenu()
        for (title, action, selected) in [
            ("残量", #selector(showRemaining), !showUsed), ("使用量", #selector(showUsage), showUsed),
        ] {
            let option = NSMenuItem(title: title, action: action, keyEquivalent: "")
            option.target = self
            option.state = selected ? .on : .off
            displayMenu.addItem(option)
        }
        display.submenu = displayMenu
        submenu.addItem(.separator())
        let notify = setting("通知", #selector(toggleNotifications))
        notify.state = notificationsEnabled ? .on : .off
        let scheduled = setting("定期回復", #selector(toggleScheduled))
        scheduled.state = scheduledEnabled ? .on : .off
        submenu.addItem(.separator())
        _ = setting("通知をテスト", #selector(testNotification))
        _ = setting("通知設定…", #selector(openSettings))
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
        notify("Codex Meter", "通知のテストです。臨時回復とリセット券の追加をお知らせします。")
    }
    @objc private func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }
    @objc private func showError() {
        let alert = NSAlert()
        alert.messageText = "利用状況を取得できません"
        alert.informativeText = failure ?? ""
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
