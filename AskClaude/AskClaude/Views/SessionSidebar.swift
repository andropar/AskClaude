import SwiftUI

struct SessionSidebar: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var renamingSessionId: UUID?
    @State private var renameText: String = ""

    var body: some View {
        List(selection: Binding(
            get: { sessionManager.activeSessionId },
            set: { newValue in
                if let id = newValue {
                    sessionManager.activeSessionId = id
                }
            }
        )) {
            Section("Sessions") {
                ForEach(sessionManager.sessions) { session in
                    SessionRow(
                        session: session,
                        isRenaming: renamingSessionId == session.id,
                        renameText: $renameText,
                        onCommitRename: {
                            commitRename(for: session)
                        },
                        onCancelRename: {
                            renamingSessionId = nil
                            renameText = ""
                        }
                    )
                    .tag(session.id)
                    .contextMenu {
                        Button("Rename...") {
                            startRenaming(session)
                        }
                        Divider()
                        Button("Close Session", role: .destructive) {
                            sessionManager.closeSession(session)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .navigationTitle("Ask Claude")
    }

    private func startRenaming(_ session: ChatSession) {
        renameText = session.displayName
        renamingSessionId = session.id
    }

    private func commitRename(for session: ChatSession) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            // If name matches folder name, clear custom name
            if trimmed == session.folderName {
                session.customName = nil
            } else {
                session.customName = trimmed
            }
        }
        renamingSessionId = nil
        renameText = ""
    }
}

struct SessionRow: View {
    @ObservedObject var session: ChatSession
    var isRenaming: Bool
    @Binding var renameText: String
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("Session name", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isRenameFocused)
                        .onSubmit {
                            onCommitRename()
                        }
                        .onExitCommand {
                            onCancelRename()
                        }
                        .onAppear {
                            isRenameFocused = true
                        }
                } else {
                    Text(session.displayName)
                        .font(.body)
                        .lineLimit(1)
                }

                Text(session.folderPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if session.isProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionSidebar()
        .environmentObject(SessionManager())
}
