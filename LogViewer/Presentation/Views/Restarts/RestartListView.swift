import SwiftUI

struct RestartListView: View {
    let restarts: [SystemRestart]
    @Binding var selection: SystemRestart?
    var isLoading: Bool
    var statistics: RestartStatistics?
    var patterns: [String]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if let stats = statistics {
                statsHeader(stats)
                Divider()
            }

            if !patterns.isEmpty {
                patternsSection
                Divider()
            }

            restartsList
        }
    }

    private func statsHeader(_ stats: RestartStatistics) -> some View {
        HStack(spacing: 16) {
            StatItem(title: "Total", value: "\(stats.totalCount)", color: .primary)
            StatItem(title: "Panics", value: "\(stats.panicCount)", color: .red)
            StatItem(title: "Watchdog", value: "\(stats.watchdogCount)", color: .orange)
            StatItem(title: "Last 7d", value: "\(stats.recentCount)", color: .blue)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(patterns, id: \.self) { pattern in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(pattern)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.yellow.opacity(0.1))
    }

    private var restartsList: some View {
        ZStack {
            if isLoading && restarts.isEmpty {
                ProgressView("Loading restart history...")
            } else if restarts.isEmpty {
                ContentUnavailableView(
                    "No Restarts Found",
                    systemImage: "power.circle",
                    description: Text("No kernel panics or unexpected restarts recorded")
                )
            } else {
                List(selection: $selection) {
                    ForEach(restarts) { restart in
                        RestartRowView(restart: restart, dateFormatter: dateFormatter)
                            .tag(restart)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400)
    }
}

private struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RestartRowView: View {
    let restart: SystemRestart
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            RestartTypeBadge(type: restart.type)

            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: restart.timestamp))
                    .font(.system(.body, design: .monospaced))

                Text(restart.causeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if restart.hasRelatedCrashes {
                HStack(spacing: 4) {
                    Image(systemName: "app.badge")
                        .font(.caption)
                    Text("\(restart.relatedCrashes.count)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RestartListView(
        restarts: [
            SystemRestart(
                timestamp: Date(),
                type: .watchdog,
                panic: KernelPanic(
                    timestamp: Date(),
                    incidentId: "test-1",
                    panicString: "Unexpected SoC watchdog reset"
                ),
                relatedCrashes: []
            ),
            SystemRestart(
                timestamp: Date().addingTimeInterval(-86400),
                type: .kernelPanic,
                panic: KernelPanic(
                    timestamp: Date().addingTimeInterval(-86400),
                    incidentId: "test-2",
                    panicString: "Kernel panic - memory corruption"
                ),
                relatedCrashes: [
                    CrashReport(
                        timestamp: Date().addingTimeInterval(-86400 - 300),
                        processName: "TestApp",
                        processPath: "/path/to/app",
                        terminationReason: "SIGABRT",
                        crashType: .signal
                    )
                ]
            )
        ],
        selection: .constant(nil),
        isLoading: false,
        statistics: RestartStatistics(
            totalCount: 5,
            panicCount: 3,
            typeCounts: [.watchdog: 2, .kernelPanic: 3],
            relatedCrashCount: 8,
            recentCount: 2
        ),
        patterns: ["Multiple Watchdog Reset restarts detected (2 occurrences)"]
    )
}
