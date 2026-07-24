import Foundation

protocol IPCServerDelegate: AnyObject {
    func handleCommand(_ command: String) -> String
}

class IPCServer {
    let socketPath: String
    weak var delegate: IPCServerDelegate?
    private var serverFD: Int32 = -1
    private var isRunning = false

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func start() {
        unlink(socketPath)

        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            Logger.shared.log("Failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        guard socketPath.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            Logger.shared.log("Socket path too long")
            close(serverFD)
            return
        }

        let pathBytes = socketPath.utf8CString
        let pathSize = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let pathPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            pathBytes.withUnsafeBufferPointer { buf in
                _ = strncpy(pathPtr, buf.baseAddress!, pathSize - 1)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        guard withUnsafePointer(to: &addr, { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverFD, $0, addrLen)
            }
        }) == 0
        else {
            Logger.shared.log("Failed to bind socket: \(String(cString: strerror(errno)))")
            close(serverFD)
            return
        }

        chmod(socketPath, 0o600)

        guard listen(serverFD, 5) == 0 else {
            Logger.shared.log("Failed to listen on socket")
            close(serverFD)
            return
        }

        isRunning = true
        Logger.shared.log("IPC server started on \(socketPath)")

        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        isRunning = false
        if serverFD >= 0 {
            close(serverFD)
        }
        unlink(socketPath)
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverFD, $0, &clientLen)
                }
            }

            guard clientFD >= 0 else {
                if isRunning {
                    Logger.shared.log("Accept failed: \(String(cString: strerror(errno)))")
                }
                continue
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count)

        guard bytesRead > 0 else {
            close(fd)
            return
        }

        let data = Data(bytes: buffer, count: bytesRead)
        guard let request = try? JSONSerialization.jsonObject(with: data) as? [String: String],
            let command = request["command"]
        else {
            sendResponse(fd, response: "{\"error\":\"Invalid request\"}")
            close(fd)
            return
        }

        let response = delegate?.handleCommand(command) ?? "{\"error\":\"No handler\"}"
        sendResponse(fd, response: response)
        close(fd)
    }

    private func sendResponse(_ fd: Int32, response: String) {
        if let data = response.data(using: .utf8) {
            var totalSent = 0
            while totalSent < data.count {
                let result = data.withUnsafeBytes { ptr in
                    write(
                        fd, ptr.baseAddress!.advanced(by: totalSent), data.count - totalSent)
                }
                if result <= 0 { break }
                totalSent += result
            }
        }
    }
}
