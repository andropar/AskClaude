import SwiftUI
import AppKit

/// Renders markdown content with a light, friendly design
struct MarkdownContentView: View {
    let content: String
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var loadedImages: [String: NSImage] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(parseContent().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: ContentBlock) -> some View {
        switch block.type {
        case .text(let text):
            Text(parseInlineMarkdown(text))
                .font(.system(size: textSizeManager.scaled(14)))
                .lineSpacing(5)
                .foregroundStyle(Color(hex: "333333"))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

        case .codeBlock(let code, let language):
            CodeBlockView(code: code, language: language)

        case .heading(let text, let level):
            Text(parseInlineMarkdown(text))
                .font(fontForHeading(level))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .padding(.top, level == 1 ? 8 : 4)

        case .listItem(let text, let ordered, let index):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(ordered ? "\(index)." : "")
                    .font(.system(size: textSizeManager.scaled(14), weight: .medium))
                    .foregroundStyle(ordered ? Color(hex: "E85D04") : .clear)
                    .frame(width: ordered ? 24 : 0, alignment: .trailing)

                if !ordered {
                    Circle()
                        .fill(Color(hex: "E85D04"))
                        .frame(width: 5, height: 5)
                        .offset(y: 5)
                }

                Text(parseInlineMarkdown(text))
                    .font(.system(size: textSizeManager.scaled(14)))
                    .lineSpacing(5)
                    .foregroundStyle(Color(hex: "333333"))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "E85D04").opacity(0.6))
                    .frame(width: 3)

