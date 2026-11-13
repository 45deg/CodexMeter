// Compares snapshots for the same account and returns notification text for resets and new tickets.
import Foundation

func recoveryEvents(previous: Snapshot?, current: Snapshot, scheduled: Bool = true) -> [(String, String)] {
    guard let previous, previous.account == current.account else { return [] }
    var result: [(String, String)] = []
    for window in current.windows {
        guard let old = previous.windows.first(where: { $0.windowDurationMins == window.windowDurationMins }),
            let reset = old.resetsAt
        else { continue }
        let title: String
        if reset > current.date.timeIntervalSince1970 && window.usedPercent < old.usedPercent {
            title = localized("Codex usage reset early")
        } else if scheduled, reset <= current.date.timeIntervalSince1970, let next = window.resetsAt, next > reset {
            title = localized("Codex usage reset on schedule")
        } else {
            continue
        }
        let body = localized("%@: %lld%% remaining.", window.label, window.remaining)
        result.append((title, body))
    }
    let newIDs = Set(current.creditIDs).subtracting(previous.creditIDs)
    let increased = (current.count ?? 0) > (previous.count ?? Int.max)
    if increased || (!previous.creditIDs.isEmpty && !newIDs.isEmpty) {
        let count = current.count.map { localized("%lld", $0) } ?? localized("Unknown")
        result.append((localized("New Codex reset tickets"), localized("Available reset tickets: %@", count)))
    }
    return result
}
