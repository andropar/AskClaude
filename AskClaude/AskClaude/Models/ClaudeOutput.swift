import Foundation

/// Parses Claude CLI stream-json output
enum ClaudeOutputParser {

    /// Parse a single line of JSON output from Claude
    static func parse(_ line: String) -> ClaudeEvent? {
        guard let data = line.data(using: .utf8) else { return nil }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            // Check for hook event (permission request) - these may not have a "type" field
            if let hookEventName = json["hook_event_name"] as? String, hookEventName == "PermissionRequest" {
                return parsePermissionRequest(json)
            }

            guard let type = json["type"] as? String else {
                print("[ClaudeOutputParser] No type field in: \(json)")
                return nil
            }

            switch type {
            case "system":
                return parseSystemMessage(json)
            case "assistant":
                return parseAssistantMessage(json)
            case "user":
                return parseUserMessage(json)
            case "result":
                return parseResultMessage(json)
            case "content_block_start":
                return parseContentBlockStart(json)
            case "content_block_delta":
                return parseContentBlockDelta(json)
            case "content_block_stop":
                return .contentBlockStop
            case "permission_request":
                return parsePermissionRequest(json)
            default:
                print("[ClaudeOutputParser] Unknown type: \(type)")
                print("[ClaudeOutputParser] Full JSON: \(json)")
                return nil
            }
        } catch {
            print("[ClaudeOutputParser] JSON parse error: \(error)")
            return nil
        }
    }

    private static func parseSystemMessage(_ json: [String: Any]) -> ClaudeEvent? {
        let subtype = json["subtype"] as? String ?? ""
        let cwd = json["cwd"] as? String ?? ""
        let sessionId = json["session_id"] as? String ?? ""
        let model = json["model"] as? String ?? ""
        let tools = json["tools"] as? [String] ?? []

        return .system(SystemEvent(
            subtype: subtype,
            cwd: cwd,
            sessionId: sessionId,
            model: model,
            tools: tools
        ))
    }

    private static func parseAssistantMessage(_ json: [String: Any]) -> ClaudeEvent? {
        guard let message = json["message"] as? [String: Any],
              let contentArray = message["content"] as? [[String: Any]] else {
            return nil
        }

        var textContent = ""
        var isToolUse = false
        var toolName: String?

        for content in contentArray {
            if let type = content["type"] as? String {
                if type == "text", let text = content["text"] as? String {
                    textContent += text
                } else if type == "tool_use" {
                    isToolUse = true
                    toolName = content["name"] as? String
                }
            }
        }

        let sessionId = json["session_id"] as? String ?? ""

        return .assistant(AssistantEvent(
            content: textContent,
            sessionId: sessionId,
            isToolUse: isToolUse,
            toolName: toolName
        ))
    }

    private static func parseUserMessage(_ json: [String: Any]) -> ClaudeEvent? {
        guard let message = json["message"] as? [String: Any],
              let contentArray = message["content"] as? [[String: Any]] else {
            return nil
        }

        var textContent = ""
        for content in contentArray {
            if let type = content["type"] as? String, type == "text",
               let text = content["text"] as? String {
                textContent += text
            }
        }

        let sessionId = json["session_id"] as? String ?? ""

        return .user(UserEvent(
            content: textContent,
            sessionId: sessionId
        ))
    }

    private static func parseResultMessage(_ json: [String: Any]) -> ClaudeEvent? {
        let subtype = json["subtype"] as? String ?? ""
        let isError = json["is_error"] as? Bool ?? false
        let result = json["result"] as? String ?? ""
        let sessionId = json["session_id"] as? String ?? ""
        let cost = json["total_cost_usd"] as? Double
        let duration = json["duration_ms"] as? Double

        return .result(ResultEvent(
            subtype: subtype,
            isError: isError,
            result: result,
            sessionId: sessionId,
            totalCostUSD: cost,
            durationMs: duration
        ))
    }

    private static func parseContentBlockStart(_ json: [String: Any]) -> ClaudeEvent? {
        guard let contentBlock = json["content_block"] as? [String: Any],
              let type = contentBlock["type"] as? String else {
            return nil
        }

        if type == "tool_use" {
            let toolName = contentBlock["name"] as? String ?? "unknown"
            return .contentBlockStart(ContentBlockStartEvent(blockType: .toolUse(toolName)))
        } else if type == "text" {
            return .contentBlockStart(ContentBlockStartEvent(blockType: .text))
        } else if type == "thinking" {
            return .contentBlockStart(ContentBlockStartEvent(blockType: .thinking))
        }

        return nil
    }

    private static func parseContentBlockDelta(_ json: [String: Any]) -> ClaudeEvent? {
        guard let delta = json["delta"] as? [String: Any],
              let type = delta["type"] as? String else {
            return nil
        }

        if type == "text_delta", let text = delta["text"] as? String {
            return .contentBlockDelta(ContentBlockDeltaEvent(deltaType: .text(text)))
        } else if type == "thinking_delta", let thinking = delta["thinking"] as? String {
            return .contentBlockDelta(ContentBlockDeltaEvent(deltaType: .thinking(thinking)))
        } else if type == "input_json_delta", let json = delta["partial_json"] as? String {
            return .contentBlockDelta(ContentBlockDeltaEvent(deltaType: .toolInput(json)))
        }

        return nil
    }

    private static func parsePermissionRequest(_ json: [String: Any]) -> ClaudeEvent? {
        // Format from --permission-prompt-tool stdio:
        // {"session_id":"...","hook_event_name":"PermissionRequest","message":"...","tool":{"name":"...","input":{...}}}
        let toolName: String
        var command: String?
        var toolInput: [String: Any]?

        if let tool = json["tool"] as? [String: Any] {
            toolName = tool["name"] as? String ?? "Unknown"
            toolInput = tool["input"] as? [String: Any]
            if let input = toolInput {
                // For Bash commands, extract the command
                if let cmd = input["command"] as? String {
                    command = cmd
                }
                // For file operations, show the path
                else if let path = input["file_path"] as? String {
                    command = path
                }
            }
        } else {
            toolName = json["tool_name"] as? String ?? "Unknown"
            command = json["command"] as? String
        }

        let requestId = json["request_id"] as? String ?? json["session_id"] as? String ?? UUID().uuidString
        let description = json["message"] as? String ?? json["description"] as? String

        return .permissionRequest(PermissionRequestEvent(
            requestId: requestId,
            toolName: toolName,
            description: description,
            command: command,
            toolInput: toolInput
        ))
    }
}

