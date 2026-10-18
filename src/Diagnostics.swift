import Foundation

func checkConnection() {
    do {
        let snapshot = try fetchLimits()
        print(
            "取得成功：" + snapshot.windows.map { "\($0.label) 残り\($0.remaining)%" }.joined(separator: " / ")
                + "、リセットチケット \(snapshot.count.map(String.init) ?? "不明")枚")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm z"
        for credit in (snapshot.creditDetails ?? []).sorted(by: {
            ($0.expiresAt ?? .infinity) < ($1.expiresAt ?? .infinity)
        }) {
            print(
                "リセットチケット：\(credit.expiresAt.map { formatter.string(from: Date(timeIntervalSince1970: $0)) } ?? "期限未取得") · \(credit.timeLeft())"
            )
        }
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
}
