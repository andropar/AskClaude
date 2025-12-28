import XCTest
@testable import AskClaude

final class ClaudeOutputParserTests: XCTestCase {

    // MARK: - System Event Tests

    func testParseSystemEvent() {
        let json = """
        {"type":"system","subtype":"session_started","cwd":"/Users/test/project","session_id":"abc123","model":"claude-3-5-sonnet-20241022","tools":["Read","Write","Bash"]}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .system(let systemEvent) = event else {
            XCTFail("Expected system event")
            return
        }

        XCTAssertEqual(systemEvent.subtype, "session_started")
        XCTAssertEqual(systemEvent.cwd, "/Users/test/project")
        XCTAssertEqual(systemEvent.sessionId, "abc123")
        XCTAssertEqual(systemEvent.model, "claude-3-5-sonnet-20241022")
        XCTAssertEqual(systemEvent.tools, ["Read", "Write", "Bash"])
    }

    // MARK: - Assistant Message Tests

    func testParseAssistantTextMessage() {
        let json = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hello, how can I help?"}]},"session_id":"abc123"}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .assistant(let assistantEvent) = event else {
            XCTFail("Expected assistant event")
            return
        }

        XCTAssertEqual(assistantEvent.content, "Hello, how can I help?")
        XCTAssertEqual(assistantEvent.sessionId, "abc123")
        XCTAssertFalse(assistantEvent.isToolUse)
        XCTAssertNil(assistantEvent.toolName)
    }

    func testParseAssistantToolUseMessage() {
        let json = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","id":"tool_123"}]},"session_id":"abc123"}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .assistant(let assistantEvent) = event else {
            XCTFail("Expected assistant event")
            return
        }

        XCTAssertTrue(assistantEvent.isToolUse)
        XCTAssertEqual(assistantEvent.toolName, "Read")
        XCTAssertEqual(assistantEvent.sessionId, "abc123")
    }

    // MARK: - User Message Tests

    func testParseUserMessage() {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"Show me the README"}]},"session_id":"abc123"}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .user(let userEvent) = event else {
            XCTFail("Expected user event")
            return
        }

        XCTAssertEqual(userEvent.content, "Show me the README")
        XCTAssertEqual(userEvent.sessionId, "abc123")
    }

    // MARK: - Result Event Tests

    func testParseResultSuccess() {
        let json = """
        {"type":"result","subtype":"conversation_turn_completed","is_error":false,"result":"Success","session_id":"abc123","total_cost_usd":0.0045,"duration_ms":1234.5}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .result(let resultEvent) = event else {
            XCTFail("Expected result event")
            return
        }

        XCTAssertEqual(resultEvent.subtype, "conversation_turn_completed")
        XCTAssertFalse(resultEvent.isError)
        XCTAssertEqual(resultEvent.result, "Success")
        XCTAssertEqual(resultEvent.sessionId, "abc123")
        XCTAssertEqual(resultEvent.totalCostUSD, 0.0045)
        XCTAssertEqual(resultEvent.durationMs, 1234.5)
    }

