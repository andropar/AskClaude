import Foundation
import Combine

// MARK: - Claude Model

enum ClaudeModel: String, CaseIterable, Identifiable {
    case haiku = "haiku"
    case sonnet = "sonnet"
    case opus = "opus"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku: return "Haiku"
        case .sonnet: return "Sonnet"
        case .opus: return "Opus"
        }
    }

    var icon: String {
        switch self {
        case .haiku: return "hare"
        case .sonnet: return "bolt"
        case .opus: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .haiku: return "Fast & light"
        case .sonnet: return "Balanced"
        case .opus: return "Most capable"
        }
    }
}

@MainActor
class ChatSession: ObservableObject, Identifiable {
    let id: UUID
    let folderPath: String
    let folderName: String
    let selectedItem: String?  // The file/folder that was right-clicked

    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var isThinking = false
    @Published var currentActivity: String?
    @Published var error: String?
    @Published var sessionInfo: SessionInfo?
    @Published var pendingPermission: PermissionRequest?
    @Published var selectedModel: ClaudeModel = .haiku

    struct PermissionRequest: Identifiable {
        let id: String
        let toolName: String
        let description: String?
        let command: String?
    }

    private var processManager: ClaudeProcessManager?
    private let persistence = ChatPersistence()
    private var currentStreamingMessageId: UUID?
    private var currentBlockType: ContentBlockStartEvent.BlockType?
    private var hasSentInitialContext = false
    private var errorObserver: AnyCancellable?

    struct SessionInfo {
        let model: String
        let sessionId: String
    }

    init(folderPath: String, selectedItem: String? = nil) {
        self.id = UUID()
        self.folderPath = folderPath
        self.folderName = (folderPath as NSString).lastPathComponent
        self.selectedItem = selectedItem

        // Start with empty messages - each session is a fresh chat
        self.messages = []
    }

