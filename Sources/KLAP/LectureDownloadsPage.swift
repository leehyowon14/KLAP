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
            if #available(macOS 26.0, *) {
                HStack(spacing:16) {
                    Toggle("다운로드 후 전사",isOn:$model.downloadTranscribe).toggleStyle(.switch).controlSize(.small)
                    Group {
                        Picker("언어",selection:$model.downloadLocale) {
                            Text("한국어").tag("ko-KR")
                            Text("영어").tag("en-US")
                            Text("일본어").tag("ja-JP")
                            Text("중국어").tag("zh-CN")
                        }.frame(maxWidth:180)
                    }
                }.disabled(model.downloadState.running)
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
        let state=model.downloadState.rows[item.id]
        let downloaded=model.downloadExisting.contains(item.id) || state?.finished == true
        let path=state?.finished == true ? state?.path : model.downloadPaths[item.id]
        return VStack(alignment:.leading,spacing:8) {
            HStack(spacing:10) {
                if downloaded || model.downloadState.running {
                    Text(item.row.Lecture.Title).font(.callout.weight(.medium)).fixedSize(horizontal:false,vertical:true)
                } else {
                    Toggle(isOn:Binding(get:{model.downloadSelection.contains(item.id)},set:{selected in if selected {model.downloadSelection.insert(item.id)} else {model.downloadSelection.remove(item.id)}})) {
                        Text(item.row.Lecture.Title).font(.callout.weight(.medium)).fixedSize(horizontal:false,vertical:true)
                    }.toggleStyle(.checkbox).disabled(model.downloadScanning)
                }
                Spacer(minLength:8)
                if downloaded {
                    if #available(macOS 26.0, *),!model.downloadTranscribed.contains(item.id),model.downloadState.transcripts[item.id]?.Stage != "transcribed" {
                        Button("전사하기") {Task {await model.transcribeLecture(item.id)}}.buttonStyle(.borderless).font(.caption).disabled(model.downloadState.running)
                    }
                }
                if downloaded,let path {
                    Button {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:path)])} label:{Image(systemName:"folder")}
                        .buttonStyle(.plain).frame(width:28,height:28).help("Finder에서 보기").accessibilityLabel("Finder에서 보기")
                }
            }
            HStack(spacing:8) {
                if downloaded {Label("다운로드됨",systemImage:"checkmark.circle")}
                else if let state,state.stage != "cancelled" {Text(state.label).foregroundStyle(state.stage == "error" ? Color.red : Color.secondary).help(state.error ?? "")}
                if let transcript=model.downloadState.transcripts[item.id],transcript.Stage != "cancelled" {
                    if downloaded {Text("·")}
                    Text(transcript.Stage == "cancelled" ? "전사 취소됨" : transcript.Stage == "transcribed" ? "전사 완료" : transcript.Stage == "transcript-error" ? "전사 실패" : "전사 중…")
                    if !transcript.Error.isEmpty {Image(systemName:"info.circle").help(transcript.Error).accessibilityLabel(transcript.Error)}
                }
                Spacer()
                if state?.stage == "download",let fraction=state?.fraction {Text("\(Int(fraction*100))%").monospacedDigit()}
            }.font(.caption).foregroundStyle(.secondary)
            if state?.stage == "download" {
                if let fraction=state?.fraction {ProgressView(value:fraction)} else {ProgressView().controlSize(.small)}
            }
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
    }
}
