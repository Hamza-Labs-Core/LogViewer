import SwiftUI

struct FilterToolbar: ToolbarContent {
    @ObservedObject var viewModel: FilterViewModel
    var isStreaming: Bool
    var isPaused: Bool
    var onTogglePause: () -> Void
    var onClear: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Menu {
                Button("Show All") {
                    viewModel.showAllLevels()
                }

                Divider()

                ForEach(LogLevel.allCases, id: \.self) { level in
                    Toggle(isOn: Binding(
                        get: { viewModel.levels.contains(level) },
                        set: { _ in viewModel.toggleLevel(level) }
                    )) {
                        Label(level.displayName, systemImage: level.systemImage)
                    }
                }

                Divider()

                Menu("Minimum Level") {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button("\(level.displayName) and above") {
                            viewModel.setMinimumLevel(level)
                        }
                    }
                }
            } label: {
                Label("Level", systemImage: "slider.horizontal.3")
            }
            .help("Filter by log level")

            Picker("Time", selection: $viewModel.timeRangeOption) {
                ForEach(FilterViewModel.TimeRangeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .help("Filter by time range")

            Divider()

            TextField("Process", text: $viewModel.processFilter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .help("Filter by process name")

            TextField("Subsystem", text: $viewModel.subsystemFilter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .help("Filter by subsystem")

            if isStreaming {
                Divider()

                Button {
                    onTogglePause()
                } label: {
                    Label(
                        isPaused ? "Resume" : "Pause",
                        systemImage: isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .help(isPaused ? "Resume log streaming" : "Pause log streaming")
            }

            Divider()

            Button {
                viewModel.reset()
            } label: {
                Label("Reset Filters", systemImage: "arrow.counterclockwise")
            }
            .help("Reset all filters")

            Button(role: .destructive) {
                onClear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear all logs")
        }
    }
}
