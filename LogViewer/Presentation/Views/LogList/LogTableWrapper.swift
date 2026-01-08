import SwiftUI
import AppKit

struct LogTableWrapper: NSViewRepresentable {
    let entries: [LogEntry]
    @Binding var selection: Set<LogEntry.ID>
    @Binding var sortOrder: [KeyPathComparator<LogEntry>]
    var searchText: String
    var onDoubleClick: ((LogEntry) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let tableView = NSTableView()
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.rowHeight = 20
        tableView.intercellSpacing = NSSize(width: 6, height: 2)

        tableView.headerView = NSTableHeaderView()

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 90
        timeColumn.minWidth = 70
        timeColumn.maxWidth = 150
        timeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "timestamp", ascending: true)
        tableView.addTableColumn(timeColumn)

        let levelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("level"))
        levelColumn.title = "Level"
        levelColumn.width = 60
        levelColumn.minWidth = 50
        levelColumn.maxWidth = 80
        levelColumn.sortDescriptorPrototype = NSSortDescriptor(key: "level", ascending: true)
        tableView.addTableColumn(levelColumn)

        let processColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("process"))
        processColumn.title = "Process"
        processColumn.width = 120
        processColumn.minWidth = 80
        processColumn.maxWidth = 200
        processColumn.sortDescriptorPrototype = NSSortDescriptor(key: "process", ascending: true)
        tableView.addTableColumn(processColumn)

        let subsystemColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("subsystem"))
        subsystemColumn.title = "Subsystem"
        subsystemColumn.width = 150
        subsystemColumn.minWidth = 100
        subsystemColumn.maxWidth = 250
        subsystemColumn.sortDescriptorPrototype = NSSortDescriptor(key: "subsystem", ascending: true)
        tableView.addTableColumn(subsystemColumn)

        let messageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
        messageColumn.title = "Message"
        messageColumn.width = 500
        messageColumn.minWidth = 200
        tableView.addTableColumn(messageColumn)

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))

        scrollView.documentView = tableView

        context.coordinator.tableView = tableView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }

        let oldEntries = context.coordinator.entries
        context.coordinator.entries = entries
        context.coordinator.searchText = searchText
        context.coordinator.onDoubleClick = onDoubleClick

        if entries.count != oldEntries.count || !entries.elementsEqual(oldEntries, by: { $0.id == $1.id }) {
            tableView.reloadData()
        }

        let selectedRows = IndexSet(entries.enumerated().compactMap { index, entry in
            selection.contains(entry.id) ? index : nil
        })

        if tableView.selectedRowIndexes != selectedRows {
            tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: LogTableWrapper
        var entries: [LogEntry] = []
        var searchText: String = ""
        var onDoubleClick: ((LogEntry) -> Void)?
        weak var tableView: NSTableView?

        private lazy var timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter
        }()

        init(_ parent: LogTableWrapper) {
            self.parent = parent
            self.entries = parent.entries
            self.searchText = parent.searchText
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            entries.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < entries.count else { return nil }
            let entry = entries[row]

            let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")

            let cell: NSTextField
            if let existingCell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
                cell = existingCell
            } else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = identifier
                cell.lineBreakMode = .byTruncatingTail
                cell.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                cell.isEditable = false
                cell.isBordered = false
                cell.drawsBackground = false
            }

            switch tableColumn?.identifier.rawValue {
            case "time":
                cell.stringValue = timeFormatter.string(from: entry.timestamp)
                cell.textColor = .secondaryLabelColor

            case "level":
                cell.stringValue = entry.level.shortName
                cell.textColor = nsColor(for: entry.level)
                cell.font = .monospacedSystemFont(ofSize: 11, weight: .medium)

            case "process":
                cell.stringValue = entry.process
                cell.textColor = .secondaryLabelColor

            case "subsystem":
                cell.stringValue = entry.subsystem
                cell.textColor = .tertiaryLabelColor

            case "message":
                cell.stringValue = entry.message
                cell.textColor = .labelColor
                if !searchText.isEmpty && entry.message.localizedCaseInsensitiveContains(searchText) {
                    cell.attributedStringValue = highlightedString(entry.message, highlight: searchText)
                }

            default:
                break
            }

            return cell
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            20
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            let selectedIDs = Set(tableView?.selectedRowIndexes.compactMap { index -> UUID? in
                guard index < entries.count else { return nil }
                return entries[index].id
            } ?? [])
            parent.selection = selectedIDs
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first else { return }

            let order: SortOrder = descriptor.ascending ? .forward : .reverse

            let comparator: KeyPathComparator<LogEntry>
            switch descriptor.key {
            case "timestamp":
                comparator = KeyPathComparator(\LogEntry.timestamp, order: order)
            case "level":
                comparator = KeyPathComparator(\LogEntry.level.rawValue, order: order)
            case "process":
                comparator = KeyPathComparator(\LogEntry.process, order: order)
            case "subsystem":
                comparator = KeyPathComparator(\LogEntry.subsystem, order: order)
            default:
                return
            }

            parent.sortOrder = [comparator]
        }

        @objc func handleDoubleClick(_ sender: NSTableView) {
            let clickedRow = sender.clickedRow
            guard clickedRow >= 0, clickedRow < entries.count else { return }
            onDoubleClick?(entries[clickedRow])
        }

        private func nsColor(for level: LogLevel) -> NSColor {
            switch level {
            case .debug:
                return .secondaryLabelColor
            case .info:
                return .labelColor
            case .notice:
                return .systemBlue
            case .warning:
                return .systemOrange
            case .error:
                return .systemRed
            case .fault:
                return .systemPurple
            }
        }

        private func highlightedString(_ text: String, highlight: String) -> NSAttributedString {
            let attributed = NSMutableAttributedString(string: text)
            let range = (text as NSString).range(of: highlight, options: .caseInsensitive)
            if range.location != NSNotFound {
                attributed.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: range)
            }
            return attributed
        }
    }
}
