import Foundation

/// Handles saving and loading chat history for workspaces
class ChatPersistence {
    private let fileManager = FileManager.default

    /// Directory name for storing chat data in each workspace
    private let chatDirName = ".askclaude"
    private let historyFileName = "chat_history.json"

    /// Get the chat directory path for a workspace
    private func chatDirectory(for workspacePath: String) -> URL {
        URL(fileURLWithPath: workspacePath).appendingPathComponent(chatDirName)
    }

    /// Get the history file path for a workspace
    private func historyFile(for workspacePath: String) -> URL {
        chatDirectory(for: workspacePath).appendingPathComponent(historyFileName)
    }

    /// Save messages to workspace
    func saveMessages(_ messages: [ChatMessage], for workspacePath: String) {
        let chatDir = chatDirectory(for: workspacePath)
        let historyFile = historyFile(for: workspacePath)

        do {
            // Create directory if needed
            if !fileManager.fileExists(atPath: chatDir.path) {
                try fileManager.createDirectory(at: chatDir, withIntermediateDirectories: true)
            }

            // Convert messages to saveable format
            let saveableMessages = messages.map { SaveableMessage(from: $0) }

            // Encode and save
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(saveableMessages)
            try data.write(to: historyFile)

            print("[ChatPersistence] Saved \(messages.count) messages to \(historyFile.path)")
        } catch {
            print("[ChatPersistence] Failed to save: \(error)")
        }
    }

    /// Load messages from workspace
    func loadMessages(for workspacePath: String) -> [ChatMessage] {
        let historyFile = historyFile(for: workspacePath)

        guard fileManager.fileExists(atPath: historyFile.path) else {
            print("[ChatPersistence] No history file at \(historyFile.path)")
            return []
        }

        do {
            let data = try Data(contentsOf: historyFile)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let saveableMessages = try decoder.decode([SaveableMessage].self, from: data)
            let messages = saveableMessages.map { $0.toChatMessage() }

            print("[ChatPersistence] Loaded \(messages.count) messages from \(historyFile.path)")
            return messages
        } catch {
            print("[ChatPersistence] Failed to load: \(error)")
            return []
        }
    }

    /// Clear history for a workspace
    func clearHistory(for workspacePath: String) {
        let historyFile = historyFile(for: workspacePath)

        do {
            if fileManager.fileExists(atPath: historyFile.path) {
                try fileManager.removeItem(at: historyFile)
                print("[ChatPersistence] Cleared history at \(historyFile.path)")
            }
        } catch {
            print("[ChatPersistence] Failed to clear: \(error)")
        }
    }

    /// Check if workspace has chat history
    func hasHistory(for workspacePath: String) -> Bool {
        let historyFile = historyFile(for: workspacePath)
        return fileManager.fileExists(atPath: historyFile.path)
    }
}

// MARK: - Saveable Message

struct SaveableMessage: Codable {
    let id: String
    let role: String
    let content: String
    let timestamp: Date

    init(from message: ChatMessage) {
        self.id = message.id.uuidString
        self.role = message.role.rawValue
        self.content = message.content
        self.timestamp = message.timestamp
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: UUID(uuidString: id) ?? UUID(),
            role: ChatMessage.Role(rawValue: role) ?? .user,
            content: content,
            timestamp: timestamp
        )
    }
}

// MARK: - Extended ChatMessage

extension ChatMessage {
    init(id: UUID, role: Role, content: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = false
    }
}
