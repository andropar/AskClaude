import SwiftUI

/// Manages global text size scaling
class TextSizeManager: ObservableObject {
    @Published var scale: CGFloat {
        didSet {
            UserDefaults.standard.set(scale, forKey: "textSizeScale")
        }
    }

    static let minScale: CGFloat = 0.75
    static let maxScale: CGFloat = 1.5
    static let step: CGFloat = 0.1

    init() {
        let saved = UserDefaults.standard.double(forKey: "textSizeScale")
        self.scale = saved > 0 ? CGFloat(saved) : 1.0
    }

    func increase() {
        scale = min(scale + Self.step, Self.maxScale)
    }

    func decrease() {
        scale = max(scale - Self.step, Self.minScale)
    }

    func reset() {
        scale = 1.0
    }

    /// Scale a font size
    func scaled(_ size: CGFloat) -> CGFloat {
        return size * scale
    }
}

// MARK: - Environment Key

struct TextSizeManagerKey: EnvironmentKey {
    static let defaultValue = TextSizeManager()
}

extension EnvironmentValues {
    var textSizeManager: TextSizeManager {
        get { self[TextSizeManagerKey.self] }
        set { self[TextSizeManagerKey.self] = newValue }
    }
}

// MARK: - Scaled Font Modifier

struct ScaledFont: ViewModifier {
    @EnvironmentObject var textSizeManager: TextSizeManager
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: textSizeManager.scaled(size), weight: weight, design: design))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}
