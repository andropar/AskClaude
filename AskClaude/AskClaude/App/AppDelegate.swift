import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var ipcService: IPCService?
    private var statusItem: NSStatusItem!

    private let hasEnabledExtensionKey = "hasEnabledFinderExtension"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start IPC listener for Finder extension communication
        ipcService = IPCService()
        ipcService?.startListening { [weak self] folderPath in
            self?.openSessionForFolder(folderPath)
        }

        // Setup menu bar - must be done early and kept alive
        setupMenuBar()

        // Auto-enable Finder extension on first launch
        enableFinderExtensionIfNeeded()

        // Configure window
        DispatchQueue.main.async {
            self.configureWindow()
        }

        // Also listen for new windows
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureWindow()
        }
    }

    private func enableFinderExtensionIfNeeded() {
        let defaults = UserDefaults.standard

        // Only try once
        guard !defaults.bool(forKey: hasEnabledExtensionKey) else { return }
        defaults.set(true, forKey: hasEnabledExtensionKey)

        // Try to enable the extension using pluginkit
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            process.arguments = ["-e", "use", "-i", "com.askclaude.app.FinderSyncExtension"]

            do {
                try process.run()
                process.waitUntilExit()
                print("[AppDelegate] Finder extension enable attempt completed with status: \(process.terminationStatus)")
            } catch {
                print("[AppDelegate] Failed to enable Finder extension: \(error)")
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "AskClaude")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show AskClaude", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.level == .normal {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func configureWindow() {
        // Configure ALL windows - standard title bar with app name
        for window in NSApplication.shared.windows {
            // Skip menu bar extra windows
            guard window.level == .normal else { continue }
            window.title = "AskClaude"
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ipcService?.stopListening()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in background for IPC
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle askclaude://open?path=/path/to/folder&selected=/path/to/item
        for url in urls {
            guard url.scheme == "askclaude" else { continue }

            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let pathItem = components.queryItems?.first(where: { $0.name == "path" }),
               let path = pathItem.value?.removingPercentEncoding {
                let selectedItem = components.queryItems?.first(where: { $0.name == "selected" })?.value?.removingPercentEncoding
                openSessionForFolder(path, selectedItem: selectedItem)
            }
        }
    }

    private func openSessionForFolder(_ path: String, selectedItem: String? = nil) {
        var userInfo: [String: Any] = ["path": path]
        if let selected = selectedItem {
            userInfo["selectedItem"] = selected
        }
        NotificationCenter.default.post(
            name: .openSessionForFolder,
            object: nil,
            userInfo: userInfo
        )

        // Bring app to front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let openSessionForFolder = Notification.Name("openSessionForFolder")
}
