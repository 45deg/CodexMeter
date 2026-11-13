// Prints usage and ticket expiry details for the --check command.
import Foundation

func checkConnection() {
    do {
        let snapshot = try fetchLimits()
        let usage = snapshot.windows.map { localized("%@: %lld%% remaining", $0.label, $0.remaining) }
            .joined(separator: " / ")
        let count = snapshot.count.map { localized("%lld", $0) } ?? localized("Unknown")
        print(localized("Usage fetched: %@. Reset tickets: %@", usage, count))
        for credit in (snapshot.creditDetails ?? []).sorted(by: {
            ($0.expiresAt ?? .infinity) < ($1.expiresAt ?? .infinity)
        }) {
            let expiry = credit.expiresAt.map {
                formatDate(Date(timeIntervalSince1970: $0), template: "yMdjmz")
            } ?? localized("Expiry unknown")
            print(localized("Reset ticket: %@ · %@", expiry, credit.timeLeft()))
        }
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
}
