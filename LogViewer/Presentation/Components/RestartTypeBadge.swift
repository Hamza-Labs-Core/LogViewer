import SwiftUI

struct RestartTypeBadge: View {
    let type: RestartType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.systemImage)
                .font(.caption2)
            Text(type.shortName)
                .font(.system(.caption2, design: .monospaced, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(type.color.opacity(0.15))
        .foregroundStyle(type.color)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct SeverityBadge: View {
    let severity: RestartAnalysis.Severity

    var color: Color {
        switch severity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        Text(severity.rawValue)
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack {
            ForEach(RestartType.allCases, id: \.self) { type in
                RestartTypeBadge(type: type)
            }
        }

        HStack {
            SeverityBadge(severity: .low)
            SeverityBadge(severity: .medium)
            SeverityBadge(severity: .high)
            SeverityBadge(severity: .critical)
        }
    }
    .padding()
}
