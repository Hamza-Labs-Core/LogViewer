import SwiftUI

@main
struct LogViewerApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(replacing: .help) {
                Button("LogViewer Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }

            CommandMenu("Logs") {
                Button("Clear Logs") {
                    NotificationCenter.default.post(name: .clearLogs, object: nil)
                }
                .keyboardShortcut("K", modifiers: .command)

                Divider()

                Button("Export...") {
                    NotificationCenter.default.post(name: .exportLogs, object: nil)
                }
                .keyboardShortcut("E", modifiers: [.command, .shift])
            }

            CommandMenu("Filter") {
                Button("Show All Levels") {
                    NotificationCenter.default.post(name: .showAllLevels, object: nil)
                }

                Divider()

                ForEach(LogLevel.allCases, id: \.self) { level in
                    Button("Show \(level.displayName) and Above") {
                        NotificationCenter.default.post(name: .setMinimumLevel, object: level)
                    }
                }
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }

        Window("LogViewer Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        #endif
    }
}

extension Notification.Name {
    static let clearLogs = Notification.Name("clearLogs")
    static let exportLogs = Notification.Name("exportLogs")
    static let showAllLevels = Notification.Name("showAllLevels")
    static let setMinimumLevel = Notification.Name("setMinimumLevel")
}
