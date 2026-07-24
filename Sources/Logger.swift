import Foundation

class Logger {
    static let shared = Logger()
    private var logFile: FileHandle?
    private var logPath: String = ""

    func setup(logPath: String) {
        self.logPath = logPath
        FileManager.default.createFile(atPath: logPath, contents: nil)
        logFile = FileHandle(forWritingAtPath: logPath)
        logFile?.seekToEndOfFile()
    }

    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        if let data = line.data(using: .utf8) {
            logFile?.write(data)
            logFile?.synchronizeFile()
        }

        #if DEBUG
            fputs(line, stderr)
        #endif
    }

    func readLogs(lastLines: Int = 50) -> String {
        guard let data = FileManager.default.contents(atPath: logPath),
            let content = String(data: data, encoding: .utf8)
        else {
            return "No logs available"
        }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        let recent = Array(lines.suffix(lastLines))
        return recent.joined(separator: "\n")
    }
}