    func testParseResultError() {
        let json = """
        {"type":"result","subtype":"error","is_error":true,"result":"File not found","session_id":"abc123"}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .result(let resultEvent) = event else {
            XCTFail("Expected result event")
            return
        }

        XCTAssertTrue(resultEvent.isError)
        XCTAssertEqual(resultEvent.result, "File not found")
        XCTAssertNil(resultEvent.totalCostUSD)
        XCTAssertNil(resultEvent.durationMs)
    }

    // MARK: - Content Block Tests

    func testParseContentBlockStartText() {
        let json = """
        {"type":"content_block_start","content_block":{"type":"text"}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .contentBlockStart(let startEvent) = event else {
            XCTFail("Expected content block start event")
            return
        }

        if case .text = startEvent.blockType {
            // Success
        } else {
            XCTFail("Expected text block type")
        }
    }

    func testParseContentBlockStartThinking() {
        let json = """
        {"type":"content_block_start","content_block":{"type":"thinking"}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .contentBlockStart(let startEvent) = event else {
            XCTFail("Expected content block start event")
            return
        }

        if case .thinking = startEvent.blockType {
            // Success
        } else {
            XCTFail("Expected thinking block type")
        }
    }

    func testParseContentBlockStartToolUse() {
        let json = """
        {"type":"content_block_start","content_block":{"type":"tool_use","name":"Bash"}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .contentBlockStart(let startEvent) = event else {
            XCTFail("Expected content block start event")
            return
        }

        if case .toolUse(let toolName) = startEvent.blockType {
            XCTAssertEqual(toolName, "Bash")
        } else {
            XCTFail("Expected tool use block type")
        }
    }

    func testParseContentBlockDeltaText() {
        let json = """
        {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .contentBlockDelta(let deltaEvent) = event else {
            XCTFail("Expected content block delta event")
            return
        }

        if case .text(let text) = deltaEvent.deltaType {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text delta type")
        }
    }

    func testParseContentBlockDeltaThinking() {
        let json = """
        {"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"Analyzing..."}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .contentBlockDelta(let deltaEvent) = event else {
            XCTFail("Expected content block delta event")
            return
        }

        if case .thinking(let thinking) = deltaEvent.deltaType {
            XCTAssertEqual(thinking, "Analyzing...")
        } else {
            XCTFail("Expected thinking delta type")
        }
    }

    func testParseContentBlockDeltaToolInput() {
        let json = """
        {"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{\\"path\\":\\"/test\\""}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .contentBlockDelta(let deltaEvent) = event else {
            XCTFail("Expected content block delta event")
            return
        }

        if case .toolInput(let jsonStr) = deltaEvent.deltaType {
            XCTAssertTrue(jsonStr.contains("path"))
        } else {
            XCTFail("Expected tool input delta type")
        }
    }

    func testParseContentBlockStop() {
        let json = """
        {"type":"content_block_stop"}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .contentBlockStop = event else {
            XCTFail("Expected content block stop event")
            return
        }
    }

    // MARK: - Permission Request Tests

    func testParsePermissionRequest() {
        let json = """
        {"session_id":"abc123","hook_event_name":"PermissionRequest","message":"Execute bash command","tool":{"name":"Bash","input":{"command":"ls -la"}}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .permissionRequest(let permEvent) = event else {
            XCTFail("Expected permission request event")
            return
        }

        XCTAssertEqual(permEvent.toolName, "Bash")
        XCTAssertEqual(permEvent.description, "Execute bash command")
        XCTAssertEqual(permEvent.command, "ls -la")
    }

    func testParsePermissionRequestFileOperation() {
        let json = """
        {"session_id":"abc123","hook_event_name":"PermissionRequest","message":"Read file","tool":{"name":"Read","input":{"file_path":"/test/file.txt"}}}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .permissionRequest(let permEvent) = event else {
            XCTFail("Expected permission request event")
            return
        }

        XCTAssertEqual(permEvent.toolName, "Read")
        XCTAssertEqual(permEvent.command, "/test/file.txt")
    }

    // MARK: - Edge Cases

    func testParseInvalidJSON() {
        let json = "{invalid json"
        let event = ClaudeOutputParser.parse(json)
        XCTAssertNil(event)
    }

    func testParseEmptyString() {
        let event = ClaudeOutputParser.parse("")
        XCTAssertNil(event)
    }

    func testParseUnknownType() {
        let json = """
        {"type":"unknown_type","data":"something"}
        """

        let event = ClaudeOutputParser.parse(json)
        XCTAssertNil(event)
    }

    func testParseMissingTypeField() {
        let json = """
        {"data":"something"}
        """

        let event = ClaudeOutputParser.parse(json)
        XCTAssertNil(event)
    }

    func testParseMultipleContentTypes() {
        // Test message with both text and tool_use content
        let json = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Let me check that file."},{"type":"tool_use","name":"Read","id":"tool_456"}]},"session_id":"abc123"}
        """

        let event = ClaudeOutputParser.parse(json)

        guard case .assistant(let assistantEvent) = event else {
            XCTFail("Expected assistant event")
            return
        }

        XCTAssertEqual(assistantEvent.content, "Let me check that file.")
        XCTAssertTrue(assistantEvent.isToolUse)
        XCTAssertEqual(assistantEvent.toolName, "Read")
    }
}
