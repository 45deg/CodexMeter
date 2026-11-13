// Renders usage cards and reset ticket rows, including tooltips and accessibility labels.
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
        setAccessibilityLabel(localized("Remaining"))
        setAccessibilityValue("\(remaining)%")
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
        let kind = textLabel(showUsed ? localized("Used") : localized("Left"), size: 11, secondary: true)
        kind.alignment = .right
        kind.frame = NSRect(x: 170, y: 45, width: 96, height: 17)
        addSubview(kind)
        addSubview(MeterProgress(remaining: window.remaining, frame: NSRect(x: 18, y: 29, width: 248, height: 4)))
        var resetText = "—"
        var resetDetail = localized("Reset time unavailable")
        if let reset = window.resetsAt {
            let seconds = reset - now.timeIntervalSince1970
            let minutes = max(1, Int(ceil(seconds / 60)))
            let relative =
                minutes >= 1440
                ? localized("%lldd %lldh", minutes / 1440, (minutes % 1440) / 60)
                : minutes >= 60 ? localized("%lldh %lldm", minutes / 60, minutes % 60) : localized("%lld min", minutes)
            resetText = seconds <= 0 ? localized("Waiting for reset") : relative
            resetDetail = localized("Next reset: %@", formatDate(Date(timeIntervalSince1970: reset), template: "Mdjm"))
        }
        let clock = NSImageView(frame: NSRect(x: 18, y: 7, width: 12, height: 12))
        clock.image = NSImage(systemSymbolName: "clock", accessibilityDescription: localized("Time until reset"))
        clock.contentTintColor = .secondaryLabelColor
        addSubview(clock)
        let reset = textLabel(resetText, size: 11, secondary: true)
        reset.frame = NSRect(x: 36, y: 5, width: 230, height: 17)
        reset.toolTip = resetDetail
        addSubview(reset)
        let usage = showUsed
            ? localized("%@: %lld%% used.", window.label, metric)
            : localized("%@: %lld%% remaining.", window.label, metric)
        let resetSummary = window.resetsAt == nil ? resetDetail : "\(resetText). \(resetDetail)"
        setAccessibilityLabel("\(usage) \(resetSummary)")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

final class CreditExpiryRow: NSView {
    init(credit: Credit, index: Int, now: Date = Date()) {
        super.init(frame: NSRect(x: 0, y: 0, width: 274, height: 54))
        let ticketTitle = localized("Reset Ticket %lld", index + 1)
        let title = textLabel(ticketTitle, size: 11, secondary: true)
        title.frame = NSRect(x: 16, y: 31, width: 150, height: 16)
        addSubview(title)
        let expiry = credit.expiresAt.map(Date.init(timeIntervalSince1970:))
        let dateText = expiry.map { formatDate($0, template: "Mdjm") } ?? "—"
        let date = textLabel(dateText, size: 13, weight: .medium)
        date.frame = NSRect(x: 16, y: 10, width: 145, height: 18)
        addSubview(date)
        let timeLeft = credit.timeLeft(now: now)
        let remaining = textLabel(timeLeft, size: 12, weight: .medium)
        remaining.alignment = .right
        remaining.frame = NSRect(x: 168, y: 11, width: 90, height: 17)
        addSubview(remaining)
        let detail = expiry.map { localized("Expires: %@", formatDate($0, template: "yMMMEdjmsz")) }
            ?? localized("Expiry date unavailable")
        toolTip = detail
        setAccessibilityLabel(localized("%@. %@. %@", ticketTitle, detail, timeLeft))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

final class CreditListMenu: NSMenu, NSMenuDelegate {
    let details: [Credit]?
    let count: Int?
    init(snapshot: Snapshot) {
        details = snapshot.creditDetails
        count = snapshot.count
        super.init(title: localized("Reset Tickets"))
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
            let text: String
            if count == 0 {
                text = localized("No reset tickets")
            } else if missing > 0 {
                text = localized("%lld with unknown expiry", missing)
            } else {
                text = localized("Expiry unknown")
            }
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            addItem(item)
        }
    }
}
