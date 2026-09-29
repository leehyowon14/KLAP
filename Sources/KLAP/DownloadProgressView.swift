import SwiftUI

struct DownloadProgressView:View {
    @ObservedObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Button {model.showSettings=false;model.showDownloads=true} label:{Label(model.downloadState.transcribing ? "강의 전사" : "강의 다운로드",systemImage:model.downloadState.transcribing ? "waveform" : "arrow.down.circle")}.buttonStyle(.plain)
                Spacer()
                Text("\(model.downloadState.displayCurrent) / \(model.downloadState.displayTotal)").monospacedDigit()
                Button(model.downloadState.cancelling ? "취소 중…" : "취소") {model.cancelDownloads()}.disabled(model.downloadState.cancelling)
            }.font(.callout.weight(.medium))
            if model.downloadState.transcribing {
                ProgressView(value:model.downloadState.transcriptFraction)
            } else {
                let activeIDs=model.downloadState.expected.filter {model.downloadState.rows[$0]?.stage == "download"}
                if activeIDs.isEmpty {
                    ProgressView(value:model.downloadState.fraction)
                } else {
                    ForEach(activeIDs,id:\.self) {id in
                        ProgressView(value:model.downloadState.rows[id]?.fraction ?? 0)
                            .accessibilityLabel("다운로드 진행상황")
                    }
                }
            }
            if !model.downloadState.transcribing && !model.downloadState.transcriptQueue.isEmpty {
                HStack {
                    Label("전사",systemImage:"waveform")
                    Spacer()
                    Text("\(model.downloadState.transcriptCurrent) / \(model.downloadState.transcriptQueue.count)").monospacedDigit()
                }.font(.caption).foregroundStyle(.secondary)
                ProgressView(value:model.downloadState.transcriptFraction)
            }
            if !model.downloadState.transcribing {
                Text("\(model.downloadState.active)개 다운로드 중 · \(model.downloadState.paused)개 일시정지 · \(model.downloadState.speedLabel)").font(.caption).foregroundStyle(.secondary)
            }

        }.padding(12).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
    }
}
