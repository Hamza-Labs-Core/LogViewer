import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                Divider()

                sourcesSection

                Divider()

                featuresSection

                Divider()

                shortcutsSection

                Divider()

                troubleshootingSection
            }
            .padding(24)
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.purple)
                Text("LogViewer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            Text("A powerful macOS log viewer and system restart analyzer")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Log Sources")

            VStack(alignment: .leading, spacing: 16) {
                sourceItem(
                    icon: "app.badge",
                    title: "App Logs",
                    description: "View logs from the LogViewer application itself. Useful for debugging this app."
                )

                sourceItem(
                    icon: "gearshape.2",
                    title: "System Logs",
                    description: "View logs from all processes on your Mac, including kernel messages, system daemons, and all applications."
                )

                sourceItem(
                    icon: "waveform",
                    title: "Live Stream",
                    description: "Watch logs in real-time as they're generated. Click the play button to start streaming. Useful for monitoring active issues."
                )

                sourceItem(
                    icon: "bolt.trianglebadge.exclamationmark",
                    title: "System Restarts",
                    description: "Analyze kernel panics and unexpected system restarts. Shows panic details, related crashes, and probable causes."
                )

                sourceItem(
                    icon: "doc.text",
                    title: "Log Files",
                    description: "Import and view external log files. Supports plain text, JSON, and common log formats."
                )
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Features")

            VStack(alignment: .leading, spacing: 16) {
                featureItem(
                    icon: "slider.horizontal.3",
                    title: "Filtering",
                    description: "Filter logs by level (Debug, Info, Warning, Error, Fault), time range, process name, or subsystem."
                )

                featureItem(
                    icon: "magnifyingglass",
                    title: "Search",
                    description: "Use the search bar to find logs containing specific text. Searches message content, process names, and subsystems."
                )

                featureItem(
                    icon: "arrow.up.arrow.down",
                    title: "Sorting",
                    description: "Click column headers to sort logs by timestamp, level, process, or subsystem."
                )

                featureItem(
                    icon: "doc.on.doc",
                    title: "Copy",
                    description: "Select a log entry and click Copy to copy the full details to your clipboard."
                )

                featureItem(
                    icon: "square.and.arrow.up",
                    title: "Export",
                    description: "Export logs in plain text, JSON, or CSV format via File > Export."
                )
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Keyboard Shortcuts")

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                shortcutRow("Search", "Cmd + F")
                shortcutRow("Copy selected", "Cmd + C")
                shortcutRow("Clear logs", "Cmd + K")
                shortcutRow("Refresh", "Cmd + R")
                shortcutRow("Show Help", "Cmd + ?")
            }
        }
    }

    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Troubleshooting")

            VStack(alignment: .leading, spacing: 12) {
                troubleshootItem(
                    title: "\"Permission denied\" errors",
                    solution: "LogViewer needs Full Disk Access to read system logs and diagnostic reports. Go to System Settings > Privacy & Security > Full Disk Access and enable LogViewer."
                )

                troubleshootItem(
                    title: "No logs showing",
                    solution: "Try switching to System Logs instead of App Logs. App Logs only shows this app's own logs. Also check if any filters are active and reset them."
                )

                troubleshootItem(
                    title: "Live Stream not working",
                    solution: "Make sure to click the Play button in the toolbar after selecting Live Stream. The stream won't start automatically."
                )

                troubleshootItem(
                    title: "System Restarts empty",
                    solution: "The app reads from /Library/Logs/DiagnosticReports/. If no kernel panics have occurred recently, this section will be empty."
                )
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
    }

    private func sourceItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func featureItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shortcutRow(_ action: String, _ shortcut: String) -> some View {
        GridRow {
            Text(action)
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func troubleshootItem(title: String, solution: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
            Text(solution)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HelpView()
}
