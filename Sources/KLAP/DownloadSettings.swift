import SwiftUI

struct DownloadSettings:View {
    @ObservedObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("강의 다운로드").font(.headline)
            HStack {
                VStack(alignment:.leading,spacing:4) {
                    Text("기본 다운로드 폴더").font(.callout.weight(.medium))
                    Text(model.downloadDirectory?.path ?? "폴더를 선택해 주세요").font(.caption).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                    Text("선택한 폴더 아래 ./KLAP/{과목명}/Video에 자동 저장").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("폴더 선택") {model.chooseDownloadDirectory()}
            }.help(model.downloadDirectory?.path ?? "")
            if #available(macOS 26.0, *) {Toggle("다운로드 후 한국어 전사",isOn:$model.downloadTranscribe)}
            else {Text("자동 전사는 macOS 26 이상에서 사용할 수 있습니다.").font(.caption).foregroundStyle(.secondary)}
            Text("전사 결과는 영상 옆 텍스트 파일로 저장됩니다.").font(.caption).foregroundStyle(.secondary)
            Stepper("동시 다운로드 상한: \(model.downloadMaximum)개",value:$model.downloadMaximum,in:1...8)
            Toggle("속도에 따라 동시 다운로드 조절",isOn:$model.downloadAdaptive)
            Text("최대 3개로 시작해 영상별 약 10 MB/s를 기준으로 늘리거나 일시정지합니다. 상한이 3개보다 작으면 설정한 개수로 시작합니다.").font(.caption).foregroundStyle(.secondary)
        }.disabled(model.downloadState.running).padding(16).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
    }
}
