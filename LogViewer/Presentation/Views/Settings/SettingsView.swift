import SwiftUI

struct SettingsView: View {
    @AppStorage("maxLogEntries") private var maxLogEntries = 100000
    @AppStorage("autoScrollToLatest") private var autoScrollToLatest = true
    @AppStorage("showTimestampMilliseconds") private var showTimestampMilliseconds = true
    @AppStorage("defaultTimeRange") private var defaultTimeRange = "last24Hours"

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            displaySettings
                .tabItem {
                    Label("Display", systemImage: "paintbrush")
                }

            advancedSettings
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 450, height: 300)
    }

    private var generalSettings: some View {
        Form {
            Section {
                Picker("Default Time Range", selection: $defaultTimeRange) {
                    Text("All Time").tag("all")
                    Text("Last Hour").tag("lastHour")
                    Text("Last 24 Hours").tag("last24Hours")
                    Text("Last 7 Days").tag("last7Days")
                    Text("Today").tag("today")
                }

                Toggle("Auto-scroll to latest log", isOn: $autoScrollToLatest)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var displaySettings: some View {
        Form {
            Section {
                Toggle("Show milliseconds in timestamp", isOn: $showTimestampMilliseconds)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var advancedSettings: some View {
        Form {
            Section {
                Stepper(
                    "Max Log Entries: \(maxLogEntries)",
                    value: $maxLogEntries,
                    in: 10000...1000000,
                    step: 10000
                )

                Text("Higher values use more memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
