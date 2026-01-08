import SwiftUI

struct HighlightedText: View {
    let text: String
    let highlight: String
    var highlightColor: Color = .yellow

    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else {
            Text(attributedString)
        }
    }

    private var attributedString: AttributedString {
        var attributed = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedHighlight = highlight.lowercased()

        var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex

        while let foundRange = lowercasedText.range(of: lowercasedHighlight, range: searchRange) {
            let start = text.distance(from: text.startIndex, to: foundRange.lowerBound)
            let end = text.distance(from: text.startIndex, to: foundRange.upperBound)

            if let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: start),
               let attrEnd = attributed.index(attributed.startIndex, offsetByCharacters: end) {
                attributed[attrStart..<attrEnd].backgroundColor = highlightColor.opacity(0.3)
            }

            searchRange = foundRange.upperBound..<lowercasedText.endIndex
        }

        return attributed
    }
}

extension AttributedString {
    func index(_ i: AttributedString.Index, offsetByCharacters offset: Int) -> AttributedString.Index? {
        var current = i
        for _ in 0..<offset {
            guard current < endIndex else { return nil }
            current = index(afterCharacter: current)
        }
        return current
    }
}

#Preview {
    VStack(alignment: .leading) {
        HighlightedText(
            text: "This is a test message with error in it",
            highlight: "error"
        )

        HighlightedText(
            text: "Multiple matches: error here and error there",
            highlight: "error"
        )

        HighlightedText(
            text: "Case insensitive: ERROR and Error",
            highlight: "error"
        )
    }
    .padding()
}
