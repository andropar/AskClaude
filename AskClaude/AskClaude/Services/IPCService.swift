import Foundation

/// Listens for messages from the Finder Sync Extension via CFMessagePort
class IPCService {
    private var localPort: CFMessagePort?
    private var runLoopSource: CFRunLoopSource?
    private var onFolderReceived: ((String) -> Void)?

    func startListening(onFolderReceived: @escaping (String) -> Void) {
        self.onFolderReceived = onFolderReceived

        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        localPort = CFMessagePortCreateLocal(
            nil,
            AppGroupConfig.ipcPortName,
            { (port, msgid, data, info) -> Unmanaged<CFData>? in
                guard let info = info,
                      let cfData = data else { return nil }

                let data = cfData as Data
                let service = Unmanaged<IPCService>.fromOpaque(info).takeUnretainedValue()

                if let path = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        service.onFolderReceived?(path)
                    }
                }
                return nil
            },
            &context,
            nil
        )

        if let port = localPort {
            runLoopSource = CFMessagePortCreateRunLoopSource(nil, port, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            print("[IPCService] Started listening on port: \(AppGroupConfig.ipcPortName)")
        } else {
            print("[IPCService] Failed to create local port")
        }
    }

    func stopListening() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port = localPort {
            CFMessagePortInvalidate(port)
        }
        localPort = nil
        runLoopSource = nil
        print("[IPCService] Stopped listening")
    }
}
