import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 0) {
            if isUser {
                // User message: right-aligned, muted, compact
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(colorScheme == .dark ? Color(white: 0.6) : Color(white: 0.4))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // Claude response: full-width, primary, no bubble
                MarkdownContentView(content: message.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        MessageBubble(message: ChatMessage(
            role: .user,
            content: "How does the authentication system work?"
        ))

        MessageBubble(message: ChatMessage(
            role: .assistant,
            content: """
            The authentication system uses JWT tokens stored in httpOnly cookies. Here's the flow:

            1. User submits credentials to `/api/login`
            2. Server validates and returns JWT
            3. Client stores in cookie automatically

            ```typescript
            export async function login(email: string, password: string) {
                const res = await fetch('/api/login', {
                    method: 'POST',
                    body: JSON.stringify({ email, password })
                });
                return res.json();
            }
            ```

            The key files are:
            - `src/auth/login.ts` - Login logic
            - `src/middleware/jwt.ts` - Token validation
            """
        ))

        MessageBubble(message: ChatMessage(
            role: .user,
            content: "What about refresh tokens?"
        ))
    }
    .padding(24)
    .frame(width: 600)
    .background(Color(.windowBackgroundColor))
}
