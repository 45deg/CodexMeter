import Foundation

struct Window: Codable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
    var remaining: Int { Int(max(0, min(100, 100 - usedPercent)).rounded(.down)) }
    var label: String {
        guard let minutes = windowDurationMins else { return "利用枠" }
        if minutes == 10080 { return "週間" }
        if minutes % 60 == 0 { return "\(minutes / 60)時間" }
        return "\(minutes)分"
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
        guard let expiresAt else { return "期限未取得" }
        let seconds = expiresAt - now.timeIntervalSince1970
        if seconds <= 0 { return "期限切れ" }
        if seconds >= 86400 { return "あと\(Int(seconds / 86400))日" }
        if seconds >= 3600 { return "あと\(Int(seconds / 3600))時間" }
        return "あと\(max(1, Int(ceil(seconds / 60))))分"
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
