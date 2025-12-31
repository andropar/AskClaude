import SwiftUI
import UniformTypeIdentifiers

// MARK: - Session Error

/// Typed error representation for user-facing alerts
enum SessionError: Identifiable {
    case claudeNotFound
    case notAuthenticated
    case launchFailed(String)
    case processExited(Int32)
    case other(String)

    var id: String {
        switch self {
        case .claudeNotFound: return "notFound"
        case .notAuthenticated: return "notAuth"
        case .launchFailed(let reason): return "launch-\(reason)"
        case .processExited(let code): return "exit-\(code)"
        case .other(let msg): return "other-\(msg)"
        }
    }

    var message: String {
        switch self {
        case .claudeNotFound:
            return "Claude CLI not found. Please ensure Claude Code is installed.\n\nInstall from: https://claude.ai/code"
        case .notAuthenticated:
            return "Not signed in to Claude Code. Please run 'claude' in Terminal to sign in."
        case .launchFailed(let reason):
            return "Failed to launch Claude: \(reason)"
        case .processExited(let code):
            return "Claude process exited unexpectedly with code \(code). This may be a temporary issue."
        case .other(let msg):
            return msg
        }
    }

    var isRetryable: Bool {
        switch self {
        case .claudeNotFound, .notAuthenticated:
            return false  // User needs to take action first
        case .launchFailed, .processExited, .other:
            return true  // May work on retry
        }
    }

    static func from(_ errorString: String) -> SessionError {
        if errorString.contains("Claude CLI not found") {
            return .claudeNotFound
        } else if errorString.contains("Not signed in") || errorString.contains("sign in") {
            return .notAuthenticated
        } else if errorString.contains("Failed to launch") {
            let reason = errorString.replacingOccurrences(of: "Failed to launch Claude: ", with: "")
            return .launchFailed(reason)
        } else if errorString.contains("process exited with code") {
            // Extract exit code from message like "Claude process exited with code 1"
            if let range = errorString.range(of: "code "),
               let codeStr = errorString[range.upperBound...].split(separator: " ").first,
               let code = Int32(codeStr) {
                return .processExited(code)
            }
            return .processExited(-1)
        } else {
            return .other(errorString)
        }
    }
}

struct ChatView: View {
    @ObservedObject var session: ChatSession
    @EnvironmentObject var textSizeManager: TextSizeManager
    @EnvironmentObject var sessionManager: SessionManager
    @State private var inputText = ""
    @State private var appeared = false
    @State private var showFileBrowser = false
    @State private var showErrorAlert = false
    @State private var alertError: SessionError?
    @FocusState private var isInputFocused: Bool
    var onToggleSidebar: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // Main chat area
            VStack(spacing: 0) {
                // Header with folder context
                HeaderBar(
                    session: session,
                    onToggleSidebar: onToggleSidebar,
                    onNewChat: {
                        Task {
                            await sessionManager.createSession(for: session.folderPath)
                        }
                    },
                    onToggleFiles: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showFileBrowser.toggle()
                        }
                    },
                    showingFiles: showFileBrowser
                )

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(session.messages.enumerated()), id: \.element.id) { index, message in
                                MessageRow(message: message)
                                    .id(message.id)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            if session.isThinking && session.pendingPermission == nil {
                                ThinkingRow(activity: session.currentActivity ?? "Thinking")
                                    .id("thinking")
                            }

                            // Permission request
                            if let permission = session.pendingPermission {
                                PermissionRequestView(
                                    permission: permission,
                                    onAllow: { session.respondToPermission(allow: true) },
                                    onDeny: { session.respondToPermission(allow: false) }
                                )
                                .id("permission")
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            // Invisible anchor at bottom for reliable scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: session.messages.count) { oldCount, newCount in
                        // New message added - always scroll immediately
                        scrollToBottomNow(proxy: proxy)
                    }
                    .onChange(of: session.messages.last?.content) { _, _ in
                        // Streaming content - scroll on each update
                        scrollToBottomNow(proxy: proxy)
                    }
                    .onChange(of: session.isThinking) { _, isThinking in
                        if isThinking {
                            scrollToBottomNow(proxy: proxy)
                        }
                    }
                    .onAppear {
                        // Scroll to bottom when view appears
                        scrollToBottomNow(proxy: proxy)
                    }
                }

                Spacer(minLength: 0)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    // Error banner (non-critical errors)
                    if let error = session.error, !isCriticalError(error) {
                        ErrorBanner(message: error, onDismiss: {
                            session.error = nil
                        })
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    InputBar(
                        text: $inputText,
                        isDisabled: session.isProcessing,
                        onSend: sendMessage
                    )
                    .focused($isInputFocused)
                }
            }
            .background(Color(hex: "FAFAF8"))

            // File browser
            if showFileBrowser {
                Rectangle()
                    .fill(Color(hex: "E5E5E0"))
                    .frame(width: 1)

                FileBrowserView(rootPath: session.folderPath)
                    .frame(width: 240)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            isInputFocused = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
        .onChange(of: session.error) { _, newError in
            // Show alert for critical errors
            if let error = newError, isCriticalError(error) {
                alertError = SessionError.from(error)
                showErrorAlert = true
            }
        }
        .alert("Session Error", isPresented: $showErrorAlert, presenting: alertError) { error in
            Button("OK") {
                session.error = nil
            }
            if error.isRetryable {
                Button("Retry") {
                    session.error = nil
                    Task {
                        await session.start()
                    }
                }
            }
        } message: { error in
            Text(error.message)
        }
    }

    /// Check if an error is critical and should show an alert instead of a banner
    private func isCriticalError(_ error: String) -> Bool {
        error.contains("Claude CLI not found") ||
        error.contains("Not signed in") ||
        error.contains("Failed to launch") ||
        error.contains("process exited with code")
    }

    private func scrollToBottomNow(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        session.sendMessage(text)
    }
}

