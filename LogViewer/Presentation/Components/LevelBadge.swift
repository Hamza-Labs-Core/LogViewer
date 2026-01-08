import SwiftUI

struct LevelBadge: View {
    let level: LogLevel

    var body: some View {
        Text(level.shortName)
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color.opacity(0.15))
            .foregroundStyle(level.color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    HStack {
        ForEach(LogLevel.allCases, id: \.self) { level in
            LevelBadge(level: level)
        }
    }
    .padding()
}