// MARK: - Event Types

enum ClaudeEvent {
    case system(SystemEvent)
    case assistant(AssistantEvent)
    case user(UserEvent)
    case result(ResultEvent)
    case contentBlockStart(ContentBlockStartEvent)
    case contentBlockDelta(ContentBlockDeltaEvent)
    case contentBlockStop
    case permissionRequest(PermissionRequestEvent)
}

struct SystemEvent {
    let subtype: String
    let cwd: String
    let sessionId: String
    let model: String
    let tools: [String]
}

struct AssistantEvent {
    let content: String
    let sessionId: String
    let isToolUse: Bool
    let toolName: String?
}

struct UserEvent {
    let content: String
    let sessionId: String
}

struct ResultEvent {
    let subtype: String
    let isError: Bool
    let result: String
    let sessionId: String
    let totalCostUSD: Double?
    let durationMs: Double?
}

struct ContentBlockStartEvent {
    enum BlockType {
        case text
        case thinking
        case toolUse(String)
    }
    let blockType: BlockType
}

struct ContentBlockDeltaEvent {
    enum DeltaType {
        case text(String)
        case thinking(String)
        case toolInput(String)
    }
    let deltaType: DeltaType
}

struct PermissionRequestEvent {
    let requestId: String
    let toolName: String
    let description: String?
    let command: String?
    let toolInput: [String: Any]?
}
