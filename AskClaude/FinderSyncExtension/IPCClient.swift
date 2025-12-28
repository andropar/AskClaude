import Foundation

/// Sends messages to the main app via CFMessagePort
class IPCClient {
    /// Attempts to send a folder path to the main app
    /// - Returns: true if successful, false if main app is not running
    func sendFolderPath(_ path: String) -> Bool {
        guard let remotePort = CFMessagePortCreateRemote(nil, AppGroupConfig.ipcPortName) else {
            print("[IPCClient] Main app not running (no remote port)")
            return false
        }

        // Ensure port is invalidated after use to prevent resource leak
        defer {
            CFMessagePortInvalidate(remotePort)
        }

        guard let data = path.data(using: .utf8) else {
            print("[IPCClient] Failed to encode path")
            return false
        }

        let cfData = data as CFData
        let result = CFMessagePortSendRequest(
            remotePort,
            0, // message ID
            cfData,
            1.0, // send timeout
            0.0, // receive timeout (no response expected)
            nil, // no reply mode
            nil  // no reply data
        )

        let success = result == kCFMessagePortSuccess
        print("[IPCClient] Send result: \(success ? "success" : "failed")")
        return success
    }
}