// MARK: - Header Bar

struct HeaderBar: View {
    @ObservedObject var session: ChatSession
    @EnvironmentObject var textSizeManager: TextSizeManager
    var onToggleSidebar: (() -> Void)?
    var onNewChat: (() -> Void)?
    var onToggleFiles: (() -> Void)?
    var showingFiles: Bool = false
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Sidebar toggle button
            if let toggle = onToggleSidebar {
                Button(action: toggle) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .buttonStyle(.plain)
            }

            // Folder name
            HStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "E85D04"))

                Text(session.folderName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "444444"))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Model selector (only before session starts)
            if session.messages.isEmpty && !session.isProcessing {
                ModelSelector(selectedModel: Binding(
                    get: { session.selectedModel },
                    set: { session.selectedModel = $0 }
                ))
            } else {
                // Show current model
                HStack(spacing: 4) {
                    Image(systemName: session.selectedModel.icon)
                        .font(.system(size: 10))
                    Text(session.selectedModel.displayName)
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color(hex: "888888"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "F0F0EC"))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Status indicator / Stop button
            if session.isProcessing {
                Button(action: { session.interrupt() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8))
                        Text("Stop")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "E85D04"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Stop Claude")
            }

            // File browser toggle
            if let toggleFiles = onToggleFiles {
                Button(action: toggleFiles) {
                    Image(systemName: showingFiles ? "folder.fill" : "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(showingFiles ? Color(hex: "E85D04") : Color(hex: "888888"))
                }
                .buttonStyle(.plain)
                .help("Toggle file browser")
            }

            // New chat button
            if let newChat = onNewChat {
                Button(action: newChat) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .buttonStyle(.plain)
                .help("New chat")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            Color(hex: "FAFAF8")
                .overlay(
                    Rectangle()
                        .fill(Color(hex: "E8E8E4"))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
        .background(WindowDragGesture())
    }
}

// MARK: - Model Selector

struct ModelSelector: View {
    @Binding var selectedModel: ClaudeModel
    @State private var isExpanded = false

    var body: some View {
        Menu {
            ForEach(ClaudeModel.allCases) { model in
                Button(action: { selectedModel = model }) {
                    HStack {
                        Image(systemName: model.icon)
                        Text(model.displayName)
                        Text("- \(model.description)")
                            .foregroundStyle(.secondary)
                        if model == selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedModel.icon)
                    .font(.system(size: 10))
                Text(selectedModel.displayName)
                    .font(.system(size: 11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(Color(hex: "666666"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "F0F0EC"))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Bouncing Dots

struct BouncingDots: View {
    @State private var activeIndex = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(hex: "E85D04"))
                    .frame(width: 5, height: 5)
                    .offset(y: activeIndex == index ? -3 : 0)
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    activeIndex = (activeIndex + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Window Drag Gesture

struct WindowDragGesture: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: ChatMessage
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var appeared = false

    var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isUser {
                // User message - friendly bubble on right
                HStack {
                    Spacer(minLength: 80)
                    Text(message.content)
                        .font(.system(size: textSizeManager.scaled(14)))
                        .foregroundStyle(Color(hex: "333333"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(hex: "F0F0EC"))
                        )
                        .textSelection(.enabled)
                }
            } else {
                // Claude response - clean left-aligned
                MarkdownContentView(content: message.content)
                    .textSelection(.enabled)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
}

// MARK: - Thinking Row

struct ThinkingRow: View {
    let activity: String
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var dotIndex = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 10) {
            // Animated indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(hex: "E85D04").opacity(opacityFor(index)))
                        .frame(width: 6, height: 6)
                        .scaleEffect(scaleFor(index))
                }
            }

            Text(activity)
                .font(.system(size: textSizeManager.scaled(13)))
                .foregroundStyle(Color(hex: "888888"))
        }
        .padding(.vertical, 8)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    dotIndex = (dotIndex + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func opacityFor(_ index: Int) -> Double {
        let phase = (dotIndex + index) % 3
        return phase == 0 ? 1.0 : (phase == 1 ? 0.5 : 0.25)
    }

    private func scaleFor(_ index: Int) -> Double {
        let phase = (dotIndex + index) % 3
        return phase == 0 ? 1.15 : 1.0
    }
}

// MARK: - Permission Request View

struct PermissionRequestView: View {
    let permission: ChatSession.PermissionRequest
    let onAllow: () -> Void
    let onDeny: () -> Void
    @EnvironmentObject var textSizeManager: TextSizeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "E85D04"))

                Text("Permission Required")
                    .font(.system(size: textSizeManager.scaled(13), weight: .semibold))
                    .foregroundStyle(Color(hex: "333333"))
            }

            // Tool info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Tool:")
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                    Text(permission.toolName)
                        .font(.system(size: textSizeManager.scaled(11), weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "7C3AED"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "F3F0FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if let command = permission.command, !command.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command:")
                            .font(.system(size: textSizeManager.scaled(11)))
                            .foregroundStyle(Color(hex: "888888"))

                        Text(command)
                            .font(.system(size: textSizeManager.scaled(11), design: .monospaced))
                            .foregroundStyle(Color(hex: "333333"))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "F5F5F3"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .textSelection(.enabled)
                    }
                }

                if let desc = permission.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "666666"))
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button(action: onDeny) {
                    Text("Deny")
                        .font(.system(size: textSizeManager.scaled(12), weight: .medium))
                        .foregroundStyle(Color(hex: "666666"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(hex: "F0F0EC"))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onAllow) {
                    Text("Allow")
                        .font(.system(size: textSizeManager.scaled(12), weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(hex: "E85D04"))
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "E85D04").opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    @EnvironmentObject var textSizeManager: TextSizeManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: textSizeManager.scaled(13)))
                .foregroundStyle(Color(hex: "E85D04"))

            Text(message)
                .font(.system(size: textSizeManager.scaled(13)))
                .foregroundStyle(Color(hex: "555555"))
                .lineLimit(1)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: textSizeManager.scaled(11), weight: .semibold))
                    .foregroundStyle(Color(hex: "888888"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "FEF3E7"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(hex: "E85D04").opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - File Browser View

struct FileBrowserView: View {
    let rootPath: String
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var files: [FileItem] = []
    @State private var currentPath: String = ""
    @State private var isLoading = true
    @State private var draggedOver = false

    init(rootPath: String) {
        self.rootPath = rootPath
        self._currentPath = State(initialValue: rootPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("Files")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "555555"))

                Spacer()

                // Up button
                if currentPath != rootPath {
                    Button(action: goUp) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "888888"))
                    }
                    .buttonStyle(.plain)
                }

                // Open in Finder
                Button(action: openInFinder) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .buttonStyle(.plain)
                .help("Open in Finder")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)

            Rectangle()
                .fill(Color(hex: "E8E8E4"))
                .frame(height: 1)

            // Breadcrumb
            if currentPath != rootPath {
                HStack(spacing: 4) {
                    Text(relativePath)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "888888"))
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "F5F5F3"))
            }

            // File list
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(files) { file in
                            FileRow(
                                file: file,
                                onNavigate: { navigateTo(file.path) },
                                onOpen: { openFile(file.path) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color(hex: "F5F5F3"))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(draggedOver ? Color(hex: "E85D04") : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $draggedOver) { providers in
            handleDrop(providers)
        }
        .onAppear { loadFiles() }
        .onChange(of: currentPath) { loadFiles() }
        .onChange(of: rootPath) { _, newRoot in
            // Reset to new root when session changes
            currentPath = newRoot
        }
    }

    private var relativePath: String {
        let rel = currentPath.replacingOccurrences(of: rootPath, with: "")
        return rel.isEmpty ? "/" : rel
    }

    private func loadFiles() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var items: [FileItem] = []

            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: currentPath)

                for name in contents.sorted() {
                    // Skip hidden files
                    guard !name.hasPrefix(".") else { continue }

                    let fullPath = (currentPath as NSString).appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)

                    let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
                    let size = attrs?[.size] as? Int64 ?? 0
                    let modified = attrs?[.modificationDate] as? Date

                    items.append(FileItem(
                        name: name,
                        path: fullPath,
                        isDirectory: isDir.boolValue,
                        size: size,
                        modifiedDate: modified
                    ))
                }

                // Sort: folders first, then by name
                items.sort { a, b in
                    if a.isDirectory != b.isDirectory {
                        return a.isDirectory
                    }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            } catch {
                print("Error loading files: \(error)")
            }

            DispatchQueue.main.async {
                self.files = items
                self.isLoading = false
            }
        }
    }

    private func goUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        if parent.hasPrefix(rootPath) || parent == rootPath {
            currentPath = parent
        } else {
            currentPath = rootPath
        }
    }

    private func navigateTo(_ path: String) {
        currentPath = path
    }

    private func openFile(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: currentPath)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                let sourcePath = url.path
                let fileName = url.lastPathComponent
                let destPath = (currentPath as NSString).appendingPathComponent(fileName)

                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try FileManager.default.copyItem(atPath: sourcePath, toPath: destPath)
                        DispatchQueue.main.async {
                            loadFiles()
                        }
                    } catch {
                        print("Error copying file: \(error)")
                    }
                }
            }
        }
        return true
    }
}

