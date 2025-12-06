import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    override init() {
        super.init()

        // Monitor all folders - this allows the extension to work everywhere
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]

        print("[FinderSync] Extension initialized")
    }

    // MARK: - Menu Building

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Show menu for all context menu types
        switch menuKind {
        case .contextualMenuForItems, .contextualMenuForContainer:
            return createAskClaudeMenu()
        default:
            return nil
        }
    }

    private func createAskClaudeMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        let askClaudeItem = NSMenuItem(
            title: "Ask Claude",
            action: #selector(askClaudeClicked(_:)),
            keyEquivalent: ""
        )
        if let image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Ask Claude") {
            image.isTemplate = true
            askClaudeItem.image = image
        }
        menu.addItem(askClaudeItem)
        return menu
    }

    @objc func askClaudeClicked(_ sender: AnyObject?) {
        let (folderPath, selectedItem) = determinePaths()

        guard let path = folderPath else {
            print("[FinderSync] Could not determine folder path")
            return
        }

        print("[FinderSync] Opening Claude for folder: \(path), selected: \(selectedItem ?? "none")")
        launchMainApp(withFolder: path, selectedItem: selectedItem)
    }

    /// Determines the folder path and selected item based on what's selected in Finder
    private func determinePaths() -> (folderPath: String?, selectedItem: String?) {
        // Check if we have selected items
        if let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
           let firstURL = selectedURLs.first {
            // Check if the selected item is a directory
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: firstURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Selected a folder - use it as both folder and context
                    return (firstURL.path, firstURL.path)
                } else {
                    // Selected a file - use parent folder, but pass file as context
                    return (firstURL.deletingLastPathComponent().path, firstURL.path)
                }
            }
        }

        // Fall back to the current folder (background click)
        if let targetURL = FIFinderSyncController.default().targetedURL() {
            return (targetURL.path, nil)
        }

        return (nil, nil)
    }

    /// Launches the main app with the specified folder and optional selected item
    private func launchMainApp(withFolder path: String, selectedItem: String?) {
        // Use URL scheme to launch main app
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("[FinderSync] Failed to encode path")
            return
        }

        var urlString = "askclaude://open?path=\(encodedPath)"

        if let item = selectedItem,
           let encodedItem = item.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&selected=\(encodedItem)"
        }

        guard let url = URL(string: urlString) else {
            print("[FinderSync] Failed to create URL")
            return
        }

        print("[FinderSync] Launching via URL scheme: \(url)")
        NSWorkspace.shared.open(url)
    }
}
