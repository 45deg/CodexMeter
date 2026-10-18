import Foundation

func snapshot(_ reset: Double, _ used: Double, _ ids: [String], _ count: Int?, _ account: String = "test") -> Snapshot {
    Snapshot(
        account: account, windows: [Window(usedPercent: used, windowDurationMins: 10080, resetsAt: reset)],
        creditIDs: ids, count: count, date: Date(timeIntervalSince1970: 200))
}

func sampleLimits() throws -> Limits {
    let fixture = Data(
        #"{"rateLimits":{"primary":{"usedPercent":30,"windowDurationMins":300,"resetsAt":250},"secondary":{"usedPercent":60,"windowDurationMins":10080,"resetsAt":500}},"rateLimitResetCredits":null}"#
            .utf8)
    return try JSONDecoder().decode(Limits.self, from: fixture)
}

func testRecoveryNotifications() {
    let old = snapshot(100, 80, ["a"], 1)
    precondition(recoveryEvents(previous: nil, current: old).isEmpty, "初回取得は通知しない")
    precondition(recoveryEvents(previous: old, current: old).isEmpty, "変化がなければ通知しない")
    precondition(recoveryEvents(previous: old, current: snapshot(300, 0, ["a"], 1)).count == 1, "定期回復を通知する")
    precondition(
        recoveryEvents(previous: old, current: snapshot(300, 0, ["a"], 1), scheduled: false).isEmpty, "定期回復の通知を無効にできる")
    precondition(recoveryEvents(previous: old, current: snapshot(100, 80, ["a", "b"], 2)).count == 1, "券の追加を通知する")
    precondition(recoveryEvents(previous: old, current: snapshot(100, 80, [], 0)).isEmpty, "券の消費は通知しない")
    precondition(recoveryEvents(previous: old, current: snapshot(300, 0, ["b"], 1, "other")).isEmpty, "アカウント変更時は通知しない")
    precondition(
        recoveryEvents(previous: snapshot(250, 90, [], 0), current: snapshot(300, 0, [], 0)).count == 1, "予定より早い回復を通知する"
    )
}

func testRateLimitDecodingAndRecovery() throws {
    let plus = try sampleLimits()
    precondition(
        plus.windows.count == 2 && plus.windows[0].label == "5時間" && plus.windows[0].remaining == 70
            && plus.windows[1].remaining == 40, "5時間枠と週間枠をデコードできる")
    let before = Snapshot(
        account: "test", windows: plus.windows, creditIDs: [], count: nil, date: Date(timeIntervalSince1970: 200))
    let after = Snapshot(
        account: "test", windows: [Window(usedPercent: 0, windowDurationMins: 300, resetsAt: 600), plus.windows[1]],
        creditIDs: [], count: nil, date: Date(timeIntervalSince1970: 300))
    precondition(recoveryEvents(previous: before, current: after).count == 1, "5時間枠の定期回復を通知する")
}

func testRingSelection() throws {
    let plus = try sampleLimits()
    let ringPair = RingState(windows: plus.windows)
    precondition(ringPair.isDouble && ringPair.outer == 70 && ringPair.inner == 40, "外側は5時間枠、内側は週間枠")
    let reversedPair = RingState(windows: plus.windows.reversed())
    precondition(reversedPair.outer == 70 && reversedPair.inner == 40, "応答順に依存せずリングを選ぶ")
    let weeklyOnly = RingState(windows: [plus.windows[1]])
    precondition(weeklyOnly.isDouble && weeklyOnly.outer == nil && weeklyOnly.inner == 40, "週間枠だけなら外側は未取得")
    let shortOnly = RingState(windows: [plus.windows[0]])
    precondition(!shortOnly.isDouble && shortOnly.outer == 70, "5時間枠だけなら一重リング")
    let usedPair = RingState(windows: plus.windows, showUsed: true)
    precondition(usedPair.outer == 30 && usedPair.inner == 60, "使用量表示ではリングも切り替える")
}

func testCreditExpiry() {
    let now = Date(timeIntervalSince1970: 1000)
    func credit(_ seconds: Double?) -> Credit {
        Credit(id: "test", status: "available", expiresAt: seconds.map { 1000 + $0 })
    }
    precondition(credit(86400 * 4.5).timeLeft(now: now) == "あと4日", "券の残り日数を切り捨てる")
    precondition(credit(3600 * 2.5).timeLeft(now: now) == "あと2時間", "券の残り時間を切り捨てる")
    precondition(credit(30).timeLeft(now: now) == "あと1分", "1分未満はあと1分")
    precondition(credit(0).timeLeft(now: now) == "期限切れ", "期限切れを表示する")
    precondition(credit(nil).timeLeft(now: now) == "期限未取得", "期限不明を表示する")
}

func testLegacySnapshot() throws {
    let plus = try sampleLimits()
    let before = Snapshot(
        account: "test", windows: plus.windows, creditIDs: [], count: nil, date: Date(timeIntervalSince1970: 200))
    var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(before)) as! [String: Any]
    legacy.removeValue(forKey: "creditDetails")
    let restored = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
    precondition(
        restored.creditDetails == nil && restored.windows.count == before.windows.count, "券の詳細がない旧スナップショットを復元できる")
}

do {
    testRecoveryNotifications()
    try testRateLimitDecodingAndRecovery()
    try testRingSelection()
    testCreditExpiry()
    try testLegacySnapshot()
    print("通知・利用枠・リング・券の期限・旧データ互換：21ケース成功")
} catch {
    fputs("テスト失敗: \(error)\n", stderr)
    exit(1)
}