// MARK: - File Item

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date?

    var icon: String {
        if isDirectory {
            return "folder.fill"
        }

        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "json", "xml", "html", "css":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            return "photo"
        case "mp4", "mov", "avi":
            return "film"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "md", "txt":
            return "doc.text"
        case "zip", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory {
            return Color(hex: "E85D04")
        }

        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":
            return Color(hex: "F05138")
        case "py":
            return Color(hex: "3776AB")
        case "js", "ts":
            return Color(hex: "F7DF1E")
        case "json":
            return Color(hex: "000000")
        case "png", "jpg", "jpeg", "gif":
            return Color(hex: "7C3AED")
        default:
            return Color(hex: "888888")
        }
    }

    var formattedSize: String {
        if isDirectory { return "" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return "\(size / (1024 * 1024)) MB"
    }
}

// MARK: - Draggable File Path

struct DraggableFilePath: Transferable {
    let path: String

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { item in
            URL(fileURLWithPath: item.path)
        }
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: FileItem
    let onNavigate: () -> Void  // For navigating into directories (single click)
    let onOpen: () -> Void      // For opening files (double click)
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.icon)
                .font(.system(size: 12))
                .foregroundStyle(file.iconColor)
                .frame(width: 16)

            Text(file.name)
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "333333"))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !file.isDirectory {
                Text(file.formattedSize)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "999999"))
            }

            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "CCCCCC"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color(hex: "EAEAE6") : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double click - open file or navigate into directory
            if file.isDirectory {
                onNavigate()
            } else {
                onOpen()
            }
        }
        .onTapGesture(count: 1) {
            // Single click - only navigate into directories
            if file.isDirectory {
                onNavigate()
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .draggable(DraggableFilePath(path: file.path))
    }
}

#Preview {
    ChatView(session: ChatSession(folderPath: "/Users/test/my-project"), onToggleSidebar: {})
        .environmentObject(TextSizeManager())
        .environmentObject(SessionManager())
        .frame(width: 680, height: 500)
}
