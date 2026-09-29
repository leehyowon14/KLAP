import SwiftUI

struct DownloadSettings:View {
    @ObservedObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("강의 다운로드").font(.headline)
            HStack {
                VStack(alignment:.leading,spacing:4) {
                    Text(model.downloadDirectory.map {"저장경로: \(LectureDownloadLocation.root(in:$0).path)/과목명/Videos"} ?? "저장경로: 미설정").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                Button("폴더 선택") {model.chooseDownloadDirectory()}
            }.help(model.downloadDirectory?.path ?? "")
            Stepper("동시 다운로드 상한: \(model.downloadMaximum)개",value:$model.downloadMaximum,in:1...8)
            Toggle("속도에 따라 동시 다운로드 조절",isOn:$model.downloadAdaptive).toggleStyle(.switch).controlSize(.small)
        }.disabled(model.downloadState.running).padding(16).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
    }
}
