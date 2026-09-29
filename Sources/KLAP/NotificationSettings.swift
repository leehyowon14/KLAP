import SwiftUI
import UserNotifications

struct NotificationSettings:View {
    @ObservedObject var model:AppModel
    @ObservedObject var service:ContentNotificationService
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("알림").font(.headline)
            Toggle("새 공지",isOn:$model.newNoticeNotifications)
            Rectangle().fill(Theme.line).frame(height:1)
            Toggle("새 강의",isOn:$model.newLectureNotifications)
            Rectangle().fill(Theme.line).frame(height:1)
            Toggle("강의 수강 상태",isOn:$model.notifications)
            Text("앱 실행 중 30분마다 새 공지·강의를 확인합니다. 새 강의 알림에서 바로 수강하거나 함께 등록된 강의를 전체 수강할 수 있습니다.")
                .font(.caption).foregroundStyle(.secondary)
            if service.authorization == .denied {
                HStack {
                    Text("macOS에서 알림이 꺼져 있습니다.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("시스템 설정 열기") {NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/System Settings.app"))}
                        .buttonStyle(FormButtonStyle(compact:true))
                }
            } else if service.authorization == .notDetermined {
                Button("알림 허용") {service.requestAuthorization()}.buttonStyle(FormButtonStyle(compact:true))
            }
            if let error=service.deliveryError {Text(error).font(.caption).foregroundStyle(.red)}
        }.toggleStyle(.switch).controlSize(.small).frame(maxWidth:.infinity,alignment:.leading)
            .padding(16).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
            .task {await service.updateAuthorization()}
            .onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) { _ in Task {await service.updateAuthorization()} }
    }
}