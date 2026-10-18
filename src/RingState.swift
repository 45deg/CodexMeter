struct RingState {
    let outer: Double?
    let inner: Double?
    let isDouble: Bool
    init(windows: [Window], showUsed: Bool = false) {
        let short = windows.first { $0.windowDurationMins == 300 }
        let weekly = windows.first { $0.windowDurationMins == 10080 }
        func value(_ window: Window?) -> Double? {
            window.map { Double(showUsed ? 100 - $0.remaining : $0.remaining) }
        }
        isDouble = weekly != nil
        outer = value(short ?? (weekly == nil ? windows.first : nil))
        inner = value(weekly)
    }
}
