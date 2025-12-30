import AppKit
import SwiftUI

/// Centralized manager for displaying user-facing error alerts
@MainActor
class AlertManager {
    static let shared = AlertManager()

    private init() {}

    /// Shows a critical error alert with an OK button
    func showError(title: String, message: String, informative: String? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = informative ?? message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Shows a warning alert with an OK button
    func showWarning(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Shows an error alert with an action button (e.g., "Open Terminal", "Install")
    /// Returns true if the action button was clicked, false otherwise
    @discardableResult
    func showErrorWithAction(
        title: String,
        message: String,
        actionTitle: String,
        action: () -> Void
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            action()
            return true
        }
        return false
    }

    // MARK: - Specific Error Handlers

    /// Shows alert when Claude CLI is not found
    func showClaudeNotFoundError() {
        showErrorWithAction(
            title: "Claude Code Not Found",
            message: "Claude Code CLI could not be found on your system. Please install Claude Code to use AskClaude.",
            actionTitle: "Download Claude Code"
        ) {
            if let url = URL(string: "https://claude.ai/download") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Shows alert when user is not authenticated
    func showAuthenticationError() {
        showErrorWithAction(
            title: "Not Signed In",
            message: "You need to sign in to Claude Code. Open Terminal and run 'claude' to authenticate.",
            actionTitle: "Open Terminal"
        ) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    /// Shows alert when Claude process crashes unexpectedly
    func showProcessCrashError(exitCode: Int32, folderPath: String) {
        let folderName = (folderPath as NSString).lastPathComponent
        showError(
            title: "Claude Process Crashed",
            message: "The Claude process for \"\(folderName)\" exited unexpectedly with code \(exitCode).",
            informative: "This may be due to a temporary issue. Try starting a new chat session."
        )
    }

    /// Shows alert when session fails to start
    func showSessionStartError(error: Error, folderPath: String) {
        let folderName = (folderPath as NSString).lastPathComponent
        let message: String
        let actionTitle: String?
        let action: (() -> Void)?

        if let claudeError = error as? ClaudeError {
            switch claudeError {
            case .notFound:
                showClaudeNotFoundError()
                return
            case .notAuthenticated:
                showAuthenticationError()
                return
            case .launchFailed(let reason):
                message = "Failed to start Claude session for \"\(folderName)\": \(reason)"
                actionTitle = nil
                action = nil
            case .notRunning:
                message = "Claude is not running. Please try again."
                actionTitle = nil
                action = nil
            }
        } else {
            message = "Failed to start Claude session: \(error.localizedDescription)"
            actionTitle = nil
            action = nil
        }

        if let actionTitle = actionTitle, let action = action {
            showErrorWithAction(title: "Session Start Failed", message: message, actionTitle: actionTitle, action: action)
        } else {
            showError(title: "Session Start Failed", message: message)
        }
    }

    /// Shows alert for file browser errors
    func showFileBrowserError(path: String, error: Error) {
        showError(
            title: "File Browser Error",
            message: "Could not load files from \"\(path)\"",
            informative: error.localizedDescription
        )
    }
}
