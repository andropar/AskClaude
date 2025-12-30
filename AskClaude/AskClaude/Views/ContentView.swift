import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var sidebarVisible = false
    @State private var sidebarWidth: CGFloat = 240

    var body: some View {
        ZStack {
            // Warm off-white background
            Color(hex: "FAFAF8")
                .ignoresSafeArea()

            if sessionManager.sessions.isEmpty {
                OnboardingView()
            } else {
                HStack(spacing: 0) {
                    // Sidebar
                    if sidebarVisible {
                        SidebarView(sidebarWidth: sidebarWidth)
                            .frame(width: sidebarWidth, alignment: .leading)
                            .frame(minWidth: sidebarWidth, maxWidth: sidebarWidth)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    // Divider
                    if sidebarVisible {
                        Rectangle()
                            .fill(Color(hex: "E5E5E0"))
                            .frame(width: 1)
                    }

                    // Main content
                    if let session = sessionManager.activeSession {
                        ChatView(session: session, onToggleSidebar: toggleSidebar)
                    } else {
                        // No active session selected
                        VStack {
                            Spacer()
                            Text("Select a chat")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(hex: "888888"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            sidebarVisible.toggle()
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var textSizeManager: TextSizeManager
    let sidebarWidth: CGFloat

    // Group sessions by folder path
    private var groupedSessions: [String: [ChatSession]] {
        Dictionary(grouping: sessionManager.sessions) { $0.folderPath }
    }

    private var sortedFolderPaths: [String] {
        groupedSessions.keys.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack {
                Text("Chats")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "555555"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            Rectangle()
                .fill(Color(hex: "E8E8E4"))
                .frame(height: 1)

            // Workspaces list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(sortedFolderPaths, id: \.self) { folderPath in
                        WorkspaceRow(
                            folderPath: folderPath,
                            sessions: groupedSessions[folderPath] ?? []
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer(minLength: 0)
        }
        .background(Color(hex: "F5F5F3"))
    }
}

// MARK: - Workspace Row (Collapsible folder with chats)

struct WorkspaceRow: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var textSizeManager: TextSizeManager
    let folderPath: String
    let sessions: [ChatSession]

    @State private var isExpanded = true
    @State private var isHovered = false

    private var folderName: String {
        (folderPath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Folder header
            HStack(spacing: 8) {
                Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "888888"))
                            .frame(width: 12)

                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "E85D04"))

                        Text(folderName)
                            .font(.system(size: textSizeManager.scaled(12), weight: .medium))
                            .foregroundStyle(Color(hex: "333333"))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isHovered {
                    Button(action: { sessionManager.closeWorkspace(folderPath: folderPath) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "888888"))
                            .padding(4)
                            .background(Circle().fill(Color(hex: "E5E5E0")))
                    }
                    .buttonStyle(.plain)
                    .help("Remove workspace")
                } else {
                    Text("\(sessions.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "888888"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: "E5E5E0"))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }

            // Chat list (when expanded)
            if isExpanded {
                ForEach(sessions) { session in
                    ChatRow(session: session)
                }
            }
        }
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var textSizeManager: TextSizeManager
    @ObservedObject var session: ChatSession

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""

    private var isActive: Bool {
        sessionManager.activeSessionId == session.id
    }

    private var timeAgo: String {
        // Just show message count for now
        let count = session.messages.count
        if count == 0 { return "Empty" }
        return "\(count) msg\(count == 1 ? "" : "s")"
    }

    var body: some View {
        Button(action: { sessionManager.setActiveSession(session) }) {
            HStack(spacing: 8) {
                // Indent for hierarchy
                Spacer()
                    .frame(width: 20)

                Image(systemName: "bubble.left")
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? Color(hex: "E85D04") : Color(hex: "999999"))

                VStack(alignment: .leading, spacing: 2) {
                    if isRenaming {
                        TextField("Chat name", text: $renameText, onCommit: commitRename)
                            .textFieldStyle(.plain)
                            .font(.system(size: textSizeManager.scaled(11)))
                            .foregroundStyle(Color(hex: "1A1A1A"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                            )
                            .onExitCommand(perform: cancelRename)
                    } else {
                        Text(session.displayTitle)
                            .font(.system(size: textSizeManager.scaled(11)))
                            .foregroundStyle(isActive ? Color(hex: "1A1A1A") : Color(hex: "555555"))
                            .lineLimit(1)
                    }

                    Text(timeAgo)
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: "999999"))
                }

                Spacer()

                // Close button on hover
                if isHovered && !isRenaming {
                    Button(action: { sessionManager.closeSession(session) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "888888"))
                            .padding(4)
                            .background(Circle().fill(Color(hex: "E5E5E0")))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color(hex: "E85D04").opacity(0.1) : (isHovered ? Color(hex: "EAEAE6") : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: startRename) {
                Label("Rename", systemImage: "pencil")
            }
            if session.customName != nil {
                Button(action: clearCustomName) {
                    Label("Reset Name", systemImage: "arrow.counterclockwise")
                }
            }
            Divider()
            Button(role: .destructive, action: { sessionManager.closeSession(session) }) {
                Label("Close", systemImage: "xmark")
            }
        }
        .padding(.horizontal, 8)
    }

    private func startRename() {
        renameText = session.customName ?? session.displayTitle
        isRenaming = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            session.rename(to: trimmed)
        }
        isRenaming = false
    }

    private func cancelRename() {
        isRenaming = false
    }

    private func clearCustomName() {
        session.rename(to: nil)
    }
}

// MARK: - Onboarding View (Empty State)

struct OnboardingView: View {
    @State private var appeared = false
    @State private var claudeStatus: ClaudeStatus = .checking

    enum ClaudeStatus {
        case checking
        case notInstalled
        case notAuthenticated
        case ready
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle area
            DragHandleView()
                .frame(height: 52)

            Spacer()

            VStack(spacing: 32) {
                // Logo mark
                ZStack {
                    // Soft glow
                    Circle()
                        .fill(Color(hex: "E85D04").opacity(0.12))
                        .frame(width: 140, height: 140)
                        .blur(radius: 50)

                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B35"), Color(hex: "E85D04")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: Color(hex: "E85D04").opacity(0.3), radius: 20, y: 8)

                        Image(systemName: "sparkle")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

                // Text
                VStack(spacing: 12) {
                    Text("Ask Claude")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(Color(hex: "1A1A1A"))

                    statusView
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            }

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
            checkClaudeStatus()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch claudeStatus {
        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Checking Claude Code...")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "888888"))
            }

        case .notInstalled:
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(hex: "E85D04"))
                    Text("Claude Code not found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "333333"))
                }

                Text("Install Claude Code CLI to get started")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "666666"))

                Button(action: openInstallPage) {
                    Text("Install Claude Code")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "E85D04"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

        case .notAuthenticated:
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(Color(hex: "E85D04"))
                    Text("Not signed in")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "333333"))
                }

                Text("Run 'claude' in Terminal to sign in")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "666666"))

                Button(action: openTerminal) {
                    Text("Open Terminal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "E85D04"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

        case .ready:
            VStack(spacing: 16) {
                Text("Right-click a folder in Finder to start")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "666666"))

                Text("You can close this window — AskClaude runs in the background and will open automatically when you select \"Ask Claude\" from Finder.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "999999"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
    }

    private func checkClaudeStatus() {
        Task { @MainActor in
            // Check if Claude is installed
            let possiblePaths = [
                "/Users/\(NSUserName())/.local/bin/claude",
                "/usr/local/bin/claude",
                "/opt/homebrew/bin/claude",
                "\(NSHomeDirectory())/.local/bin/claude"
            ]

            var claudeFound = false
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    claudeFound = true
                    break
                }
            }

            if !claudeFound {
                withAnimation { claudeStatus = .notInstalled }
                return
            }

            // Check authentication
            let manager = ClaudeProcessManager()
            let isAuthenticated = await manager.checkAuthentication()
            withAnimation {
                claudeStatus = isAuthenticated ? .ready : .notAuthenticated
            }
        }
    }

    private func openInstallPage() {
        if let url = URL(string: "https://claude.ai/download") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openTerminal() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
    }
}


// MARK: - Drag Handle View

struct DragHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionManager())
        .environmentObject(TextSizeManager())
        .frame(width: 680, height: 500)
}
