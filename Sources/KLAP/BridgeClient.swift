import Foundation
import Darwin

struct BridgeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor final class BridgeClient {
    private var process: Process?
    private let executableURL: URL

    init(executableURL: URL? = nil) {
        self.executableURL=executableURL ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/KLAPBridge")
    }

    func cancel() {
        guard let process, process.isRunning else { return }
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
    func run(_ request: [String: Any], receive: @escaping @MainActor (BridgeEvent) -> Void) async throws {
        guard process == nil else { throw BridgeFailure(message: "다른 작업이 실행 중입니다") }
        let executable = executableURL
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw BridgeFailure(message: "KLAPBridge가 없습니다. scripts/build.sh로 앱 전체를 빌드하세요.") }
        let task = Process()
        task.executableURL = executable
        if Bundle.main.object(forInfoDictionaryKey:"KLAPDevelopmentBuild") as? Bool == true {
            var environment=ProcessInfo.processInfo.environment
            let home=FileManager.default.homeDirectoryForCurrentUser
            environment["KLAP_CONFIG_DIR"]=home.appendingPathComponent("Library/Application Support/KLAP-Dev").path
            environment["KLAP_CACHE_DIR"]=home.appendingPathComponent("Library/Caches/KLAP-Dev").path
            environment["KLAP_KEYRING_SERVICE"]="klap-dev"
            task.environment=environment
        }
        let input = Pipe(), output = Pipe()
        task.standardInput = input
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        let payload = try JSONSerialization.data(withJSONObject: request)
        try task.run()
        process = task
        defer { if task.isRunning { task.terminate() }; process = nil }
        try input.fileHandleForWriting.write(contentsOf: payload)
        try input.fileHandleForWriting.close()
        let status = try await Task.detached { () throws -> Int32 in
            defer { if task.isRunning { kill(task.processIdentifier, SIGKILL) }; task.waitUntilExit() }
            var decoder = BridgeProtocolDecoder()
            while true {
                let chunk = output.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                for event in try decoder.append(chunk) { await receive(event) }
            }
            task.waitUntilExit()
            try decoder.finish()
            return task.terminationStatus
        }.value
        if status != 0 { throw BridgeFailure(message: "작업이 종료되었습니다 (\(status))") }
    }
}
