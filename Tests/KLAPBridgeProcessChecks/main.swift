import Darwin
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

Task { @MainActor in
    do {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("klap-bridge-process-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:root)}
        let executable=root.appendingPathComponent("fake-bridge")
        let fake="""
        #!/bin/sh
        cat >/dev/null
        case "$KLAP_TEST_BRIDGE_MODE" in
          lines) printf '{"kind":"start","data":{"id":"one"}}\\n\\n{"kind":"done","data":{"success":1}}\\n' ;;
          malformed) printf 'broken-json\\n' ;;
          truncated) printf '{"kind":"done","data":{"success":1}}' ;;
          nonzero) printf '{"kind":"done","data":{"success":1}}\\n'; exit 9 ;;
          hang) printf '{"kind":"started","data":null}\\n'; exec /bin/sleep 30 >/dev/null 2>&1 ;;
        esac
        """
        try Data(fake.utf8).write(to:executable)
        try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:executable.path)
        let client=BridgeClient(executableURL:executable)
        func mode(_ value:String) {setenv("KLAP_TEST_BRIDGE_MODE",value,1)}

        mode("lines")
        var events:[BridgeEvent]=[]
        try await client.run(["Command":"test"]) {events.append($0)}
        expect(events.map(\.kind)==["start","done"],"Process output is delivered in order and blank lines are ignored")
        let result=try events[1].decode([String:Int].self)
        expect(result["success"]==1,"The process forwards decoded event payloads")

        for failureMode in ["malformed","truncated"] {
            mode(failureMode)
            do {
                try await client.run(["Command":"test"]) {_ in}
                fatalError("\(failureMode) process output must fail")
            } catch is BridgeFailure {
            }
            mode("lines")
            try await client.run(["Command":"test"]) {_ in}
        }

        mode("nonzero")
        var emittedBeforeExit=false
        do {
            try await client.run(["Command":"test"]) {emittedBeforeExit = $0.kind=="done"}
            fatalError("A nonzero process exit must fail")
        } catch is BridgeFailure {
        }
        expect(emittedBeforeExit,"Events received before a failing exit remain observable")

        mode("hang")
        var started=false
        let active=Task {try await client.run(["Command":"test"]) {if $0.kind=="started" {started=true}}}
        for _ in 0..<100 where !started {try await Task.sleep(nanoseconds:20_000_000)}
        expect(started,"The hanging process starts before cancellation")
        do {
            try await client.run(["Command":"test"]) {_ in}
            fatalError("Concurrent bridge commands must be rejected")
        } catch let error as BridgeFailure {
            expect(error.message.contains("다른 작업"),"Concurrent command reports a busy state")
        }
        client.cancel()
        if case .success = await active.result {fatalError("Cancelled bridge process must not report success")}
        mode("lines")
        try await client.run(["Command":"test"]) {_ in}
        print("Bridge process start, stream delivery, malformed output, exit failure, cancellation and reuse checks passed")
        exit(0)
    } catch {
        fputs("Bridge process check failed: \(error)\n",stderr)
        exit(1)
    }
}
RunLoop.main.run()
