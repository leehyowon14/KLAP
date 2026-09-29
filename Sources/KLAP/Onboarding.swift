import AppKit
import EventKit
import SwiftUI
import KLAPCore

@MainActor final class SetupModel: ObservableObject {
    @Published var step = 0
    @Published var calendars: [String] = []
    @Published var reminders: [String] = []
    @Published var calendarAllowed = false
    @Published var reminderAllowed = false
    @Published var loading = false
    @Published var error: String?
    @Published var timetable = UserDefaults.standard.string(forKey:"destinationTimetable") ?? ""
    @Published var academic = UserDefaults.standard.string(forKey:"destinationAcademic") ?? ""
    @Published var reminder = UserDefaults.standard.string(forKey:"destinationReminder") ?? ""
    @Published var automatic = true
    @Published var newTimetable = "KLAP 시간표"
    @Published var newAcademic = "KLAP 학사일정"
    @Published var newReminder = "KLAP 할 일"
    private let store = EKEventStore()
    var ready: Bool { calendarAllowed && reminderAllowed && !loading }
    func requestAccess() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            if #available(macOS 14.0, *) {
                calendarAllowed = try await store.requestFullAccessToEvents()
                reminderAllowed = try await store.requestFullAccessToReminders()
            } else {
                calendarAllowed = try await store.requestAccess(to: .event)
                reminderAllowed = try await store.requestAccess(to: .reminder)
            }
            let allEvents = calendarAllowed ? store.calendars(for:.event) : []
            let events = allEvents.filter(\.allowsContentModifications).map(\.title)
            let allLists = reminderAllowed ? store.calendars(for:.reminder) : []
            let lists = allLists.filter(\.allowsContentModifications).map(\.title)
            // The reused CLI resolves destinations by name. Ambiguous names must not be selectable.
            calendars = DestinationPolicy.uniqueNames(allEvents.map(\.title)).filter { events.contains($0) }
            reminders = DestinationPolicy.uniqueNames(allLists.map(\.title)).filter { lists.contains($0) }
            newTimetable = DestinationPolicy.availableName("KLAP 시간표",existing:allEvents.map(\.title))
            newAcademic = DestinationPolicy.availableName("KLAP 학사일정",existing:allEvents.map(\.title))
            newReminder = DestinationPolicy.availableName("KLAP 할 일",existing:allLists.map(\.title))
            if !calendarAllowed || !reminderAllowed { error = "캘린더와 미리 알림 접근을 허용해 주세요. 나중에 설정할 수도 있습니다." }
            else if calendars.count != events.count || reminders.count != lists.count { error = "이름이 중복된 캘린더·목록은 제외했습니다. 각 앱에서 이름을 구분하면 선택할 수 있습니다." }
            if !timetable.isEmpty && !calendars.contains(timetable) { timetable = "" }
            if !academic.isEmpty && !calendars.contains(academic) { academic = "" }
            if !reminder.isEmpty && !reminders.contains(reminder) { reminder = "" }
        } catch { self.error = error.localizedDescription }
    }
    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var setup: SetupModel
    @ViewState<String> private var studentID = ""
    @ViewState<String> private var password = ""
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("KLAP 시작하기").font(.title3.bold());Spacer();Text("\(setup.step+1) / 3").font(.caption).foregroundStyle(.secondary) }
            if setup.step == 0 {
                Text("학교 계정을 연결하세요").font(.headline)
                Text("수업과 강의 정보를 불러옵니다. 비밀번호는 OS 보안 저장소에 보관합니다.").font(.callout).foregroundStyle(.secondary)
                TextField("학번",text:$studentID)
                SecureField("비밀번호",text:$password)
                HStack {
                    Button("로그인하고 계속") { let secret=password;password="";Task {if await model.login(studentID:studentID,password:secret) {setup.step=1}} }.disabled(model.busy || studentID.isEmpty || password.isEmpty)
                    Button("CLI 계정 사용") {Task {await model.refresh();if model.snapshot.timetable != nil {setup.step=1}}}.disabled(model.busy)
                }
            } else if setup.step == 1 {
                Text("어디에 일정을 등록할까요?").font(.headline)
                Text("시간표·학사일정은 캘린더에, 과제·강의 마감은 미리 알림에 등록합니다. 대상 설정은 KLAP-Cli와 공유됩니다.").font(.caption).foregroundStyle(.secondary)
                if !setup.ready {
                    Button(setup.loading ? "권한 확인 중…" : "캘린더·미리 알림 접근 허용") {Task {await setup.requestAccess()}}.disabled(setup.loading)
                    Button("시스템 권한 설정 열기") {setup.openPrivacySettings()}.font(.caption)
                } else {
                    destination("시간표",selection:$setup.timetable,options:setup.calendars,newName:setup.newTimetable)
                    destination("학사일정",selection:$setup.academic,options:setup.calendars,newName:setup.newAcademic)
                    destination("미리 알림",selection:$setup.reminder,options:setup.reminders,newName:setup.newReminder)
                }
                if let error=setup.error {Text(error).font(.caption).foregroundStyle(.orange)}
                HStack { Button("이전") {setup.step=0};Button("다음") {setup.step=2}.disabled(!setup.ready) }
            } else {
                Text("자동 동기화와 알림").font(.headline)
                Toggle("30분마다 일정 자동 동기화",isOn:$setup.automatic)
                Toggle("강의 완료·전환·오류 알림",isOn:$model.notifications)
                Text("앱이 실행 중일 때 동기화합니다. 잠자기에서 깨어나면 다시 갱신하며, 메뉴바 팝오버를 닫아도 작업은 계속됩니다.").font(.caption).foregroundStyle(.secondary)
                HStack {Button("이전") {setup.step=1};Button("설정 저장하고 첫 동기화") {Task {await model.finishSetup()}}.disabled(model.busy)}
            }
            if let error=model.error {Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)}
            Button("나중에 설정") {model.skipSetup()}.font(.caption).disabled(model.busy || setup.loading)
        }.textFieldStyle(.roundedBorder).padding(12).frame(maxWidth:.infinity,alignment:.leading)
    }
    private func destination(_ label:String,selection:Binding<String>,options:[String],newName:String)->some View {
        Picker(label,selection:selection) {
            Text("새로 만들기 · \(newName)").tag("")
            ForEach(options,id:\.self) {Text($0).tag($0)}
        }
    }
}
