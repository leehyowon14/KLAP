import AppKit
import SwiftUI
import KLAPCore

struct LectureDownloadsPage:View {
    @ObservedObject var model:AppModel
    private var courses:[String] {Array(Set(model.downloadChoices.map{$0.row.CourseName})).sorted()}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("강의를 선택해 영상 파일로 저장합니다. 여러 강의는 순서대로 다운로드합니다.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("저장 폴더 선택") {model.chooseDownloadDirectory()}.disabled(model.busy)
                Text(model.downloadDirectory?.lastPathComponent ?? "폴더를 선택해 주세요").font(.caption).lineLimit(1).help(model.downloadDirectory?.path ?? "")
                Spacer()
                if let directory=model.downloadDirectory {Button {NSWorkspace.shared.open(directory)} label:{Image(systemName:"folder")}.help("저장 폴더 열기").accessibilityLabel("저장 폴더 열기")}
            }
            if model.downloadState.running {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("\(model.downloadState.completed) / \(model.downloadState.expected.count)개 완료").font(.callout).monospacedDigit()
                    Spacer()
                    Button(model.downloadState.cancelling ? "취소 중…" : "취소",role:.destructive) {model.cancelDownloads()}.disabled(model.downloadState.cancelling)
                }
                Text("이 화면을 닫아도 다운로드는 계속됩니다.").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    Button("전체 선택") {model.downloadSelection=Set(model.downloadChoices.map(\.id))}
                    Button("선택 해제") {model.downloadSelection=[]}
                    Spacer()
                    Button("선택한 \(model.downloadSelection.count)개 다운로드") {Task {await model.downloadLectures()}}
                        .buttonStyle(FormButtonStyle(prominent:true,compact:true)).disabled(model.downloadSelection.isEmpty || model.busy)
                }.disabled(model.busy)
                if !model.downloadState.retryIDs.isEmpty {
                    Button("실패·취소한 \(model.downloadState.retryIDs.count)개 다시 시도") {Task {await model.downloadLectures(retry:true)}}.disabled(model.busy)
                }
            }
            if let failure=model.downloadState.failure {Text(failure).font(.caption).foregroundStyle(.red).textSelection(.enabled)}
            if model.downloadChoices.isEmpty {Text("다운로드할 강의가 없습니다.").foregroundStyle(.secondary)}
            ForEach(courses,id:\.self) { course in
                VStack(alignment:.leading,spacing:8) {
                    HStack {
                        Text(course).font(.headline)
                        Spacer()
                        Button("과목 전체 선택") {model.downloadSelection.formUnion(model.downloadChoices.filter{$0.row.CourseName == course}.map(\.id))}.font(.caption).disabled(model.busy)
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
            }.toggleStyle(.checkbox).disabled(model.busy)
            if let state=model.downloadState.rows[item.id] {
                HStack {
                    Text(state.label).font(.caption).foregroundStyle(state.stage == "error" ? Color.red : Color.secondary)
                    Spacer()
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
