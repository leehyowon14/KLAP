import SwiftUI
import ServiceManagement

struct LoginItemSettings:View {
    @ObservedObject var controller:LoginItemController
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Toggle(isOn:Binding(get:{controller.registered},set:{enabled in Task {await controller.setEnabled(enabled)}})) {
                VStack(alignment:.leading,spacing:4) {
                    Text("Mac 로그인 시 자동 실행").font(.callout.weight(.medium))
                    Text("로그인하면 메뉴바에서 KLAP을 시작합니다.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.disabled(controller.changing)
            if controller.status == .requiresApproval {
                HStack {
                    Text("시스템 설정에서 승인이 필요합니다.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("로그인 항목 열기") {controller.openSettings()}.buttonStyle(FormButtonStyle(compact:true))
                }
            }
            if controller.status == .notFound {
                Text("앱 등록 정보를 찾지 못했습니다. KLAP.app을 응용 프로그램 폴더에서 실행해 주세요.").font(.caption).foregroundStyle(.secondary)
            }
            if let error=controller.error {Text("자동 실행 설정 실패: "+error).font(.caption).foregroundStyle(.red)}
        }.task {controller.refresh()}
    }
}
