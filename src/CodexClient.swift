import Foundation

enum MeterError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let value) = self { return value }
        return nil
    }
}

// Each read has a bounded lifetime; the child never starts a model turn.
func fetchLimits() throws -> Snapshot {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
        home + "/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
        "/Applications/Codex.app/Contents/Resources/codex",
    ]
    guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
        throw MeterError.message("Codex CLIが見つかりません。Codex CLIをインストールし、codex loginでログインしてください。")
    }
    let process = Process()
    let input = Pipe()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = ["app-server", "--listen", "stdio://"]
    process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: deadline)
    defer {
        deadline.cancel()
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
        try? output.fileHandleForReading.close()
    }
    func send(_ value: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: value)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    var buffer = Data()
    func response(_ id: Int) throws -> Data {
        while true {
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let value = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                    let replyID = value["id"] as? Int, replyID == id
                else { continue }
                if let error = value["error"] as? [String: Any] {
                    throw MeterError.message(error["message"] as? String ?? "Codexからエラーが返りました")
                }
                guard let result = value["result"] else { throw MeterError.message("応答にデータがありません") }
                return try JSONSerialization.data(withJSONObject: result)
            }
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { throw MeterError.message("取得できませんでした。接続またはCodex CLIのログインを確認してください（30秒で中断）。") }
            buffer.append(chunk)
        }
    }
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    try send([
        "id": 0, "method": "initialize",
        "params": ["clientInfo": ["name": "codex_meter", "title": "Codex Meter", "version": version]],
    ])
    _ = try response(0)
    try send(["method": "initialized", "params": [:]])
    try send(["id": 1, "method": "account/read", "params": ["refreshToken": false]])
    let accountData = try JSONSerialization.jsonObject(with: response(1)) as? [String: Any]
    let account = accountData?["account"] as? [String: Any]
    guard let email = account?["email"] as? String else {
        throw MeterError.message("Codex CLIでChatGPTアカウントにログインしてください。ターミナルで codex login を実行できます。")
    }
    try send(["id": 2, "method": "account/rateLimits/read"])
    let limits = try JSONDecoder().decode(Limits.self, from: response(2))
    guard !limits.windows.isEmpty else { throw MeterError.message("利用枠が返されませんでした") }
    return Snapshot(
        account: email, windows: limits.windows,
        creditIDs: limits.rateLimitResetCredits?.credits?.filter { $0.status == "available" }.map(\.id) ?? [],
        count: limits.rateLimitResetCredits?.availableCount, date: Date(),
        creditDetails: limits.rateLimitResetCredits?.credits?.filter { $0.status == "available" })
}
