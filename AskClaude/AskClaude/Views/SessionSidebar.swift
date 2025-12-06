import SwiftUI

struct SessionSidebar: View {
    @EnvironmentObject var sessionManager: SessionManager

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
                    SessionRow(session: session)
                        .tag(session.id)
                        .contextMenu {
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
}

struct SessionRow: View {
    @ObservedObject var session: ChatSession

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.folderName)
                    .font(.body)
                    .lineLimit(1)

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
