import AppKit
import Foundation
import KLAPCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

@MainActor func waitUntil(_ message: String, _ condition: () -> Bool) async throws {
    for _ in 0..<500 {
        if condition() { return }
        try await Task.sleep(nanoseconds:10_000_000)
    }
    fatalError("Timed out: \(message)")
}

@MainActor func runChecks() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("klap-study-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:root) }
    let domain=Bundle.main.bundleIdentifier!
    defer { UserDefaults.standard.removePersistentDomain(forName:domain) }
    UserDefaults.standard.set(false,forKey:"notifications")
    UserDefaults.standard.set(false,forKey:"destinationsConfigured")
    setenv("KLAP_STUDY_CHECK_ROOT",root.path,1)
    defer { unsetenv("KLAP_STUDY_CHECK_ROOT") }
    let executable=root.appendingPathComponent("fake-bridge")
    let fake=#"""
    #!/usr/bin/python3
    import base64, json, os, pathlib, signal, sys, time
    root = pathlib.Path(os.environ["KLAP_STUDY_CHECK_ROOT"])
    request = json.load(sys.stdin)
    command = request["Command"]
    with (root / "requests").open("a") as log:
        log.write(json.dumps(request) + "\n")
    def emit(kind, data=None, error=None):
        print(json.dumps(dict(kind=kind, data=data, error=error)), flush=True)
    def gate(name):
        deadline = time.monotonic() + 12
        while not (root / name).exists():
            if time.monotonic() > deadline:
                sys.exit(12)
            time.sleep(.01)
    def address(kind, *parts):
        return kind + ":v1:" + ":".join(base64.urlsafe_b64encode(p.encode()).decode().rstrip("=") for p in parts)
    notice = dict(ID=address("notice", "2026,2", "course", "board", "master"), CourseName="과목",
                  Notice=dict(Title="공지", BoardNo="board", MasterNo="master"))
    if command == "attend":
        mode = request["IDs"][0]
        if mode == "failure":
            emit("error", error="study-failure")
            sys.exit(1)
        if mode == "malformed":
            print("broken-json", flush=True)
            sys.exit(0)
        if mode == "exit-failure":
            sys.exit(9)
        def cancel(*args):
            # A terminating process can still flush buffered events, even exit 0.
            emit("start", dict(id=mode, title="late-event", current=2, total=2))
            emit("completed", dict(id=mode, current=1, total=2))
            emit("done", dict(success=2, failed=0))
            sys.exit(0)
        signal.signal(signal.SIGTERM, signal.SIG_IGN if mode == "ignore-term" else cancel)
        emit("start", dict(id=mode, title=mode, current=1, total=len(request["IDs"])))
        emit("progress", dict(id=mode, title=mode, percent=25, achieved="15", required="60", current=1, total=len(request["IDs"])))
        if mode != "finish":
            gate("release-study")
        emit("completed", dict(id=mode, current=1, total=1))
        emit("done", dict(success=1, failed=0))
    elif command == "snapshot":
        if (root / "hold-snapshot").exists():
            gate("release-snapshot")
        emit("result", dict(account="account", timetable=dict(Term=dict(label="2026-2", value="2026,2",
             subjList=[dict(name="과목", value="course")]), Entries=[]), notices=[notice], errors=[]))
    elif command == "board-list":
        emit("result", [notice["Notice"]])
    elif command == "board-detail":
        if (root / "hold-detail").exists():
            gate("release-detail")
        if (root / "fail-detail").exists():
            emit("error", error="query-failure")
            sys.exit(1)
        emit("result", dict(Detail=dict(Title="공지", ContentText="본문"), Files=[]))
    elif command == "board-read":
        emit("chunk", base64.b64encode(b"attachment").decode())
        emit("result", dict(Bytes=10))
    elif command == "board-download":
        path = root / "attachment.txt"
        path.write_text("attachment")
        emit("result", dict(Path=str(path)))
    elif command == "attendance-list":
        emit("result", dict(Term=dict(label="2026-2"), Rows=[]))
    elif command == "academic-list":
        emit("result", dict(Year="2026", SourceURL="https://example.test", Events=[]))
    elif command == "attendance-cdp":
        emit("result", dict(Report=dict(TotalCount="0", Rows=[])))
    else:
        emit("error", error="Unexpected command: " + command)
        sys.exit(2)
    """#
    try Data(fake.utf8).write(to:executable)
    try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:executable.path)
    func flag(_ name:String) throws { try Data().write(to:root.appendingPathComponent(name)) }
    func remove(_ name:String) { try? FileManager.default.removeItem(at:root.appendingPathComponent(name)) }
    func requests(_ command:String) -> [[String:Any]] {
        let data=(try? String(contentsOf:root.appendingPathComponent("requests"),encoding:.utf8)) ?? ""
        return data.split(separator:"\n").compactMap {
            (try? JSONSerialization.jsonObject(with:Data($0.utf8))) as? [String:Any]
        }.filter { $0["Command"] as? String == command }
    }
    let notifications=ContentNotificationService(readAuthorization:{.denied},authorize:{fatalError("No system permission prompts in checks")},submitNotification:{_ in fatalError("No system notifications in checks")})
    let model=AppModel(bridge:BridgeClient(executableURL:executable),studyBridge:BridgeClient(executableURL:executable),contentNotifications:notifications)
    model.onboarding=false
    model.loggedOut=false
    let reference=BoardReference(kind:"notice",term:"2026,2",subject:"course",board:"board",master:"master")
    let materialReference=BoardReference(kind:"material",term:"2026,2",subject:"course")

    await model.attend([])
    await model.attend(["", ""])
    expect(requests("attend").isEmpty && !model.studying,"Empty selections never start a process")

    let study=Task { await model.attend(["hold", "hold", "", "next"],expectedAccount:"account") }
    try await waitUntil("study progress") { model.progress?.fraction == 0.25 }
    expect(model.studying && !model.busy,"Studying does not occupy the query lane")
    expect(requests("attend").first?["IDs"] as? [String] == ["hold", "next"],"Duplicate/empty IDs are removed")
    expect(requests("attend").first?["ExpectedAccount"] as? String == "account","The study account remains pinned")
    await model.attend(["duplicate"])
    expect(requests("attend").count == 1,"A second study is rejected while the first is running")

    let detail=try await model.boardValue("board-detail",reference:reference,as:BoardDetail.self)
    expect(detail.Detail.ContentText == "본문" && model.studying,"Notice detail loads during study")
    let materials=try await model.boardValue("board-list",reference:materialReference,as:[Notice].self)
    expect(materials.count == 1 && model.studying,"Material list loads during study")
    let material=try await model.boardValue("board-detail",reference:materialReference,as:BoardDetail.self)
    expect(material.Detail.Title == "공지","Material detail loads during study")
    let downloaded=try await model.boardValue("board-download",reference:reference,as:BoardDownload.self)
    let attachmentText=try String(contentsOfFile:downloaded.Path,encoding:.utf8)
    expect(attachmentText == "attachment","Attachment bytes download during study")
    let attendance=try await model.pageValue(["Command":"attendance-list"],as:AttendanceResult.self)
    expect(attendance.Rows?.isEmpty == true && model.studying,"Attendance loads during study")
    let academic=try await model.pageValue(["Command":"academic-list"],as:AcademicResult.self)
    expect(academic.Year == "2026" && model.studying,"Academic events load during study")
    let cdp=try await model.pageValue(["Command":"attendance-cdp"],as:CdpResult.self)
    expect(cdp.Report.TotalCount == "0" && model.studying,"CDP attendance loads during study")
    var attachmentBytes=Data()
    await model.perform(reference.request.merging(["Command":"board-read"],uniquingKeysWith:{_,new in new})) { event in
        if event.kind == "chunk" { attachmentBytes.append(try event.decode(Data.self)) }
    }
    expect(String(data:attachmentBytes,encoding:.utf8) == "attachment","Attachment preview data streams during study")
    let refreshed=await model.refresh()
    expect(refreshed != nil,"Refresh succeeds during study")
    expect(model.progress?.fraction == 0.25 && model.studyTitle == "hold","Queries preserve study progress")
    model.logout()
    expect(!model.loggedOut,"Logout is blocked during study")
    let switched=await model.login(studentID:"other",password:"unused")
    expect(!switched,"Account switching is blocked during study")
    await model.sync()
    await model.resolveConflict("pending",decision:"keep")
    expect(requests("auth").isEmpty && requests("sync").isEmpty && model.pendingDecisions["pending"] == "keep","Account/sync mutations stay deferred")
    model.pendingDecisions=[:]

    // Cancel a study with a foreground request still waiting on its response.
    try flag("hold-detail")
    let detailCount=requests("board-detail").count
    let query=Task { try await model.boardValue("board-detail",reference:reference,as:BoardDetail.self) }
    try await waitUntil("overlapping query") { requests("board-detail").count > detailCount && model.busy }
    model.cancel()
    model.cancel()
    await model.attend(["too-early"])
    await study.value
    expect(!model.studying && model.busy,"Study cancellation leaves the foreground request alive")
    expect(model.studyError == nil && model.message == "수강을 취소했습니다","Cancellation is not a study failure")
    expect(model.studyTitle == "hold","Buffered events after cancellation cannot overwrite the study")
    expect(requests("attend").count == 1,"No duplicate run starts while cancellation is pending")
    try flag("release-detail")
    let afterCancel=try await query.value
    expect(afterCancel.Detail.ContentText == "본문" && !model.busy,"An overlapping query finishes after study cancellation")
    remove("hold-detail");remove("release-detail")

    let count=requests("attend").count
    await model.attend(["finish"])
    expect(requests("attend").count == count+1 && !model.studying && model.progress == nil,"A completed/cancelled study can be restarted")
    expect(model.message.contains("성공 1"),"Successful completion retains its summary")

    // The duplicate guard also covers the final snapshot, after the study process exits.
    try flag("hold-snapshot")
    let snapshots=requests("snapshot").count
    let finishing=Task { await model.attend(["finish"]) }
    try await waitUntil("final snapshot") { requests("snapshot").count > snapshots && model.busy }
    expect(model.studying,"Study remains occupied through final cleanup")
    let cleaningCount=requests("attend").count
    await model.attend(["duplicate-during-cleanup"])
    expect(requests("attend").count == cleaningCount,"Cleanup rejects a new study")
    try flag("release-snapshot")
    await finishing.value
    remove("hold-snapshot");remove("release-snapshot")

    for mode in ["failure", "malformed", "exit-failure"] {
        await model.attend([mode])
        expect(model.studyError != nil && !model.studying && model.progress == nil,"Failed studies release their state: \(mode)")
        expect(model.error == nil,"Study failures do not become foreground query errors")
        let savedError=model.studyError
        _ = try await model.boardValue("board-detail",reference:reference,as:BoardDetail.self)
        expect(model.studyError == savedError,"A successful query does not erase a study failure")
    }

    // Foreground errors must survive cancellation of the independent study.
    let cancelling=Task { await model.attend(["hold"]) }
    try await waitUntil("second overlapping study") { model.progress?.fraction == 0.25 }
    try flag("hold-detail");try flag("fail-detail")
    let errorQueries=requests("board-detail").count
    let failingQuery=Task { try await model.boardValue("board-detail",reference:reference,as:BoardDetail.self) }
    try await waitUntil("failing query") { requests("board-detail").count > errorQueries }
    model.cancel()
    await cancelling.value
    try flag("release-detail")
    if case .success = await failingQuery.result { fatalError("Query failure was swallowed") }
    expect(model.error == "query-failure" && model.studyError == nil,"Cancellation does not suppress an independent query failure")
    remove("hold-detail");remove("fail-detail");remove("release-detail")

    let stubborn=Task { await model.attend(["ignore-term"]) }
    try await waitUntil("SIGTERM-ignoring study") { model.progress?.fraction == 0.25 }
    model.cancel()
    await model.attend(["duplicate-before-kill"])
    await stubborn.value
    expect(model.studyError == nil && !model.studying,"Forced termination completes cancellation without a study error")
    await model.attend(["finish"])
    expect(model.studyError == nil && model.message.contains("성공 1"),"The study client is reusable after SIGKILL")
    model.cancel()
    _ = try await model.boardValue("board-detail",reference:reference,as:BoardDetail.self)
    expect(model.error == nil,"An idle cancel is harmless")
    await model.resolveConflict("unsent",decision:"keep")
    expect(model.pendingDecisions["unsent"] == "keep" && requests("sync").isEmpty,"Skipped sync cannot discard queued decisions")
    print("Study checks passed: concurrent notices/materials/attachments/pages/refresh, duplicate and account guards, cancellation isolation, late events, cleanup, failures, SIGKILL and restart")
}

Task { @MainActor in
    do {
        try await runChecks()
        exit(0)
    } catch {
        fputs("Study check failed: \(error)\n",stderr)
        exit(1)
    }
}
RunLoop.main.run()
