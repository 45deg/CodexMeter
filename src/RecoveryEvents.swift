import Foundation

func recoveryEvents(previous: Snapshot?, current: Snapshot, scheduled: Bool = true) -> [(String, String)] {
    guard let previous, previous.account == current.account else { return [] }
    var result: [(String, String)] = []
    for window in current.windows {
        guard let old = previous.windows.first(where: { $0.windowDurationMins == window.windowDurationMins }),
            let reset = old.resetsAt
        else { continue }
        if reset > current.date.timeIntervalSince1970 && window.usedPercent < old.usedPercent {
            result.append(("Codexの臨時回復を検知しました", "\(window.label)枠が残り\(window.remaining)％になりました。"))
        } else if scheduled, reset <= current.date.timeIntervalSince1970, let next = window.resetsAt, next > reset {
            result.append(("Codexの\(window.label)枠が定期回復しました", "残り\(window.remaining)％です。"))
        }
    }
    let newIDs = Set(current.creditIDs).subtracting(previous.creditIDs)
    let increased = (current.count ?? 0) > (previous.count ?? Int.max)
    if increased || (!previous.creditIDs.isEmpty && !newIDs.isEmpty) {
        result.append(("Codexのリセットチケットが追加されました", "利用可能なリセットチケット：\(current.count.map(String.init) ?? "不明")枚"))
    }
    return result
}
