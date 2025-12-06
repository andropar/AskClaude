import SwiftUI

struct ActivityIndicator: View {
    let activity: String
    @State private var dotOpacity: Double = 0.3
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Pulsing dot
            Circle()
                .fill(Color(hex: "D97706"))
                .frame(width: 6, height: 6)
                .opacity(dotOpacity)

            // Activity text
            Text(activity)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                dotOpacity = 1.0
            }
        }
    }
}

// Keep old name for compatibility
struct ThinkingIndicator: View {
    var body: some View {
        ActivityIndicator(activity: "Thinking...")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ActivityIndicator(activity: "Thinking...")
        ActivityIndicator(activity: "Reading file...")
        ActivityIndicator(activity: "Running command...")
        ActivityIndicator(activity: "Searching files...")
    }
    .padding(24)
    .frame(width: 400)
    .background(Color(.windowBackgroundColor))
}
