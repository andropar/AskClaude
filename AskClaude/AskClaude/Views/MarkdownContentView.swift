import SwiftUI
import AppKit
import PDFKit
import AVKit

/// Renders markdown content - light, friendly design
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

// MARK: - Table View

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

// MARK: - Image View

struct ImageBlockView: View {
    let alt: String
    let url: String
    @Binding var loadedImages: [String: NSImage]
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var imageLoadTask: URLSessionDataTask?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = loadedImages[url] {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 500, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading...")
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "F5F5F3"))
                )
            } else if let error = loadError {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .foregroundStyle(Color(hex: "888888"))
                    Text(error)
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "F5F5F3"))
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .foregroundStyle(Color(hex: "888888"))
                    Text(alt.isEmpty ? url : alt)
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                        .lineLimit(1)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "F5F5F3"))
                )
                .onAppear { loadImage() }
            }

            if !alt.isEmpty && loadedImages[url] != nil {
                Text(alt)
                    .font(.system(size: textSizeManager.scaled(10)))
                    .foregroundStyle(Color(hex: "888888"))
                    .italic()
            }
        }
        .onDisappear {
            imageLoadTask?.cancel()
        }
    }

    private func loadImage() {
        if url.hasPrefix("/") || url.hasPrefix("file://") {
            let filePath = url.hasPrefix("file://") ? String(url.dropFirst(7)) : url
            if let image = NSImage(contentsOfFile: filePath) {
                loadedImages[url] = image
            } else {
                loadError = "File not found"
            }
            return
        }

        guard let imageURL = URL(string: url) else {
            loadError = "Invalid URL"
            return
        }

        isLoading = true
        let task = URLSession.shared.dataTask(with: imageURL) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    // Don't show error if task was cancelled
                    if (error as NSError).code != NSURLErrorCancelled {
                        loadError = error.localizedDescription
                    }
                } else if let data = data, let image = NSImage(data: data) {
                    loadedImages[url] = image
                } else {
                    loadError = "Failed to load"
                }
            }
        }
        imageLoadTask = task
        task.resume()
    }
}

// MARK: - Content Block

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

// MARK: - File Preview View

struct FilePreviewView: View {
    let path: String
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var fileContent: FileContent?
    @State private var isLoading = true
    @State private var error: String?

    enum FileContent {
        case image(NSImage)
        case text(String, String?)  // content, language
        case csv([[String]])
        case video(URL)
        case pdf(URL)
        case unknown(String)  // file type
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with file name
            HStack(spacing: 8) {
                Image(systemName: iconForFile)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "E85D04"))

                Text((path as NSString).lastPathComponent)
                    .font(.system(size: textSizeManager.scaled(12), weight: .medium))
                    .foregroundStyle(Color(hex: "333333"))

                Spacer()

