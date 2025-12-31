import SwiftUI

// MARK: - Content Block

/// Represents a parsed block of markdown content
struct ContentBlock {
    let type: BlockType

    enum BlockType {
        case text(String)
        case codeBlock(String, String?)
        case heading(String, Int)
        case listItem(String, Bool, Int)
        case blockquote(String)
        case horizontalRule
        case table([String], [[String]])
        case image(String, String)
        case filePreview(String)  // Path to file to preview
    }
}

// MARK: - Table View

/// Renders a markdown table with headers and rows
struct TableView: View {
    let headers: [String]
    let rows: [[String]]
    @EnvironmentObject var textSizeManager: TextSizeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    Text(InlineMarkdownParser.parse(header, scale: textSizeManager.scale))
                        .font(.system(size: textSizeManager.scaled(11), weight: .semibold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if index < headers.count - 1 {
                        Rectangle()
                            .fill(Color(hex: "E8E8E4"))
                            .frame(width: 1)
                    }
                }
            }
            .background(Color(hex: "F5F5F3"))

            Rectangle()
                .fill(Color(hex: "E8E8E4"))
                .frame(height: 1)

            // Rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                        Text(InlineMarkdownParser.parse(cell, scale: textSizeManager.scale))
                            .font(.system(size: textSizeManager.scaled(11)))
                            .foregroundStyle(Color(hex: "333333"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        if cellIndex < row.count - 1 {
                            Rectangle()
                                .fill(Color(hex: "E8E8E4"))
                                .frame(width: 1)
                        }
                    }
                }
                .background(rowIndex % 2 == 0 ? Color.white : Color(hex: "FAFAF8"))

                if rowIndex < rows.count - 1 {
                    Rectangle()
                        .fill(Color(hex: "F0F0EC"))
                        .frame(height: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "E8E8E4"), lineWidth: 1)
        )
    }
}

// MARK: - Inline Markdown Parser

/// Utility for parsing inline markdown formatting (bold, italic, links, code)
struct InlineMarkdownParser {
    static func parse(_ text: String, scale: CGFloat = 1.0) -> AttributedString {
        var attributedString = AttributedString()
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            // Check for inline code
            if let backtickRange = text.range(of: "`", range: currentIndex..<text.endIndex) {
                // Add text before backtick
                if currentIndex < backtickRange.lowerBound {
                    let beforeText = String(text[currentIndex..<backtickRange.lowerBound])
                    attributedString.append(processFormattedText(beforeText, scale: scale))
                }

                // Find closing backtick
                let afterBacktick = text.index(after: backtickRange.lowerBound)
                if afterBacktick < text.endIndex,
                   let closingRange = text.range(of: "`", range: afterBacktick..<text.endIndex) {
                    let codeContent = String(text[afterBacktick..<closingRange.lowerBound])
                    var codeAttr = AttributedString(codeContent)
                    codeAttr.font = .system(size: 13 * scale, weight: .medium, design: .monospaced)
                    codeAttr.foregroundColor = Color(hex: "7C3AED")
                    codeAttr.backgroundColor = Color(hex: "F3F0FF")
                    attributedString.append(codeAttr)
                    currentIndex = text.index(after: closingRange.lowerBound)
                } else {
                    attributedString.append(AttributedString("`"))
                    currentIndex = afterBacktick
                }
            } else {
                let remainingText = String(text[currentIndex..<text.endIndex])
                attributedString.append(processFormattedText(remainingText, scale: scale))
                break
            }
        }

        return attributedString
    }

    private static func processFormattedText(_ text: String, scale: CGFloat) -> AttributedString {
        var result = AttributedString()
        var remaining = text

        // Process links
        while !remaining.isEmpty {
            if let linkMatch = remaining.firstMatch(of: /\[([^\]]+)\]\(([^)]+)\)/) {
                let matchRange = linkMatch.range
                let beforeLink = String(remaining[remaining.startIndex..<matchRange.lowerBound])

                if !beforeLink.isEmpty {
                    result.append(applyBasicFormatting(beforeLink, scale: scale))
                }

                let linkText = String(linkMatch.output.1)
                let linkURL = String(linkMatch.output.2)
                var linkAttr = AttributedString(linkText)
                linkAttr.foregroundColor = Color(hex: "E85D04")
                linkAttr.underlineStyle = .single
                if let url = URL(string: linkURL) {
                    linkAttr.link = url
                }
                result.append(linkAttr)

                remaining = String(remaining[matchRange.upperBound...])
            } else {
                result.append(applyBasicFormatting(remaining, scale: scale))
                break
            }
        }

        return result
    }

    private static func applyBasicFormatting(_ text: String, scale: CGFloat) -> AttributedString {
        var result = AttributedString(text)

        // Bold
        while let match = String(result.characters).range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
            let matchedString = String(String(result.characters)[match])
            let content = String(matchedString.dropFirst(2).dropLast(2))
            if let attrRange = result.range(of: matchedString) {
                var boldAttr = AttributedString(content)
                boldAttr.font = .system(size: 14 * scale, weight: .semibold)
                result.replaceSubrange(attrRange, with: boldAttr)
            }
        }

        // Italic
        while let match = String(result.characters).range(of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, options: .regularExpression) {
            let matchedString = String(String(result.characters)[match])
            let content = String(matchedString.dropFirst(1).dropLast(1))
            if let attrRange = result.range(of: matchedString) {
                var italicAttr = AttributedString(content)
                italicAttr.font = .system(size: 14 * scale).italic()
                result.replaceSubrange(attrRange, with: italicAttr)
            }
        }

        return result
    }
}
