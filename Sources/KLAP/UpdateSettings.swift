import SwiftUI

struct UpdateSettings:View {
    @ObservedObject var updater:AppUpdater
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                Text("앱 업데이트").font(.headline)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "").font(.caption).foregroundStyle(.secondary)
            }
            Toggle(isOn:Binding(get:{updater.automatic},set:{updater.setAutomatic($0)})) {
                VStack(alignment:.leading,spacing:4) {
                    Text("자동 업데이트").font(.callout.weight(.medium))
                    Text("새 버전을 자동으로 확인·다운로드하고 앱 종료 시 설치합니다.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.toggleStyle(.switch).controlSize(.small)
            Rectangle().fill(Theme.line).frame(height:1)
            HStack(alignment:.center) {
                VStack(alignment:.leading,spacing:4) {
                    if let status=updater.status {Text(status).font(.caption).foregroundStyle(.secondary)}
                    else if let checked=updater.lastChecked {Text("마지막 확인 \(checked.formatted(date:.abbreviated,time:.shortened))").font(.caption).foregroundStyle(.secondary)}
                    else {Text("하루마다 새 버전 확인").font(.caption).foregroundStyle(.secondary)}
                }
                Spacer()
                Button("업데이트 확인") {updater.check()}.buttonStyle(FormButtonStyle(compact:true)).disabled(!updater.canCheck)
            }
        }.frame(maxWidth:.infinity,alignment:.leading).padding(16).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
    }
}