                Button(action: openInFinder) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .buttonStyle(.plain)
                .help("Open in Finder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "F5F5F3"))

            // Content
            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading...")
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .padding(16)
            } else if let error = error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color(hex: "E85D04"))
                    Text(error)
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "666666"))
                }
                .padding(16)
            } else if let content = fileContent {
                renderContent(content)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "E8E8E4"), lineWidth: 1)
        )
        .onAppear { loadFile() }
    }

    private var iconForFile: String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            return "photo"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "pdf":
            return "doc.richtext"
        case "csv":
            return "tablecells"
        case "md", "markdown":
            return "doc.text"
        case "swift", "py", "js", "ts", "json", "xml", "html", "css":
            return "chevron.left.forwardslash.chevron.right"
        case "txt":
            return "doc.text"
        default:
            return "doc"
        }
    }

    @ViewBuilder
    private func renderContent(_ content: FileContent) -> some View {
        switch content {
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 500, maxHeight: 400)
                .padding(12)

        case .text(let text, let language):
            if let lang = language {
                CodeBlockView(code: text, language: lang)
                    .padding(12)
            } else {
                ScrollView {
                    Text(text)
                        .font(.system(size: textSizeManager.scaled(12), design: .monospaced))
                        .foregroundStyle(Color(hex: "333333"))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .padding(12)
            }

        case .csv(let rows):
            if !rows.isEmpty {
                let headers = rows[0]
                let dataRows = Array(rows.dropFirst())
                TableView(headers: headers, rows: dataRows)
                    .padding(12)
            }

        case .video(let url):
            VideoPlayerView(url: url)
                .frame(maxWidth: 500, maxHeight: 300)
                .padding(12)

        case .pdf(let url):
            PDFPreviewView(url: url)
                .frame(maxWidth: 500, maxHeight: 400)
                .padding(12)

        case .unknown(let fileType):
            HStack(spacing: 8) {
                Image(systemName: "doc")
                    .foregroundStyle(Color(hex: "888888"))
                Text("Cannot preview \(fileType) files")
                    .font(.system(size: textSizeManager.scaled(11)))
                    .foregroundStyle(Color(hex: "888888"))
            }
            .padding(16)
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    private func loadFile() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let ext = (path as NSString).pathExtension.lowercased()
            var result: FileContent?
            var loadError: String?

            guard FileManager.default.fileExists(atPath: path) else {
                loadError = "File not found"
                DispatchQueue.main.async {
                    self.error = loadError
                    self.isLoading = false
                }
                return
            }

            // Check file size to prevent loading huge files
            guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let fileSize = fileAttributes[.size] as? Int64 else {
                loadError = "Cannot read file attributes"
                DispatchQueue.main.async {
                    self.error = loadError
                    self.isLoading = false
                }
                return
            }

            // 10MB limit for text files
            let maxTextFileSize: Int64 = 10 * 1024 * 1024
            let isTextFile = ["md", "markdown", "swift", "py", "python", "js", "javascript",
                             "ts", "typescript", "json", "xml", "html", "htm", "txt", "log", "css", "csv"].contains(ext)

            if isTextFile && fileSize > maxTextFileSize {
                loadError = "File too large (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))). Maximum size for text preview is \(ByteCountFormatter.string(fromByteCount: maxTextFileSize, countStyle: .file))"
                DispatchQueue.main.async {
                    self.error = loadError
                    self.isLoading = false
                }
                return
            }

            switch ext {
            case "png", "jpg", "jpeg", "gif", "webp", "heic", "bmp", "tiff":
                if let image = NSImage(contentsOfFile: path) {
                    result = .image(image)
                } else {
                    loadError = "Failed to load image"
                }

            case "mp4", "mov", "avi", "mkv", "m4v":
                result = .video(URL(fileURLWithPath: path))

            case "pdf":
                result = .pdf(URL(fileURLWithPath: path))

            case "csv":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    let rows = parseCSV(content)
                    result = .csv(rows)
                } else {
                    loadError = "Failed to read CSV"
                }

            case "md", "markdown":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(content, nil)  // Will render as markdown
                } else {
                    loadError = "Failed to read file"
                }

            case "swift":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), "swift")
                }

            case "py", "python":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), "python")
                }

            case "js", "javascript":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), "javascript")
                }

            case "ts", "typescript":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), "typescript")
                }

            case "json":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), "json")
                }

            case "xml", "html", "htm":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), ext)
                }

            case "txt", "log":
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), nil)
                }

            default:
                // Try to read as text
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = .text(String(content.prefix(5000)), nil)
                } else {
                    result = .unknown(ext.isEmpty ? "this" : ".\(ext)")
                }
            }

            DispatchQueue.main.async {
                self.fileContent = result
                self.error = loadError
                self.isLoading = false
            }
        }
    }

    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines.prefix(100) {  // Limit to 100 rows
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let cells = parseCSVLine(line)
            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        return rows
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var cells: [String] = []
        var currentCell = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                if inQuotes {
                    // Check for escaped quote
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentCell.append("\"")
                        i = nextIndex
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                cells.append(currentCell.trimmingCharacters(in: .whitespaces))
                currentCell = ""
            } else {
                currentCell.append(char)
            }

            i = line.index(after: i)
        }

        // Add last cell
        cells.append(currentCell.trimmingCharacters(in: .whitespaces))

        return cells
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let url: URL

    var body: some View {
        // Simple placeholder - full video player would need AVKit
        VStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "E85D04"))

            Text("Video: \(url.lastPathComponent)")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "666666"))

            Button("Open in QuickTime") {
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(hex: "E85D04"))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(hex: "F5F5F3"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - PDF Preview View

struct PDFPreviewView: View {
    let url: URL
    @State private var thumbnail: NSImage?
    @State private var pageCount: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            if let thumbnail = thumbnail {
                // Show PDF thumbnail
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(hex: "E8E8E4"), lineWidth: 1)
                    )

                HStack(spacing: 16) {
                    Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "888888"))

                    Button(action: { NSWorkspace.shared.open(url) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 10))
                            Text("Open in Preview")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "E85D04"))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Fallback
                VStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "E85D04"))

                    Text("PDF: \(url.lastPathComponent)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "666666"))

                    Button("Open in Preview") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "E85D04"))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(hex: "F5F5F3"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear { loadPDFThumbnail() }
    }

    private func loadPDFThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pdfDocument = PDFDocument(url: url),
                  let firstPage = pdfDocument.page(at: 0) else {
                return
            }

            let pageCount = pdfDocument.pageCount
            let pageRect = firstPage.bounds(for: .mediaBox)

            // Scale to reasonable size
            let scale: CGFloat = min(400 / pageRect.width, 500 / pageRect.height)
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            let image = NSImage(size: scaledSize)
            image.lockFocus()

            if let context = NSGraphicsContext.current?.cgContext {
                // White background
                context.setFillColor(NSColor.white.cgColor)
                context.fill(CGRect(origin: .zero, size: scaledSize))

                // Draw PDF page
                context.scaleBy(x: scale, y: scale)
                firstPage.draw(with: .mediaBox, to: context)
            }

            image.unlockFocus()

            DispatchQueue.main.async {
                self.thumbnail = image
                self.pageCount = pageCount
            }
        }
    }
}

// MARK: - Inline Markdown Parser

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
