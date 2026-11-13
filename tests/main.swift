// Checks recovery detection, limit decoding, ring selection, expiry text, and snapshot compatibility.
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
    precondition(recoveryEvents(previous: nil, current: old).isEmpty, "The first fetch should not notify")
    precondition(recoveryEvents(previous: old, current: old).isEmpty, "Unchanged usage should not notify")
    precondition(recoveryEvents(previous: old, current: snapshot(300, 0, ["a"], 1)).count == 1, "A scheduled reset should notify")
    precondition(
        recoveryEvents(previous: old, current: snapshot(300, 0, ["a"], 1), scheduled: false).isEmpty, "Scheduled reset notifications can be disabled")
    precondition(recoveryEvents(previous: old, current: snapshot(100, 80, ["a", "b"], 2)).count == 1, "New tickets should notify")
    precondition(recoveryEvents(previous: old, current: snapshot(100, 80, [], 0)).isEmpty, "Spending a ticket should not notify")
    precondition(recoveryEvents(previous: old, current: snapshot(300, 0, ["b"], 1, "other")).isEmpty, "Switching accounts should not notify")
    precondition(
        recoveryEvents(previous: snapshot(250, 90, [], 0), current: snapshot(300, 0, [], 0)).count == 1, "An early reset should notify"
    )
}

func testRateLimitDecodingAndRecovery() throws {
    let plus = try sampleLimits()
    precondition(
        plus.windows.count == 2 && plus.windows[0].label == "5 hr" && plus.windows[0].remaining == 70
            && plus.windows[1].remaining == 40, "Decode both the five-hour and weekly limits")
    let before = Snapshot(
        account: "test", windows: plus.windows, creditIDs: [], count: nil, date: Date(timeIntervalSince1970: 200))
    let after = Snapshot(
        account: "test", windows: [Window(usedPercent: 0, windowDurationMins: 300, resetsAt: 600), plus.windows[1]],
        creditIDs: [], count: nil, date: Date(timeIntervalSince1970: 300))
    precondition(recoveryEvents(previous: before, current: after).count == 1, "5時間枠のA scheduled reset should notify")
}

func testRingSelection() throws {
    let plus = try sampleLimits()
    let ringPair = RingState(windows: plus.windows)
    precondition(ringPair.isDouble && ringPair.outer == 70 && ringPair.inner == 40, "Use the outer ring for the five-hour limit and the inner ring for the weekly limit")
    let reversedPair = RingState(windows: plus.windows.reversed())
    precondition(reversedPair.outer == 70 && reversedPair.inner == 40, "Ring selection should not depend on response order")
    let weeklyOnly = RingState(windows: [plus.windows[1]])
    precondition(weeklyOnly.isDouble && weeklyOnly.outer == nil && weeklyOnly.inner == 40, "The outer ring is unavailable if only the weekly limit is present")
    let shortOnly = RingState(windows: [plus.windows[0]])
    precondition(!shortOnly.isDouble && shortOnly.outer == 70, "Use one ring if only the five-hour limit is present")
    let usedPair = RingState(windows: plus.windows, showUsed: true)
    precondition(usedPair.outer == 30 && usedPair.inner == 60, "Show used percentages in both rings in Usage mode")
}

func testCreditExpiry() {
    let now = Date(timeIntervalSince1970: 1000)
    func credit(_ seconds: Double?) -> Credit {
        Credit(id: "test", status: "available", expiresAt: seconds.map { 1000 + $0 })
    }
    precondition(credit(86400 * 4.5).timeLeft(now: now) == "4d left", "Round remaining days down")
    precondition(credit(3600 * 2.5).timeLeft(now: now) == "2h left", "Round remaining hours down")
    precondition(credit(30).timeLeft(now: now) == "1m left", "Show one minute when less than a minute remains")
    precondition(credit(0).timeLeft(now: now) == "Expired", "Show that the ticket expired")
    precondition(credit(nil).timeLeft(now: now) == "Expiry unknown", "Show that the expiry is unknown")
}

func testLegacySnapshot() throws {
    let plus = try sampleLimits()
    let before = Snapshot(
        account: "test", windows: plus.windows, creditIDs: [], count: nil, date: Date(timeIntervalSince1970: 200))
    var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(before)) as! [String: Any]
    legacy.removeValue(forKey: "creditDetails")
    let restored = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
    precondition(
        restored.creditDetails == nil && restored.windows.count == before.windows.count, "Decode older snapshots without ticket details")
}

do {
    testRecoveryNotifications()
    try testRateLimitDecodingAndRecovery()
    try testRingSelection()
    testCreditExpiry()
    try testLegacySnapshot()
    print("All 21 checks passed")
} catch {
    fputs("Test failed: \(error)\n", stderr)
    exit(1)
}
