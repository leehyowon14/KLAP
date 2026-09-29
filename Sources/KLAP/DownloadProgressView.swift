import SwiftUI

struct DownloadProgressView:View {
    @ObservedObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Button {model.showSettings=false;model.showDownloads=true} label:{Label("강의 다운로드",systemImage:"arrow.down.circle")}.buttonStyle(.plain)
                Spacer()
                Text("\(model.downloadState.completed) / \(model.downloadState.expected.count)").monospacedDigit()
                Button(model.downloadState.cancelling ? "취소 중…" : "취소") {model.cancelDownloads()}.disabled(model.downloadState.cancelling)
            }.font(.callout.weight(.medium))
            ProgressView(value:model.downloadState.fraction)
            if model.downloadState.transcripts.values.contains(where:{$0.Stage == "transcribe"}) {Text("다운로드한 영상 전사 중…").font(.caption).foregroundStyle(.secondary)}
            Text("\(model.downloadState.active)개 다운로드 중 · \(model.downloadState.paused)개 일시정지 · \(model.downloadState.speedLabel)").font(.caption).foregroundStyle(.secondary)
        }.padding(12).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
    }
}
