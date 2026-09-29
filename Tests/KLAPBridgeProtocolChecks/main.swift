import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let oneEvent = Data(#"{"kind":"result","data":{"value":42}}"#.utf8) + Data([10])
var splitDecoder = BridgeProtocolDecoder()
var splitEvents: [BridgeEvent] = []
for byte in oneEvent {
    splitEvents += try splitDecoder.append(Data([byte]))
}
try splitDecoder.finish()
expect(splitEvents.count == 1 && splitEvents[0].kind == "result", "A JSON line split across every byte is reassembled")
let splitPayload = try splitEvents[0].decode([String: Int].self)
expect(splitPayload["value"] == 42, "Decoded payload survives arbitrary chunk boundaries")

var batchDecoder = BridgeProtocolDecoder()
let batch = Data("\n{\"kind\":\"start\",\"data\":null}\n{\"kind\":\"error\",\"data\":null,\"error\":\"offline\"}\n".utf8)
let batchEvents = try batchDecoder.append(batch)
try batchDecoder.finish()
expect(batchEvents.map(\.kind) == ["start", "error"], "Blank lines are ignored while complete events preserve order")
let nullPayload = try batchEvents[0].decode(Optional<String>.self)
expect(nullPayload == nil, "Null event payload remains decodable")
expect(batchEvents[1].error == "offline", "Error field is preserved")

func rejectsLine(_ line: String, maximumLineSize: Int = 1024, message: String) {
    var decoder = BridgeProtocolDecoder(maximumLineSize: maximumLineSize)
    do {
        _ = try decoder.append(Data((line + "\n").utf8))
        fatalError(message)
    } catch is BridgeFailure {
    } catch {
        fatalError("\(message): unexpected error \(error)")
    }
}
rejectsLine("not-json", message: "Malformed JSON is rejected")
rejectsLine("[]", message: "A non-object response is rejected")
rejectsLine("{}", message: "A response without a kind is rejected")
rejectsLine("{\"kind\":4}", message: "A response with a non-string kind is rejected")
rejectsLine("{\"kind\":\"result\"}", maximumLineSize: 8, message: "A line over the configured boundary is rejected")

var truncated = BridgeProtocolDecoder()
_ = try truncated.append(Data(#"{"kind":"result"}"#.utf8))
do {
    try truncated.finish()
    fatalError("A valid but unterminated JSON line must be reported as truncated")
} catch is BridgeFailure {
}

var emptyDecoder = BridgeProtocolDecoder()
let emptyEvents = try emptyDecoder.append(Data())
expect(emptyEvents.isEmpty, "Empty reads do not produce events")
try emptyDecoder.finish()
print("Bridge response protocol: split, batched, null, malformed, size, and truncated-line checks passed")
