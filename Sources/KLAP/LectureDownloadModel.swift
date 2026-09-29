import AppKit
import KLAPCore

extension AppModel {
    func openDownloads(_ choices:[LectureItem],selected:[String]=[]) {
        if !downloadState.running {
            if downloadAccount != snapshot.account {
                downloadState=LectureDownloadState();downloadDirectory=nil
            }
            if Set(downloadChoices.map(\.id)) != Set(choices.map(\.id)) {downloadState=LectureDownloadState()}
            downloadAccount=snapshot.account
            downloadChoices=choices
            downloadSelection=Set(selected).intersection(Set(choices.map(\.id)))
        }
        showSettings=false;showSyllabus=false;showDownloads=true
    }
    func chooseDownloadDirectory() {
        guard !busy else{return}
        let panel=NSOpenPanel()
        panel.title="강의 다운로드 저장 폴더"
        panel.prompt="선택"
        panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=false;panel.canCreateDirectories=true
        panel.directoryURL=downloadDirectory ?? FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask).first
        if panel.runModal() == .OK {downloadDirectory=panel.url}
    }
    func downloadLectures(retry:Bool=false) async {
        guard !busy,!downloadState.running else{return}
        let ids=retry ? downloadState.retryIDs : downloadChoices.map(\.id).filter{downloadSelection.contains($0)}
        guard !ids.isEmpty else{return}
        guard let account=downloadAccount,account == snapshot.account else {downloadState.failure="계정이 변경되었습니다. 강의를 다시 선택해 주세요.";return}
        if downloadDirectory == nil {chooseDownloadDirectory()}
        guard let directory=downloadDirectory else{return}
        downloadState.begin(ids)
        var received=false
        await perform(["Command":"lecture-download","IDs":ids,"Directory":directory.path,"ExpectedAccount":account]) { [self] event in
            if event.kind == "download-progress" {downloadState.apply(try event.decode(LectureDownloadProgressData.self))}
            if event.kind == "download-result" {downloadState.apply(try event.decode([LectureDownloadResultData].self));received=true}
        }
        let wasCancelled=downloadState.cancelling
        downloadState.finish(error:error,receivedResult:received)
        if wasCancelled {error=nil;message="다운로드를 취소했습니다"}
        else {message="다운로드 완료 \(downloadState.completed) / \(ids.count)개"}
    }
    func cancelDownloads() {
        guard downloadState.running else{return}
        downloadState.cancelling=true
        cancel()
    }
}