                Text(parseInlineMarkdown(text))
                    .font(.system(size: textSizeManager.scaled(13)))
                    .italic()
                    .foregroundStyle(Color(hex: "666666"))
                    .padding(.leading, 14)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)

        case .horizontalRule:
            Rectangle()
                .fill(Color(hex: "E8E8E4"))
                .frame(height: 1)
                .padding(.vertical, 8)

        case .table(let headers, let rows):
            TableView(headers: headers, rows: rows)

        case .image(let alt, let url):
            ImageBlockView(alt: alt, url: url, loadedImages: $loadedImages)

        case .filePreview(let path):
            FilePreviewView(path: path)
        }
    }

    private func fontForHeading(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: textSizeManager.scaled(20), weight: .bold, design: .rounded)
        case 2: return .system(size: textSizeManager.scaled(17), weight: .bold, design: .rounded)
        case 3: return .system(size: textSizeManager.scaled(15), weight: .semibold)
        default: return .system(size: textSizeManager.scaled(14), weight: .semibold)
        }
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        var attributedString = AttributedString()
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            // Check for inline code
            if let backtickRange = text.range(of: "`", range: currentIndex..<text.endIndex) {
                // Add text before backtick
                if currentIndex < backtickRange.lowerBound {
                    let beforeText = String(text[currentIndex..<backtickRange.lowerBound])
                    attributedString.append(processFormattedText(beforeText))
                }

                // Find closing backtick
                let afterBacktick = text.index(after: backtickRange.lowerBound)
                if afterBacktick < text.endIndex,
                   let closingRange = text.range(of: "`", range: afterBacktick..<text.endIndex) {
                    let codeContent = String(text[afterBacktick..<closingRange.lowerBound])
                    var codeAttr = AttributedString(codeContent)
                    codeAttr.font = .system(size: textSizeManager.scaled(13), weight: .medium, design: .monospaced)
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
                attributedString.append(processFormattedText(remainingText))
                break
            }
        }

        return attributedString
    }

    private func processFormattedText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text

        // Process links
        while !remaining.isEmpty {
            if let linkMatch = remaining.firstMatch(of: /\[([^\]]+)\]\(([^)]+)\)/) {
                let matchRange = linkMatch.range
                let beforeLink = String(remaining[remaining.startIndex..<matchRange.lowerBound])

                if !beforeLink.isEmpty {
                    result.append(applyBasicFormatting(beforeLink))
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
                result.append(applyBasicFormatting(remaining))
                break
            }
        }

        return result
    }

    private func applyBasicFormatting(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Bold
        while let match = String(result.characters).range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
            let matchedString = String(String(result.characters)[match])
            let content = String(matchedString.dropFirst(2).dropLast(2))
            if let attrRange = result.range(of: matchedString) {
                var boldAttr = AttributedString(content)
                boldAttr.font = .system(size: textSizeManager.scaled(14), weight: .semibold)
                result.replaceSubrange(attrRange, with: boldAttr)
            }
        }

        // Italic
        while let match = String(result.characters).range(of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, options: .regularExpression) {
            let matchedString = String(String(result.characters)[match])
            let content = String(matchedString.dropFirst(1).dropLast(1))
            if let attrRange = result.range(of: matchedString) {
                var italicAttr = AttributedString(content)
                italicAttr.font = .system(size: textSizeManager.scaled(14)).italic()
                result.replaceSubrange(attrRange, with: italicAttr)
            }
        }

        return result
    }

    private func parseContent() -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var currentText = ""
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage: String?
        var listIndex = 0
        var tableHeaders: [String] = []
        var tableRows: [[String]] = []
        var inTable = false

        let lines = content.components(separatedBy: "\n")

        for line in lines {
            // Code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(ContentBlock(type: .codeBlock(codeBlockContent.trimmingCharacters(in: .newlines), codeBlockLanguage)))
                    codeBlockContent = ""
                    codeBlockLanguage = nil
                    inCodeBlock = false
                } else {
                    flushText(&currentText, &blocks)
                    flushTable(&tableHeaders, &tableRows, &blocks, &inTable)
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if codeBlockLanguage?.isEmpty == true { codeBlockLanguage = nil }
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockContent += line + "\n"
                continue
            }

            // Tables
            if line.contains("|") && !line.hasPrefix("    ") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.matches(of: /^\|?[\s\-:|]+\|?$/).count > 0 && trimmed.contains("-") {
                    inTable = true
                    continue
                }

                let cells = parseTableRow(trimmed)
                if !cells.isEmpty {
                    if !inTable {
                        flushText(&currentText, &blocks)
                        tableHeaders = cells
                        inTable = true
                    } else if tableHeaders.isEmpty {
                        tableHeaders = cells
                    } else {
                        tableRows.append(cells)
                    }
                    continue
                }
            } else if inTable {
                flushTable(&tableHeaders, &tableRows, &blocks, &inTable)
            }

            // File preview syntax: ![[path/to/file]]
            if let fileMatch = line.firstMatch(of: /!\[\[([^\]]+)\]\]/) {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .filePreview(String(fileMatch.output.1))))
                continue
            }

            // Images
            if let imageMatch = line.firstMatch(of: /!\[([^\]]*)\]\(([^)]+)\)/) {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .image(String(imageMatch.output.1), String(imageMatch.output.2))))
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces).matches(of: /^(-{3,}|\*{3,}|_{3,})$/).count > 0 {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .horizontalRule))
                continue
            }

            // Headings
            if line.hasPrefix("# ") {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .heading(String(line.dropFirst(2)), 1)))
                listIndex = 0
                continue
            }
            if line.hasPrefix("## ") {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .heading(String(line.dropFirst(3)), 2)))
                listIndex = 0
                continue
            }
            if line.hasPrefix("### ") {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .heading(String(line.dropFirst(4)), 3)))
                listIndex = 0
                continue
            }
            if line.hasPrefix("#### ") {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .heading(String(line.dropFirst(5)), 4)))
                listIndex = 0
                continue
            }

            // Unordered list
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .listItem(String(line.dropFirst(2)), false, 0)))
                listIndex = 0
                continue
            }

            // Ordered list
            if let match = line.firstMatch(of: /^(\d+)\.\s+(.*)/) {
                flushText(&currentText, &blocks)
                listIndex += 1
                blocks.append(ContentBlock(type: .listItem(String(match.output.2), true, listIndex)))
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") {
                flushText(&currentText, &blocks)
                blocks.append(ContentBlock(type: .blockquote(String(line.dropFirst(2)))))
                listIndex = 0
                continue
            }

            // Regular text
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                listIndex = 0
            }
            currentText += line + "\n"
        }

        // Flush remaining
        flushTable(&tableHeaders, &tableRows, &blocks, &inTable)
        if inCodeBlock && !codeBlockContent.isEmpty {
            blocks.append(ContentBlock(type: .codeBlock(codeBlockContent.trimmingCharacters(in: .newlines), codeBlockLanguage)))
        } else if !currentText.isEmpty {
            blocks.append(ContentBlock(type: .text(currentText.trimmingCharacters(in: .newlines))))
        }

        return blocks
    }

    private func parseTableRow(_ line: String) -> [String] {
        var content = line.trimmingCharacters(in: .whitespaces)
        if content.hasPrefix("|") { content = String(content.dropFirst()) }
        if content.hasSuffix("|") { content = String(content.dropLast()) }
        return content.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func flushText(_ currentText: inout String, _ blocks: inout [ContentBlock]) {
        let trimmed = currentText.trimmingCharacters(in: .newlines)
        if !trimmed.isEmpty {
            blocks.append(ContentBlock(type: .text(trimmed)))
        }
        currentText = ""
    }

    private func flushTable(_ headers: inout [String], _ rows: inout [[String]], _ blocks: inout [ContentBlock], _ inTable: inout Bool) {
        if !headers.isEmpty {
            blocks.append(ContentBlock(type: .table(headers, rows)))
        }
        headers = []
        rows = []
        inTable = false
    }
}

#Preview {
    ScrollView {
        MarkdownContentView(content: """
        # Welcome to Ask Claude

        The authentication system uses JWT tokens stored in httpOnly cookies. Here's the flow:

        1. User submits credentials to `/api/login`
        2. Server validates and returns JWT
        3. Client stores in cookie automatically

        ```swift
        struct ContentView: View {
            @State private var count = 0

            var body: some View {
                Text("Hello!")
            }
        }
        ```

        The key files are:
        - `src/auth/login.ts` - Login logic
        - `src/middleware/jwt.ts` - Token validation

        > Security note: Always use HTTPS in production.

        | Method | Endpoint | Description |
        |--------|----------|-------------|
        | POST | /api/login | Authenticate user |
        | POST | /api/logout | Clear session |
        | GET | /api/me | Get current user |

        Check out the [documentation](https://docs.example.com) for more.
        """)
        .environmentObject(TextSizeManager())
        .padding(24)
    }
    .frame(width: 600, height: 700)
    .background(Color(hex: "FAFAF8"))
}