    private func setupEventHandler() {
        processManager?.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleEvent(event)
            }
        }
    }

    func start() async {
        // Create process manager with selected model
        let manager = ClaudeProcessManager()
        self.processManager = manager
        setupEventHandler()

        // Observe process manager errors and propagate them to session
        errorObserver = manager.$error
            .sink { [weak self] managerError in
                if let managerError = managerError {
                    self?.error = managerError
                }
            }

        do {
            try await manager.startSession(in: folderPath, model: selectedModel.rawValue)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)

        // Save after adding user message
        saveHistory()

        isProcessing = true
        isThinking = true
        currentActivity = "Thinking..."

        // On first message, add context about the selected file/folder
        var messageToSend = content
        if !hasSentInitialContext, let selected = selectedItem {
            let itemName = (selected as NSString).lastPathComponent
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: selected, isDirectory: &isDirectory)

            if exists {
                let itemType = isDirectory.boolValue ? "folder" : "file"
                let contextPrefix = "[Context: User right-clicked on \(itemType) \"\(itemName)\" at path: \(selected)]\n\n"
                messageToSend = contextPrefix + content
            }
            hasSentInitialContext = true
        }

        processManager?.sendMessage(messageToSend)
    }

    func stop() {
        processManager?.stopSession()

        // Mark any streaming message as complete before resetting
        if let msgId = currentStreamingMessageId,
           let index = messages.firstIndex(where: { $0.id == msgId }) {
            messages[index].isStreaming = false
        }

        // Reset all state to prevent stale data
        isProcessing = false
        isThinking = false
        currentActivity = nil
        pendingPermission = nil
        currentStreamingMessageId = nil
        currentBlockType = nil
    }

    func interrupt() {
        processManager?.interrupt()
        isProcessing = false
        isThinking = false
        currentActivity = nil
        pendingPermission = nil

        // Mark any streaming message as complete before resetting
        if let msgId = currentStreamingMessageId,
           let index = messages.firstIndex(where: { $0.id == msgId }) {
            messages[index].isStreaming = false
        }

        // Reset streaming state to prevent stale references
        currentStreamingMessageId = nil
        currentBlockType = nil

        // Add a system message indicating interruption
        let interruptMessage = ChatMessage(role: .assistant, content: "*Interrupted by user*")
        messages.append(interruptMessage)
    }

    func clearHistory() {
        messages.removeAll()
        persistence.clearHistory(for: folderPath)
    }

    func clearError() {
        error = nil
    }

    private func saveHistory() {
        // Only save non-streaming messages
        let completedMessages = messages.filter { !$0.isStreaming }
        persistence.saveMessages(completedMessages, for: folderPath)
    }

    private func handleEvent(_ event: ClaudeEvent) {
        switch event {
        case .system(let systemEvent):
            sessionInfo = SessionInfo(
                model: systemEvent.model,
                sessionId: systemEvent.sessionId
            )

        case .contentBlockStart(let startEvent):
            currentBlockType = startEvent.blockType

            switch startEvent.blockType {
            case .text:
                // Start a new assistant message for text
                isThinking = false
                currentActivity = nil
                let message = ChatMessage(role: .assistant, content: "", isStreaming: true)
                currentStreamingMessageId = message.id
                messages.append(message)

            case .thinking:
                isThinking = true
                currentActivity = "Thinking..."

            case .toolUse(let toolName):
                isThinking = true
                currentActivity = formatToolActivity(toolName)
            }

        case .contentBlockDelta(let deltaEvent):
            switch deltaEvent.deltaType {
            case .text(let text):
                // Append text to current streaming message
                if let msgId = currentStreamingMessageId,
                   let index = messages.firstIndex(where: { $0.id == msgId }) {
                    messages[index].content += text
                }

            case .thinking:
                // We just show "Thinking..." - don't display actual thinking content
                break

            case .toolInput:
                // Tool input JSON - we don't need to display this
                break
            }

        case .contentBlockStop:
            // Block finished
            if case .text = currentBlockType {
                // Mark the message as done streaming
                if let msgId = currentStreamingMessageId,
                   let index = messages.firstIndex(where: { $0.id == msgId }) {
                    messages[index].isStreaming = false
                }
            }
            currentBlockType = nil

        case .assistant(let assistantEvent):
            // This is the final message with full content
            // If we have tool use, show activity
            if assistantEvent.isToolUse, let toolName = assistantEvent.toolName {
                isThinking = true
                currentActivity = formatToolActivity(toolName)
            }

            // If there's text content and we don't have a streaming message, add it
            if !assistantEvent.content.isEmpty && currentStreamingMessageId == nil {
                let message = ChatMessage(role: .assistant, content: assistantEvent.content)
                messages.append(message)
            }

        case .user:
            // User messages echoed back - ignore since we already added them
            break

        case .result(let resultEvent):
            // Conversation turn complete

            // Mark any streaming message as complete before clearing state
            // (safety measure in case contentBlockStop was missed)
            if let msgId = currentStreamingMessageId,
               let index = messages.firstIndex(where: { $0.id == msgId }) {
                messages[index].isStreaming = false
            }

            isProcessing = false
            isThinking = false
            currentActivity = nil
            currentStreamingMessageId = nil
            currentBlockType = nil

            if resultEvent.isError {
                error = resultEvent.result
            }

            // Save after conversation turn completes
            saveHistory()

        case .permissionRequest(let permEvent):
            // Show permission request UI
            pendingPermission = PermissionRequest(
                id: permEvent.requestId,
                toolName: permEvent.toolName,
                description: permEvent.description,
                command: permEvent.command
            )
            currentActivity = "Waiting for approval..."
        }
    }

    func respondToPermission(allow: Bool) {
        guard let permission = pendingPermission else { return }
        processManager?.sendPermissionResponse(requestId: permission.id, allow: allow)
        pendingPermission = nil
        if allow {
            currentActivity = formatToolActivity(permission.toolName)
        } else {
            currentActivity = nil
            isThinking = false
        }
    }

    private func formatToolActivity(_ toolName: String) -> String {
        switch toolName {
        case "Read":
            return "Reading file..."
        case "Write":
            return "Writing file..."
        case "Edit":
            return "Editing file..."
        case "Bash":
            return "Running command..."
        case "Glob":
            return "Searching files..."
        case "Grep":
            return "Searching content..."
        case "Task":
            return "Running task..."
        case "TodoWrite":
            return "Updating tasks..."
        case "WebFetch":
            return "Fetching web content..."
        case "WebSearch":
            return "Searching web..."
        default:
            return "Using \(toolName)..."
        }
    }
}

// MARK: - Session Manager

@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var activeSessionId: UUID?
    private var folderOpenObserver: NSObjectProtocol?

    var activeSession: ChatSession? {
        sessions.first { $0.id == activeSessionId }
    }

    init() {
        // Listen for folder open notifications from IPC/URL scheme
        folderOpenObserver = NotificationCenter.default.addObserver(
            forName: .openSessionForFolder,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let path = notification.userInfo?["path"] as? String {
                let selectedItem = notification.userInfo?["selectedItem"] as? String
                Task { @MainActor [weak self] in
                    await self?.createSession(for: path, selectedItem: selectedItem)
                }
            }
        }
    }

    deinit {
        if let observer = folderOpenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func createSession(for folderPath: String, selectedItem: String? = nil) async {
        // Always create a new session (new chat) for each request
        let session = ChatSession(folderPath: folderPath, selectedItem: selectedItem)
        sessions.append(session)
        activeSessionId = session.id

        await session.start()
    }

    func closeSession(_ session: ChatSession) {
        session.stop()
        sessions.removeAll { $0.id == session.id }

        if activeSessionId == session.id {
            activeSessionId = sessions.first?.id
        }
    }

    func closeWorkspace(folderPath: String) {
        // Close all sessions for this folder
        let sessionsToClose = sessions.filter { $0.folderPath == folderPath }
        for session in sessionsToClose {
            session.stop()
        }
        sessions.removeAll { $0.folderPath == folderPath }

        // Update active session if needed
        if let activeId = activeSessionId,
           sessionsToClose.contains(where: { $0.id == activeId }) {
            activeSessionId = sessions.first?.id
        }
    }

    func setActiveSession(_ session: ChatSession) {
        activeSessionId = session.id
    }
}
