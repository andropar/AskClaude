import Foundation
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("autoApprovePermissions") var autoApprovePermissions: Bool = false

    private init() {}
}
