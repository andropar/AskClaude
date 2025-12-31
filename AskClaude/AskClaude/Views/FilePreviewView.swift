import SwiftUI
import AppKit

/// Preview view for displaying file contents inline
/// Supports images, videos, PDFs, CSV, code files, and text files
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
