import Foundation

struct BridgeEvent {
    let kind: String
    let data: Data
    let error: String?

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

struct BridgeProtocolDecoder {
    private(set) var pending = Data()
    private let maximumLineSize: Int

    init(maximumLineSize: Int = 16 * 1024 * 1024) {
        self.maximumLineSize = maximumLineSize
    }

    mutating func append(_ chunk: Data) throws -> [BridgeEvent] {
        pending.append(chunk)
        var events: [BridgeEvent] = []
        while let index = pending.firstIndex(of: 10) {
            let line = Data(pending[..<index])
            pending.removeSubrange(...index)
            guard line.count <= maximumLineSize else {
                throw BridgeFailure(message: "응답 한 줄이 허용 크기를 초과했습니다")
            }
            guard !line.isEmpty else { continue }
            let raw: Any
            do {
                raw = try JSONSerialization.jsonObject(with: line)
            } catch {
                throw BridgeFailure(message: "잘못된 CLI 응답입니다")
            }
            guard let object = raw as? [String: Any], let kind = object["kind"] as? String else {
                throw BridgeFailure(message: "잘못된 CLI 응답입니다")
            }
            let data = try JSONSerialization.data(
                withJSONObject: object["data"] ?? NSNull(),
                options: .fragmentsAllowed
            )
            events.append(BridgeEvent(kind: kind, data: data, error: object["error"] as? String))
        }
        guard pending.count <= maximumLineSize else {
            throw BridgeFailure(message: "응답 한 줄이 허용 크기를 초과했습니다")
        }
        return events
    }

    func finish() throws {
        guard pending.isEmpty else {
            throw BridgeFailure(message: "CLI 응답이 중간에 끊겼습니다")
        }
    }
}
