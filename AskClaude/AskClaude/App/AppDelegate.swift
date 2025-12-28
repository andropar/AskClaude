import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var ipcService: IPCService?
    private var statusItem: NSStatusItem?
    private var windowBecomeKeyObserver: NSObjectProtocol?

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
        windowBecomeKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureWindow()
        }
    }

    private func enableFinderExtensionIfNeeded() {
        // Always try to register and enable the extension on launch
        // This handles fresh installs and updates
        DispatchQueue.global(qos: .utility).async {
            // First, register the extension (needed for unsigned apps)
            let appPath = Bundle.main.bundlePath
            let extensionPath = "\(appPath)/Contents/PlugIns/FinderSyncExtension.appex"

            // Register the extension
            let registerProcess = Process()
            registerProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            registerProcess.arguments = ["-a", extensionPath]

            do {
                try registerProcess.run()
                registerProcess.waitUntilExit()
                print("[AppDelegate] Extension registration completed with status: \(registerProcess.terminationStatus)")
            } catch {
                print("[AppDelegate] Failed to register extension: \(error)")
            }

            // Small delay to let registration complete
            Thread.sleep(forTimeInterval: 0.5)

            // Then enable the extension
            let enableProcess = Process()
            enableProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            enableProcess.arguments = ["-e", "use", "-i", "com.askclaude.app.FinderSyncExtension"]

            do {
                try enableProcess.run()
                enableProcess.waitUntilExit()
                print("[AppDelegate] Finder extension enable completed with status: \(enableProcess.terminationStatus)")
            } catch {
                print("[AppDelegate] Failed to enable Finder extension: \(error)")
            }

            // Post notification so UI can update
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .finderExtensionStatusChanged, object: nil)
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "AskClaude")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show AskClaude", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
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

        if let observer = windowBecomeKeyObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
    static let finderExtensionStatusChanged = Notification.Name("finderExtensionStatusChanged")
}
