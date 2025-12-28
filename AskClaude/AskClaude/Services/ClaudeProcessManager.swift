import Foundation
import SwiftUI

/// Manages the Claude CLI process lifecycle and I/O
@MainActor
class ClaudeProcessManager: ObservableObject {
    @Published var isRunning = false
    @Published var isProcessing = false
    @Published var error: String?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private var outputBuffer = ""

    var onEvent: ((ClaudeEvent) -> Void)?

    /// Find the claude CLI executable
    private var claudePath: String? {
        let possiblePaths = [
            "/Users/\(NSUserName())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try using 'which' to find it
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()

            let fileHandle = pipe.fileHandleForReading
            let data = fileHandle.readDataToEndOfFile()
            try? fileHandle.close()

            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            print("[ClaudeProcessManager] 'which claude' failed: \(error)")
        }

        return nil
    }

    func startSession(in directory: String, model: String = "haiku") async throws {
        guard let claudePath = claudePath else {
            throw ClaudeError.notFound
        }

        print("[ClaudeProcessManager] Starting session in: \(directory)")
        print("[ClaudeProcessManager] Using claude at: \(claudePath)")
        print("[ClaudeProcessManager] Using model: \(model)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)

        // System prompt that tells Claude about the file preview feature
        let systemPrompt = """
        You are running inside AskClaude, a macOS app that provides a chat interface for Claude Code.

        IMPORTANT: You can show file previews inline in your responses using the syntax ![[path]].
        When you want to show a file to the user (image, code file, PDF, CSV, video), use this syntax:
        - ![[/path/to/image.png]] - Shows an image preview
        - ![[/path/to/code.swift]] - Shows syntax-highlighted code
        - ![[/path/to/document.pdf]] - Shows a PDF preview
        - ![[/path/to/data.csv]] - Shows a formatted table
        - ![[/path/to/video.mp4]] - Shows a video player

        Use absolute paths. This is especially useful when the user asks you to show them a file, or when you want to visually demonstrate something you've created or found.
        """

        var arguments = [
            "-p",  // Print mode
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose",
            "--model", model,  // Model selection
            "--system-prompt", systemPrompt
        ]

        // Add permission handling based on settings
        if SettingsManager.shared.autoApprovePermissions {
            arguments.append("--dangerously-skip-permissions")
        }

        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        // Setup pipes
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        // Setup async output reading
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.processOutput(output)
                }
            }
        }

        // Also capture stderr for debugging
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("[Claude stderr] \(output)")
            }
        }

        // Handle process termination
        process.terminationHandler = { [weak self] proc in
            let exitCode = proc.terminationStatus
            Task { @MainActor [weak self] in
                self?.handleTermination(exitCode: exitCode)
            }
        }

        do {
            try process.run()
            isRunning = true
            error = nil
            print("[ClaudeProcessManager] Process started with PID: \(process.processIdentifier)")
        } catch {
            throw ClaudeError.launchFailed(error.localizedDescription)
        }
    }

    func sendMessage(_ message: String) {
        guard let stdinPipe = stdinPipe, isRunning else {
            print("[ClaudeProcessManager] Cannot send message - not running")
            return
        }

        // Format as stream-json input
        // Format: {"type":"user","message":{"role":"user","content":"..."}}
        let inputMessage: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": message
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: inputMessage)
            if var jsonString = String(data: data, encoding: .utf8) {
                jsonString += "\n"
                if let inputData = jsonString.data(using: .utf8) {
                    stdinPipe.fileHandleForWriting.write(inputData)
                    isProcessing = true
                    print("[ClaudeProcessManager] Sent message: \(message.prefix(50))...")
                }
            }
        } catch {
            print("[ClaudeProcessManager] Failed to encode message: \(error)")
        }
    }

    func sendPermissionResponse(requestId: String, allow: Bool) {
        guard let stdinPipe = stdinPipe, isRunning else {
            print("[ClaudeProcessManager] Cannot send permission response - not running")
            return
        }

        // Format for --permission-prompt-tool stdio:
        // Allow: {"behavior":"allow","updatedInput":{}}
        // Deny: {"behavior":"deny","message":"User denied"}
        let response: [String: Any]
        if allow {
            response = [
                "behavior": "allow",
                "updatedInput": [String: Any]()
            ]
        } else {
            response = [
                "behavior": "deny",
                "message": "User denied the request"
            ]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            if var jsonString = String(data: data, encoding: .utf8) {
                jsonString += "\n"
                if let inputData = jsonString.data(using: .utf8) {
                    stdinPipe.fileHandleForWriting.write(inputData)
                    print("[ClaudeProcessManager] Sent permission response: \(allow ? "ALLOW" : "DENY")")
                }
            }
        } catch {
            print("[ClaudeProcessManager] Failed to encode permission response: \(error)")
        }
    }

    func interrupt() {
        guard let process = process, process.isRunning else {
            print("[ClaudeProcessManager] No process to interrupt")
            return
        }

        print("[ClaudeProcessManager] Sending SIGINT to interrupt")
        process.interrupt()  // Sends SIGINT
    }

    func stopSession() {
        print("[ClaudeProcessManager] Stopping session")

        // Clear handlers first to prevent any callbacks during cleanup
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        // Close file handles to ensure they're properly released
        try? stdoutPipe?.fileHandleForReading.close()
        try? stderrPipe?.fileHandleForReading.close()
        try? stdinPipe?.fileHandleForWriting.close()

        if process?.isRunning == true {
            process?.terminate()
        }

        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        isRunning = false
        isProcessing = false
    }

    private func processOutput(_ output: String) {
        outputBuffer += output

        // Process complete lines
        while let newlineIndex = outputBuffer.firstIndex(of: "\n") {
            let line = String(outputBuffer[..<newlineIndex])
            outputBuffer = String(outputBuffer[outputBuffer.index(after: newlineIndex)...])

            if !line.isEmpty {
                if let event = ClaudeOutputParser.parse(line) {
                    handleEvent(event)
                }
            }
        }
    }

    private func handleEvent(_ event: ClaudeEvent) {
        print("[ClaudeProcessManager] Event: \(event)")

        switch event {
        case .result:
            isProcessing = false
        default:
            break
        }

        onEvent?(event)
    }

    private func handleTermination(exitCode: Int32) {
        print("[ClaudeProcessManager] Process terminated with exit code: \(exitCode)")
        isRunning = false
        isProcessing = false

        if exitCode != 0 {
            error = "Claude process exited with code \(exitCode)"
        }
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case notFound
    case notAuthenticated
    case launchFailed(String)
    case notRunning

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Claude CLI not found. Please ensure Claude Code is installed."
        case .notAuthenticated:
            return "Not signed in to Claude Code. Please run 'claude' in Terminal to sign in."
        case .launchFailed(let reason):
            return "Failed to launch Claude: \(reason)"
        case .notRunning:
            return "Claude process is not running"
        }
    }
}

// MARK: - Auth Check

extension ClaudeProcessManager {
    /// Check if Claude Code is authenticated
    nonisolated func checkAuthentication() async -> Bool {
        guard let claudePath = await MainActor.run(body: { self.claudePath }) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = ["-p", "--output-format", "json", "echo test"]

            let stderrPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                // Check stderr for auth errors
                let stderrHandle = stderrPipe.fileHandleForReading
                let stderrData = stderrHandle.readDataToEndOfFile()
                try? stderrHandle.close()

                if let stderrOutput = String(data: stderrData, encoding: .utf8) {
                    if stderrOutput.contains("not logged in") ||
                       stderrOutput.contains("authenticate") ||
                       stderrOutput.contains("sign in") {
                        continuation.resume(returning: false)
                        return
                    }
                }

                // Exit code 0 means authenticated
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
