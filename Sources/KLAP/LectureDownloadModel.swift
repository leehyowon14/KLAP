import AppKit
import KLAPCore

extension AppModel {
    func openDownloads(_ choices:[LectureItem],selected:[String]=[]) {
        if !downloadState.running {
            if downloadAccount != snapshot.account {
                downloadState=LectureDownloadState();downloadExisting=[]
            }
            if Set(downloadChoices.map(\.id)) != Set(choices.map(\.id)) {downloadState=LectureDownloadState()}
            downloadAccount=snapshot.account
            downloadChoices=choices
            downloadSelection=Set(selected).intersection(Set(choices.map(\.id)))
        }
        showSettings=false;showSyllabus=false;showDownloads=true
        Task {await scanDownloads()}
    }
    func chooseDownloadDirectory() {
        guard !downloadState.running,!downloadScanning else{return}
        let panel=NSOpenPanel()
        panel.title="강의 다운로드 저장 폴더"
        panel.prompt="선택"
        panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=false;panel.canCreateDirectories=true
        panel.directoryURL=downloadDirectory ?? FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask).first
        if panel.runModal() == .OK {downloadDirectory=panel.url;downloadExisting=[];Task {await scanDownloads()}}
    }
    func downloadLectures(retry:Bool=false) async {
        guard !downloadScanning,!downloadState.running else{return}
        let ids=retry ? downloadState.retryIDs : downloadChoices.map(\.id).filter{downloadSelection.contains($0)}
        let pending=ids.filter{!downloadExisting.contains($0)}
        guard !pending.isEmpty else{return}
        guard let account=downloadAccount,account == snapshot.account else {downloadState.failure="계정이 변경되었습니다. 강의를 다시 선택해 주세요.";return}
        guard let directory=downloadDirectory else {showDownloads=false;showSettings=true;return}
        downloadState.begin(pending)
        var received=false
        var failure:String?
        do {
            try await downloadBridge.run(["Command":"lecture-download","IDs":pending,"Directory":LectureDownloadLocation.root(in:directory).path,"ExpectedAccount":account,"Concurrency":downloadMaximum,"Adaptive":downloadAdaptive,"Transcribe":downloadTranscribe,"Locale":"ko-KR"]) { [self] event in
                do {
                    if event.kind == "error" {failure=event.error ?? "다운로드 실패"}
                    if event.kind == "transcript-progress" {downloadState.apply(try event.decode(LectureTranscriptProgressData.self))}
                    if event.kind == "download-progress" {downloadState.apply(try event.decode(LectureDownloadProgressData.self))}
                    if event.kind == "download-result" {downloadState.apply(try event.decode([LectureDownloadResultData].self));received=true}
                } catch {failure=error.localizedDescription}
            }
        } catch {failure=failure ?? error.localizedDescription}
        let wasCancelled=downloadState.cancelling
        downloadState.finish(error:failure,receivedResult:received)
        downloadExisting.formUnion(downloadState.rows.filter{$0.value.finished}.map(\.key))
        downloadSelection.subtract(downloadExisting)
        if wasCancelled {message="다운로드를 취소했습니다"}
        else {message="다운로드 완료 \(downloadState.completed) / \(ids.count)개"}
    }
    func scanDownloads() async {
        guard !downloadScanning,!downloadState.running,let directory=downloadDirectory,let account=downloadAccount else{return}
        downloadScanning=true
        defer {downloadScanning=false}
        do {
            var found:Set<String>=[]
            var received=false
            var failure:String?
            try await downloadInventoryBridge.run(["Command":"lecture-download-inventory","Directory":LectureDownloadLocation.root(in:directory).path,"ExpectedAccount":account]) { event in
                if event.kind == "error" {failure=event.error}
                if event.kind == "download-inventory",let rows=try? event.decode([DownloadInventoryRow].self) {found=Set(rows.map(\.ID));received=true}
            }
            guard received,failure == nil else {throw BridgeFailure(message:failure ?? "파일 목록 응답이 없습니다")}
            guard directory == downloadDirectory,account == downloadAccount else{return}
            downloadExisting=found;downloadSelection.subtract(found)
        } catch {downloadState.failure="기존 파일 확인 실패: \(error.localizedDescription)"}
    }
    func cancelDownloads() {
        guard downloadState.running else{return}
        downloadState.cancelling=true
        downloadBridge.cancel()
    }
}

private struct DownloadInventoryRow:Decodable {let ID:String}
