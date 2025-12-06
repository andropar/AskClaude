import SwiftUI
import UniformTypeIdentifiers

struct InputBar: View {
    @Binding var text: String
    let isDisabled: Bool
    let onSend: () -> Void
    var onFilesDropped: (([String]) -> Void)?

    @EnvironmentObject var textSizeManager: TextSizeManager
    @FocusState private var isFocused: Bool
    @State private var isHovering = false
    @State private var isDraggedOver = false
    @State private var attachedFiles: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Gradient fade from content
            LinearGradient(
                colors: [
                    Color(hex: "FAFAF8").opacity(0),
                    Color(hex: "FAFAF8").opacity(0.9),
                    Color(hex: "FAFAF8")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            // Attached files chips
            if !attachedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachedFiles, id: \.self) { path in
                            AttachedFileChip(
                                path: path,
                                onRemove: { removeAttachedFile(path) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 32)
                .padding(.bottom, 8)
            }

            // Input container
            HStack(spacing: 12) {
                // Text field with send button
                HStack(spacing: 0) {
                    TextField("Ask anything...", text: $text, axis: .vertical)
                        .font(.system(size: textSizeManager.scaled(14)))
                        .foregroundStyle(Color(hex: "333333"))
                        .tint(Color(hex: "E85D04"))
                        .lineLimit(1...8)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit {
                            if canSend && !NSEvent.modifierFlags.contains(.shift) {
                                sendWithAttachments()
                            }
                        }
                        .padding(.leading, 18)
                        .padding(.trailing, 8)
                        .padding(.vertical, 14)

                    // Send button
                    Button(action: {
                        if canSend { sendWithAttachments() }
                    }) {
                        ZStack {
                            Circle()
                                .fill(canSend
                                      ? LinearGradient(
                                          colors: [Color(hex: "FF6B35"), Color(hex: "E85D04")],
                                          startPoint: .topLeading,
                                          endPoint: .bottomTrailing
                                        )
                                      : LinearGradient(
                                          colors: [Color(hex: "E0E0DC"), Color(hex: "E0E0DC")],
                                          startPoint: .topLeading,
                                          endPoint: .bottomTrailing
                                        ))
                                .frame(width: 34, height: 34)
                                .shadow(color: canSend ? Color(hex: "E85D04").opacity(0.3) : .clear, radius: 8, y: 2)

                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(canSend ? .white : Color(hex: "AAAAAA"))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .padding(.trailing, 8)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: canSend)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isDraggedOver ? Color(hex: "FEF3E7") : Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            isDraggedOver
                                ? Color(hex: "E85D04")
                                : (isFocused ? Color(hex: "E85D04").opacity(0.4) : Color(hex: "E5E5E0")),
                            lineWidth: isDraggedOver ? 2 : 1.5
                        )
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDraggedOver)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .background(Color(hex: "FAFAF8"))
        }
        .onDrop(of: [.fileURL, .url], isTargeted: $isDraggedOver) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Load as URL (works for both file browser drag and Finder drag)
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let fileURL = url, fileURL.isFileURL {
                    DispatchQueue.main.async {
                        self.addAttachedFile(fileURL.path)
                    }
                }
            }
        }
        return true
    }

    private func addAttachedFile(_ path: String) {
        guard !attachedFiles.contains(path) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            attachedFiles.append(path)
        }
    }

    private func removeAttachedFile(_ path: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            attachedFiles.removeAll { $0 == path }
        }
    }

    private func sendWithAttachments() {
        // Build message with file context
        var messageText = text

        if !attachedFiles.isEmpty {
            let fileContext = attachedFiles.map { path -> String in
                let name = (path as NSString).lastPathComponent
                return "[Attached file: \(name) at \(path)]"
            }.joined(separator: "\n")

            messageText = fileContext + "\n\n" + messageText
        }

        text = messageText
        attachedFiles.removeAll()
        onSend()
    }

    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !attachedFiles.isEmpty
        return (hasText || hasAttachments) && !isDisabled
    }
}

// MARK: - Attached File Chip

struct AttachedFileChip: View {
    let path: String
    let onRemove: () -> Void
    @State private var isHovered = false

    private var fileName: String {
        (path as NSString).lastPathComponent
    }

    private var fileIcon: String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "json", "xml", "html", "css":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            return "photo"
        case "mp4", "mov", "avi":
            return "film"
        case "pdf":
            return "doc.richtext"
        default:
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return "folder.fill"
            }
            return "doc"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: fileIcon)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "E85D04"))

            Text(fileName)
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "444444"))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color(hex: "888888"))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "F0F0EC"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "E5E5E0"), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "FAFAF8")
            .ignoresSafeArea()

        VStack {
            Spacer()

            InputBar(
                text: .constant(""),
                isDisabled: false,
                onSend: {}
            )
            .environmentObject(TextSizeManager())
        }
    }
    .frame(width: 680, height: 300)
}
