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
    private let steps = ["계정 연결", "등록 위치", "동기화 설정"]

    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(spacing:8) {
                ForEach(0..<steps.count,id:\.self) { index in
                    HStack(spacing:5) {
                        Text("\(index+1)").font(.system(size:10,weight:.semibold)).frame(width:18,height:18)
                            .background(index == setup.step ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),in:Circle())
                        Text(steps[index]).font(.caption.weight(index == setup.step ? .semibold : .regular))
                    }.foregroundStyle(index == setup.step ? Color.accentColor : .secondary)
                    if index < steps.count-1 { Image(systemName:"chevron.right").font(.system(size:8,weight:.medium)).foregroundStyle(.tertiary) }
                }
                Spacer(minLength:0)
            }.accessibilityElement(children:.ignore).accessibilityLabel("설정 \(setup.step+1)단계, \(steps[setup.step])")

            VStack(alignment:.leading,spacing:6) {
                Text(title).font(.system(size:21,weight:.semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }

            if setup.step == 0 {
                VStack(alignment:.leading,spacing:12) {
                    VStack(alignment:.leading,spacing:5) {
                        Text("학번").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        TextField("학번 입력",text:$studentID).accessibilityLabel("학번").modifier(AccountFieldStyle())
                    }
                    VStack(alignment:.leading,spacing:5) {
                        Text("비밀번호").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        SecureField("KLAS 비밀번호",text:$password).accessibilityLabel("비밀번호").modifier(AccountFieldStyle())
                    }
                }
                HStack {
                    Button("저장된 계정 사용") {Task {await model.refresh();if model.snapshot.timetable != nil {setup.step=1}}}
                        .buttonStyle(.borderless).disabled(model.busy)
                    Spacer()
                    Button("로그인하고 계속") {
                        let secret=password;password=""
                        Task {if await model.login(studentID:studentID,password:secret) {setup.step=1}}
                    }.buttonStyle(.borderedProminent).disabled(model.busy || studentID.trimmingCharacters(in:.whitespaces).isEmpty || password.isEmpty)
                }
            } else if setup.step == 1 {
                if !setup.ready {
                    VStack(alignment:.leading,spacing:10) {
                        Button(setup.loading ? "권한 확인 중…" : "캘린더·미리 알림 접근 허용") {Task {await setup.requestAccess()}}
                            .buttonStyle(.borderedProminent).disabled(setup.loading)
                        Button("시스템 권한 설정 열기") {setup.openPrivacySettings()}.buttonStyle(.borderless).font(.caption)
                    }
                } else {
                    VStack(spacing:12) {
                        destination("시간표",selection:$setup.timetable,options:setup.calendars,newName:setup.newTimetable)
                        destination("학사일정",selection:$setup.academic,options:setup.calendars,newName:setup.newAcademic)
                        destination("미리 알림",selection:$setup.reminder,options:setup.reminders,newName:setup.newReminder)
                    }
                }
                if let error=setup.error {Text(error).font(.caption).foregroundStyle(.orange)}
                HStack {
                    Button("이전") {setup.step=0}.buttonStyle(.borderless)
                    Spacer()
                    Button("다음") {setup.step=2}.buttonStyle(.borderedProminent).disabled(!setup.ready)
                }
            } else {
                VStack(alignment:.leading,spacing:12) {
                    Toggle("30분마다 일정 자동 동기화",isOn:$setup.automatic)
                    Toggle("강의 완료·전환·오류 알림",isOn:$model.notifications)
                }.toggleStyle(.switch).controlSize(.small)
                HStack {
                    Button("이전") {setup.step=1}.buttonStyle(.borderless)
                    Spacer()
                    Button("저장하고 첫 동기화") {Task {await model.finishSetup()}}.buttonStyle(.borderedProminent).disabled(model.busy)
                }
            }
            if let error=model.error {Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)}
            Button("나중에 설정") {model.skipSetup()}.buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary).disabled(model.busy || setup.loading)
        }.padding(.vertical,8).frame(maxWidth:.infinity,alignment:.leading)
    }
    private var title: String {
        ["학교 계정을 연결하세요", "일정을 등록할 곳을 선택하세요", "자동으로 관리할 준비가 됐어요"][setup.step]
    }
    private var subtitle: String {
        ["수업과 강의 정보를 불러옵니다. 비밀번호는 안전하게 보관됩니다.",
         "수업·학사일정은 캘린더에, 마감은 미리 알림에 등록합니다. 대상 설정은 KLAP-Cli와 공유됩니다.",
         "앱이 실행 중일 때 동기화하고, 잠자기에서 깨어나면 다시 갱신합니다."][setup.step]
    }
    private func destination(_ label:String,selection:Binding<String>,options:[String],newName:String)->some View {
        HStack {
            Text(label).font(.callout.weight(.medium)).frame(width:64,alignment:.leading)
            Picker(label,selection:selection) {
                Text("새로 만들기 · \(newName)").tag("")
                ForEach(options,id:\.self) {Text($0).tag($0)}
            }.labelsHidden().frame(maxWidth:.infinity)
        }
    }
}
