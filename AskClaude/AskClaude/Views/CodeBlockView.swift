import SwiftUI
import AppKit

struct CodeBlockView: View {
    let code: String
    let language: String?
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var isCopied = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                // Language badge
                if let lang = language, !lang.isEmpty {
                    Text(formatLanguage(lang))
                        .font(.system(size: textSizeManager.scaled(10), weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: "E85D04"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(hex: "E85D04").opacity(0.1))
                        )
                }

                Spacer()

                // Copy button
                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .medium))
                        Text(isCopied ? "Copied!" : "Copy")
                            .font(.system(size: textSizeManager.scaled(10), weight: .medium))
                    }
                    .foregroundStyle(isCopied
                                     ? Color(hex: "16A34A")
                                     : Color(hex: "666666"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isHovered ? Color(hex: "F0F0EC") : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Divider
            Rectangle()
                .fill(Color(hex: "E8E8E4"))
                .frame(height: 1)

            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlightedCode)
                    .font(.system(size: textSizeManager.scaled(12), weight: .regular, design: .monospaced))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "F8F8F6"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(hex: "E8E8E4"), lineWidth: 1)
        )
    }

    private var highlightedCode: AttributedString {
        var result = AttributedString(code)
        result.foregroundColor = Color(hex: "374151")

        // Basic syntax highlighting
        let lang = language?.lowercased() ?? ""

        // Keywords (blue-ish)
        let keywords: [String]
        switch lang {
        case "swift":
            keywords = ["import", "struct", "class", "func", "var", "let", "if", "else", "for", "while", "return", "guard", "switch", "case", "default", "enum", "protocol", "extension", "private", "public", "static", "@State", "@Binding", "@ObservedObject", "@Published", "@main", "some", "async", "await", "throws", "try", "catch", "nil", "true", "false", "self", "Self", "init", "deinit", "override", "mutating", "inout", "where", "typealias", "associatedtype"]
        case "typescript", "ts", "javascript", "js":
            keywords = ["import", "export", "from", "const", "let", "var", "function", "async", "await", "return", "if", "else", "for", "while", "class", "interface", "type", "extends", "implements", "new", "this", "super", "static", "public", "private", "protected", "readonly", "true", "false", "null", "undefined", "try", "catch", "throw", "finally", "default", "switch", "case", "break", "continue"]
        case "python", "py":
            keywords = ["import", "from", "def", "class", "return", "if", "elif", "else", "for", "while", "in", "is", "not", "and", "or", "True", "False", "None", "try", "except", "finally", "raise", "with", "as", "lambda", "yield", "pass", "break", "continue", "global", "nonlocal", "async", "await", "self"]
        case "go":
            keywords = ["package", "import", "func", "var", "const", "type", "struct", "interface", "map", "chan", "if", "else", "for", "range", "switch", "case", "default", "return", "break", "continue", "go", "defer", "select", "nil", "true", "false", "make", "new", "append", "len", "cap"]
        case "rust", "rs":
            keywords = ["use", "mod", "pub", "fn", "let", "mut", "const", "static", "struct", "enum", "impl", "trait", "where", "if", "else", "match", "for", "while", "loop", "return", "break", "continue", "move", "ref", "self", "Self", "super", "crate", "async", "await", "dyn", "type", "as", "in", "true", "false", "Some", "None", "Ok", "Err"]
        default:
            keywords = ["import", "export", "function", "class", "return", "if", "else", "for", "while", "var", "let", "const", "true", "false", "null", "nil", "def", "end"]
        }

        for keyword in keywords {
            highlightPattern(&result, pattern: "\\b\(keyword)\\b", color: Color(hex: "7C3AED"))
        }

        // Strings (green)
        highlightPattern(&result, pattern: "\"[^\"]*\"", color: Color(hex: "059669"))
        highlightPattern(&result, pattern: "'[^']*'", color: Color(hex: "059669"))
        highlightPattern(&result, pattern: "`[^`]*`", color: Color(hex: "059669"))

        // Comments (gray)
        highlightPattern(&result, pattern: "//.*$", color: Color(hex: "9CA3AF"), options: .anchorsMatchLines)
        highlightPattern(&result, pattern: "#.*$", color: Color(hex: "9CA3AF"), options: .anchorsMatchLines)

        // Numbers (orange)
        highlightPattern(&result, pattern: "\\b\\d+\\.?\\d*\\b", color: Color(hex: "E85D04"))

        // Types (teal) - capitalized words that look like types
        if ["swift", "typescript", "ts", "rust", "rs", "go"].contains(lang) {
            highlightPattern(&result, pattern: "\\b[A-Z][a-zA-Z0-9]*\\b", color: Color(hex: "0891B2"))
        }

        return result
    }

    private func highlightPattern(_ string: inout AttributedString, pattern: String, color: Color, options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let nsString = String(string.characters) as NSString
        let matches = regex.matches(in: String(string.characters), options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            if let range = Range(match.range, in: String(string.characters)),
               let attrRange = Range(range, in: string) {
                string[attrRange].foregroundColor = color
            }
        }
    }

    private func formatLanguage(_ lang: String) -> String {
        let mapping: [String: String] = [
            "js": "JavaScript",
            "ts": "TypeScript",
            "py": "Python",
            "rb": "Ruby",
            "swift": "Swift",
            "go": "Go",
            "rs": "Rust",
            "java": "Java",
            "kt": "Kotlin",
            "cpp": "C++",
            "c": "C",
            "cs": "C#",
            "php": "PHP",
            "html": "HTML",
            "css": "CSS",
            "scss": "SCSS",
            "json": "JSON",
            "yaml": "YAML",
            "yml": "YAML",
            "xml": "XML",
            "sql": "SQL",
            "sh": "Shell",
            "bash": "Bash",
            "zsh": "Zsh",
            "fish": "Fish",
            "ps1": "PowerShell",
            "md": "Markdown",
            "dockerfile": "Dockerfile",
            "makefile": "Makefile"
        ]
        return mapping[lang.lowercased()] ?? lang.capitalized
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)

        withAnimation(.easeOut(duration: 0.2)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CodeBlockView(
            code: """
            struct ContentView: View {
                @State private var count = 0

                var body: some View {
                    Text("Count: \\(count)")
                }
            }
            """,
            language: "swift"
        )
        .environmentObject(TextSizeManager())

        CodeBlockView(
            code: "npm install @anthropic-ai/sdk",
            language: "bash"
        )
        .environmentObject(TextSizeManager())
    }
    .padding(24)
    .frame(width: 600)
    .background(Color(hex: "FAFAF8"))
}
