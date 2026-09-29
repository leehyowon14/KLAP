import Foundation
import Darwin

struct BridgeEvent {
    let kind: String
    let data: Data
    let error: String?
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try JSONDecoder().decode(type, from: data) }
}
struct BridgeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor final class BridgeClient {
    private var process: Process?
    func cancel() {
        guard let process, process.isRunning else { return }
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
    func run(_ request: [String: Any], receive: @escaping @MainActor (BridgeEvent) -> Void) async throws {
        guard process == nil else { throw BridgeFailure(message: "다른 작업이 실행 중입니다") }
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/KLAPBridge")
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
            var pending = Data()
            while true {
                let chunk = output.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                pending.append(chunk)
                guard pending.count < 16 * 1024 * 1024 else { task.terminate(); throw BridgeFailure(message: "응답 크기가 허용 범위를 초과했습니다") }
                while let index = pending.firstIndex(of: 10) {
                    let line = Data(pending[..<index]); pending.removeSubrange(...index)
                    guard !line.isEmpty else { continue }
                    let object = try JSONSerialization.jsonObject(with: line) as? [String: Any]
                    guard let object, let kind = object["kind"] as? String else { task.terminate(); throw BridgeFailure(message: "잘못된 CLI 응답입니다") }
                    let data = try JSONSerialization.data(withJSONObject: object["data"] ?? NSNull(), options: .fragmentsAllowed)
                    await receive(BridgeEvent(kind: kind, data: data, error: object["error"] as? String))
                }
            }
            task.waitUntilExit()
            if !pending.isEmpty { throw BridgeFailure(message: "CLI 응답이 중간에 끊겼습니다") }
            return task.terminationStatus
        }.value
        if status != 0 { throw BridgeFailure(message: "작업이 종료되었습니다 (\(status))") }
    }
}
