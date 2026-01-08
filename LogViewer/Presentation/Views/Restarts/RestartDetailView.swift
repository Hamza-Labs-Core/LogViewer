import SwiftUI

struct RestartDetailView: View {
    let restart: SystemRestart
    let analysis: RestartAnalysis?

    @State private var isCopied = false
    @State private var expandedCrashes: Set<UUID> = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        copyToClipboard()
                    } label: {
                        Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy analysis report to clipboard")
                }

                headerSection

                Divider()

                if let analysis = analysis {
                    analysisSection(analysis)
                    Divider()
                }

                if let panic = restart.panic {
                    panicDetailsSection(panic)
                    Divider()
                }

                if !restart.relatedCrashes.isEmpty {
                    relatedCrashesSection
                    Divider()
                }

                if let analysis = analysis, !analysis.recommendations.isEmpty {
                    recommendationsSection(analysis.recommendations)
                }
            }
            .padding()
        }
        .frame(minWidth: 300)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RestartTypeBadge(type: restart.type)
                if let analysis = analysis {
                    SeverityBadge(severity: analysis.severity)
                }
                Spacer()
            }

            Text(dateFormatter.string(from: restart.timestamp))
                .font(.headline)

            if let probableCause = restart.probableCause {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(probableCause)
                        .font(.subheadline)
                }
            }
        }
    }

    private func analysisSection(_ analysis: RestartAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Analysis", systemImage: "magnifyingglass")

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("Cause:")
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(analysis.primaryCause)
                        .fontWeight(.medium)
                }

                Text(analysis.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            if !analysis.relatedCauseAnalysis.isEmpty {
                Text(analysis.relatedCauseAnalysis)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func panicDetailsSection(_ panic: KernelPanic) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Panic Details", systemImage: "bolt.trianglebadge.exclamationmark")

            VStack(alignment: .leading, spacing: 4) {
                Text(panic.panicString)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                if !panic.osVersion.isEmpty {
                    GridRow {
                        Text("macOS")
                            .foregroundStyle(.secondary)
                        Text(panic.osVersion)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if !panic.kernel.isEmpty {
                    GridRow {
                        Text("Kernel")
                            .foregroundStyle(.secondary)
                        Text(panic.kernel)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2)
                    }
                }

                if !panic.product.isEmpty {
                    GridRow {
                        Text("Hardware")
                            .foregroundStyle(.secondary)
                        Text(panic.product)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if let socId = panic.socId {
                    GridRow {
                        Text("SoC ID")
                            .foregroundStyle(.secondary)
                        Text(socId)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if let bootFaults = panic.bootFaults, !bootFaults.isEmpty {
                    GridRow {
                        Text("Boot Faults")
                            .foregroundStyle(.secondary)
                        Text(bootFaults)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }

                if let failureCount = panic.bootFailureCount, failureCount > 0 {
                    GridRow {
                        Text("Boot Failures")
                            .foregroundStyle(.secondary)
                        Text("\(failureCount)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }

                if !panic.incidentId.isEmpty {
                    GridRow {
                        Text("Incident ID")
                            .foregroundStyle(.secondary)
                        Text(panic.incidentId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !panic.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    ForEach(panic.notes, id: \.self) { note in
                        Text("- \(note)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var relatedCrashesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Related Crashes (\(restart.relatedCrashes.count))", systemImage: "app.badge")

            ForEach(restart.relatedCrashes) { crash in
                CrashRowView(
                    crash: crash,
                    isExpanded: expandedCrashes.contains(crash.id),
                    onToggle: {
                        if expandedCrashes.contains(crash.id) {
                            expandedCrashes.remove(crash.id)
                        } else {
                            expandedCrashes.insert(crash.id)
                        }
                    }
                )
            }
        }
    }

    private func recommendationsSection(_ recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recommendations", systemImage: "lightbulb")

            ForEach(recommendations, id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(recommendation)
                        .font(.callout)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    private func copyToClipboard() {
        var text = """
        Restart Analysis Report
        =======================
        Type: \(restart.type.displayName)
        Date: \(dateFormatter.string(from: restart.timestamp))

        """

        if let analysis = analysis {
            text += """

            Analysis
            --------
            Cause: \(analysis.primaryCause)
            Severity: \(analysis.severity.rawValue)

            \(analysis.explanation)

            """
        }

        if let panic = restart.panic {
            text += """

            Panic Details
            -------------
            \(panic.panicString)

            macOS: \(panic.osVersion)
            Kernel: \(panic.kernel)
            Hardware: \(panic.product)

            """
        }

        if !restart.relatedCrashes.isEmpty {
            text += """

            Related Crashes
            ---------------

            """
            for crash in restart.relatedCrashes {
                text += "- \(crash.processName): \(crash.terminationReason)\n"
            }
        }

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        withAnimation {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

private struct CrashRowView: View {
    let crash: CrashReport
    let isExpanded: Bool
    let onToggle: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: crash.crashType.systemImage)
                        .foregroundStyle(crash.crashType.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(crash.processName)
                            .fontWeight(.medium)
                        Text(crash.terminationReason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(timeFormatter.string(from: crash.timestamp))
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse crash details" : "Expand crash details")

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if !crash.terminationDetails.isEmpty {
                        ForEach(crash.terminationDetails, id: \.self) { detail in
                            Text(detail)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !crash.processPath.isEmpty {
                        Text("Path: \(crash.processPath)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    if let parent = crash.parentProcess {
                        Text("Parent: \(parent)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(8)
        .background(.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    RestartDetailView(
        restart: SystemRestart(
            timestamp: Date(),
            type: .watchdog,
            panic: KernelPanic(
                timestamp: Date(),
                incidentId: "ABC-123",
                panicString: "Unexpected SoC (system) watchdog reset occurred after panic save chip reset initiated",
                kernel: "Darwin Kernel Version 25.2.0",
                osVersion: "macOS 26.2 (25C56)",
                product: "Mac15,14",
                socId: "6032",
                bootFaults: "wdog,reset_in_1 btn_shdn",
                bootFailureCount: 1,
                notes: ["missing stackshot buffer or size"]
            ),
            relatedCrashes: [
                CrashReport(
                    timestamp: Date().addingTimeInterval(-1800),
                    processName: "sd",
                    processPath: "/Users/USER/Library/Containers/com.hamzalabs.MediaGenerator/sd",
                    terminationReason: "Library missing",
                    terminationDetails: ["Library not loaded: @rpath/libstable-diffusion.dylib"],
                    parentProcess: "zsh",
                    crashType: .dyldError
                )
            ]
        ),
        analysis: RestartAnalysis(
            restart: SystemRestart(timestamp: Date(), type: .watchdog),
            primaryCause: "SoC Watchdog Reset",
            severity: .high,
            explanation: "The system became unresponsive and the hardware watchdog timer triggered a forced reset. A kernel panic occurred but the system was too frozen to capture full diagnostics before the watchdog reset.",
            recommendations: [
                "Check for resource-intensive processes that may have caused a system hang",
                "Investigate sd crashes that occurred before the restart"
            ],
            relatedCauseAnalysis: "Related crashes before restart:\n- Library Error: sd"
        )
    )
    .frame(width: 450)
}
