import Cocoa

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments == ["--check"] {
    checkConnection()
} else if arguments.isEmpty {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
} else {
    fputs("使い方: CodexMeter [--check]\n", stderr)
    exit(1)
}
