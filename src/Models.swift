// Defines Codex limit and ticket data, including cached snapshots and labels for display.
import Foundation

struct Window: Codable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
    var remaining: Int { Int(max(0, min(100, 100 - usedPercent)).rounded(.down)) }
    var label: String {
        guard let minutes = windowDurationMins else { return localized("Usage limit") }
        if minutes == 10080 { return localized("Weekly") }
        if minutes % 60 == 0 { return localized("%lld hr", minutes / 60) }
        return localized("%lld min", minutes)
    }
}
struct Bucket: Decodable {
    let primary: Window?
    let secondary: Window?
}
struct Credit: Codable {
    let id: String
    let status: String
    let expiresAt: Double?
    func timeLeft(now: Date = Date()) -> String {
        guard let expiresAt else { return localized("Expiry unknown") }
        let seconds = expiresAt - now.timeIntervalSince1970
        if seconds <= 0 { return localized("Expired") }
        if seconds >= 86400 { return localized("%lldd left", Int(seconds / 86400)) }
        if seconds >= 3600 { return localized("%lldh left", Int(seconds / 3600)) }
        return localized("%lldm left", max(1, Int(ceil(seconds / 60))))
    }
}
struct Credits: Decodable {
    let availableCount: Int
    let credits: [Credit]?
}
struct Limits: Decodable {
    let rateLimits: Bucket?
    let rateLimitsByLimitId: [String: Bucket]?
    let rateLimitResetCredits: Credits?
    var windows: [Window] {
        let bucket = rateLimitsByLimitId?["codex"] ?? rateLimits
        return [bucket?.primary, bucket?.secondary].compactMap { $0 }
    }
}
struct Snapshot: Codable {
    let account: String
    let windows: [Window]
    let creditIDs: [String]
    let count: Int?
    let date: Date
    var creditDetails: [Credit]? = nil
}
