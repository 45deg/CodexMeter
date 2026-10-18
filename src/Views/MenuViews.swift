import Cocoa

func textLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSTextField
{
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = secondary ? .secondaryLabelColor : .labelColor
    field.lineBreakMode = .byTruncatingTail
    return field
}

final class MeterProgress: NSView {
    let remaining: Int
    init(remaining: Int, frame: NSRect) {
        self.remaining = remaining
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("残量")
        setAccessibilityValue("\(remaining)％")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2).fill()
        if remaining > 0 {
            NSColor.labelColor.withAlphaComponent(0.85).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: 0, y: 0, width: bounds.width * CGFloat(remaining) / 100, height: bounds.height),
                xRadius: 2, yRadius: 2
            ).fill()
        }
    }
}

final class WindowCard: NSView {
    init(window: Window, showUsed: Bool, now: Date = Date()) {
        super.init(frame: NSRect(x: 0, y: 0, width: 284, height: 96))
        let title = textLabel(window.label, size: 12, weight: .semibold)
        title.frame = NSRect(x: 18, y: 73, width: 100, height: 17)
        addSubview(title)
        let metric = showUsed ? 100 - window.remaining : window.remaining
        let value = textLabel("\(metric)%", size: 28, weight: .medium)
        value.font = .monospacedDigitSystemFont(ofSize: 28, weight: .medium)
        value.frame = NSRect(x: 16, y: 39, width: 130, height: 36)
        addSubview(value)
        let kind = textLabel(showUsed ? "使用済み" : "残り", size: 11, secondary: true)
        kind.alignment = .right
        kind.frame = NSRect(x: 170, y: 45, width: 96, height: 17)
        addSubview(kind)
        addSubview(MeterProgress(remaining: window.remaining, frame: NSRect(x: 18, y: 29, width: 248, height: 4)))
        var resetText = "—"
        var resetDetail = "回復時刻は未取得"
        if let reset = window.resetsAt {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "M/d HH:mm"
            let seconds = reset - now.timeIntervalSince1970
            let minutes = max(1, Int(ceil(seconds / 60)))
            let relative =
                minutes >= 1440
                ? "\(minutes / 1440)日 \((minutes % 1440) / 60)時間"
                : minutes >= 60 ? "\(minutes / 60)時間 \(minutes % 60)分" : "\(minutes)分"
            resetText = seconds <= 0 ? "回復待ち" : relative
            resetDetail = "次回回復：\(formatter.string(from: Date(timeIntervalSince1970: reset)))"
        }
        let clock = NSImageView(frame: NSRect(x: 18, y: 7, width: 12, height: 12))
        clock.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "回復まで")
        clock.contentTintColor = .secondaryLabelColor
        addSubview(clock)
        let reset = textLabel(resetText, size: 11, secondary: true)
        reset.frame = NSRect(x: 36, y: 5, width: 230, height: 17)
        reset.toolTip = resetDetail
        addSubview(reset)
        setAccessibilityLabel("\(window.label)、残り\(window.remaining)％。回復まで\(resetText)。\(resetDetail)")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

final class CreditExpiryRow: NSView {
    init(credit: Credit, index: Int, now: Date = Date()) {
        super.init(frame: NSRect(x: 0, y: 0, width: 274, height: 54))
        let title = textLabel("リセットチケット \(index + 1)", size: 11, secondary: true)
        title.frame = NSRect(x: 16, y: 31, width: 150, height: 16)
        addSubview(title)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        let dateText = credit.expiresAt.map { formatter.string(from: Date(timeIntervalSince1970: $0)) } ?? "—"
        let date = textLabel(dateText, size: 13, weight: .medium)
        date.frame = NSRect(x: 16, y: 10, width: 145, height: 18)
        addSubview(date)
        let remaining = textLabel(credit.timeLeft(now: now), size: 12, weight: .medium)
        remaining.alignment = .right
        remaining.frame = NSRect(x: 168, y: 11, width: 90, height: 17)
        addSubview(remaining)
        let full = DateFormatter()
        full.locale = Locale(identifier: "ja_JP")
        full.dateFormat = "yyyy年M月d日(E) HH:mm:ss z"
        let detail =
            credit.expiresAt.map { "有効期限：\(full.string(from: Date(timeIntervalSince1970: $0)))" } ?? "有効期限を取得できません"
        toolTip = detail
        setAccessibilityLabel("リセットチケット\(index + 1)。\(detail)。\(credit.timeLeft(now: now))")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

final class CreditListMenu: NSMenu, NSMenuDelegate {
    let details: [Credit]?
    let count: Int?
    init(snapshot: Snapshot) {
        details = snapshot.creditDetails
        count = snapshot.count
        super.init(title: "リセットチケット")
        delegate = self
        minimumWidth = 274
        autoenablesItems = false
        populate()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func menuWillOpen(_ menu: NSMenu) { populate() }
    func populate() {
        removeAllItems()
        let sorted = (details ?? []).sorted {
            let first = $0.expiresAt ?? .infinity
            let second = $1.expiresAt ?? .infinity
            return first == second ? $0.id < $1.id : first < second
        }
        let now = Date()
        for (index, credit) in sorted.enumerated() {
            let item = NSMenuItem()
            item.view = CreditExpiryRow(credit: credit, index: index, now: now)
            addItem(item)
        }
        let missing = count.map { max(0, $0 - sorted.count) } ?? 0
        if missing > 0 || sorted.isEmpty {
            let text = count == 0 ? "リセットチケットなし" : missing > 0 ? "\(missing)枚 · 期限未取得" : "期限未取得"
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            addItem(item)
        }
    }
}
