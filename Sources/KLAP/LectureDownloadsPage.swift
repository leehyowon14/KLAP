import AppKit
import SwiftUI
import KLAPCore

struct LectureDownloadsPage:View {
    @ObservedObject var model:AppModel
    private var courses:[String] {Array(Set(model.downloadChoices.map{$0.row.CourseName})).sorted()}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.center) {
                VStack(alignment:.leading,spacing:4) {
                    Text("선택한 강의 \(model.downloadSelection.count)개").font(.headline)
                    Text("다운로드된 강의는 선택에서 제외됩니다.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("다운로드") {Task {await model.downloadLectures()}}
                    .buttonStyle(FormButtonStyle(prominent:true,compact:true))
                    .disabled(model.downloadDirectory == nil || model.downloadSelection.isEmpty || model.downloadState.running || model.downloadScanning)
            }
            if model.downloadDirectory == nil {
                Button("설정에서 저장 폴더 선택") {model.showDownloads=false;model.showSettings=true}
            }
            if model.downloadState.running {DownloadProgressView(model:model)}
            HStack(spacing:12) {
                Button("전체 선택") {model.downloadSelection=Set(model.downloadChoices.map(\.id)).subtracting(model.downloadExisting)}
                Button("선택 해제") {model.downloadSelection=[]}
                Spacer()
                if model.downloadScanning {ProgressView().controlSize(.small)}
                if !model.downloadState.retryIDs.isEmpty {
                    Button("실패·취소 항목 재시도") {Task {await model.downloadLectures(retry:true)}}
                }
            }.font(.caption).buttonStyle(.borderless).disabled(model.downloadState.running || model.downloadScanning)
            Divider()
            if let failure=model.downloadState.failure {Text(failure).font(.caption).foregroundStyle(.red).textSelection(.enabled)}
            if model.downloadChoices.isEmpty {Text("다운로드할 강의가 없습니다.").foregroundStyle(.secondary)}
            ForEach(courses,id:\.self) { course in
                VStack(alignment:.leading,spacing:8) {
                    HStack {
                        Text(course).font(.headline)
                        Spacer()
                        Button("과목 전체 선택") {model.downloadSelection.formUnion(model.downloadChoices.filter{$0.row.CourseName == course}.map(\.id).filter{!model.downloadExisting.contains($0)})}.font(.caption).buttonStyle(.borderless).disabled(model.downloadState.running || model.downloadScanning)
                    }
                    ForEach(model.downloadChoices.filter{$0.row.CourseName == course}) { item in
                        downloadRow(item)
                    }
                }.padding(.top,6)
            }
        }.buttonStyle(FormButtonStyle(compact:true))
    }
    private func downloadRow(_ item:LectureItem)->some View {
        VStack(alignment:.leading,spacing:7) {
            Toggle(isOn:Binding(get:{model.downloadSelection.contains(item.id)},set:{selected in if selected {model.downloadSelection.insert(item.id)} else {model.downloadSelection.remove(item.id)}})) {
                Text(item.row.Lecture.Title).font(.callout).fixedSize(horizontal:false,vertical:true)
            }.toggleStyle(.checkbox).disabled(model.downloadState.running || model.downloadScanning || model.downloadExisting.contains(item.id))
            if let transcript=model.downloadState.transcripts[item.id] {
                Text(transcript.Stage == "transcribed" ? "전사 완료" : transcript.Stage == "transcript-error" ? "전사 실패: \(transcript.Error)" : model.downloadState.running ? "전사 중…" : "전사 중단됨").font(.caption).foregroundStyle(.secondary)
            }
            if model.downloadExisting.contains(item.id) {Label("다운로드됨",systemImage:"checkmark.circle").font(.caption).foregroundStyle(.secondary)}
            if let state=model.downloadState.rows[item.id] {
                HStack {
                    Text(state.label).font(.caption).foregroundStyle(state.stage == "error" ? Color.red : Color.secondary)
                    Spacer()
                    if state.stage == "download" {Text(String(format:"%.1f MB/s",state.speed/1_000_000)).font(.caption).monospacedDigit()}
                    if state.total>0 {Text("\(ByteCountFormatter.string(fromByteCount:state.bytes,countStyle:.file)) / \(ByteCountFormatter.string(fromByteCount:state.total,countStyle:.file))").font(.caption).foregroundStyle(.secondary)}
                    if let path=state.path,state.finished {Button("Finder에서 보기") {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:path)])}.font(.caption)}
                }
                if state.stage == "download" {
                    if let fraction=state.fraction {ProgressView(value:fraction)} else {ProgressView().controlSize(.small)}
                }
                if let error=state.error {Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)}
            }
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
    }
}
