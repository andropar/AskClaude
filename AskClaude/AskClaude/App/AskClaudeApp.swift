import SwiftUI

@main
struct AskClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var textSizeManager = TextSizeManager()

    var body: some Scene {
        Window("AskClaude", id: "main") {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(textSizeManager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    // Handle new session
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Increase Text Size") {
                    textSizeManager.increase()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Text Size") {
                    textSizeManager.decrease()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Text Size") {
                    textSizeManager.reset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Auto-approve all permissions", isOn: $settings.autoApprovePermissions)

                if settings.autoApprovePermissions {
                    Text("Claude will execute commands without asking for approval. Only use in trusted directories.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Claude will ask for permission before running commands, editing files, etc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 150)
    }
}
