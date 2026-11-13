// Dispatches the connection check or starts the menu bar app through AppDelegate.
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
    fputs(localized("Usage: CodexMeter [--check]") + "\n", stderr)
    exit(1)
}
