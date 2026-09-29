import AppKit
import SwiftUI
import UserNotifications
import Network
import KLAPCore

@MainActor final class AppModel: ObservableObject {
    let attachments = AttachmentManager()
    let contentNotifications = ContentNotificationService()
    @Published var studyConfirmationPresented=false
    @Published var newNoticeNotifications = UserDefaults.standard.object(forKey:"newNoticeNotifications") as? Bool ?? true {
        didSet {UserDefaults.standard.set(newNoticeNotifications,forKey:"newNoticeNotifications");if newNoticeNotifications {requestNotifications()}}
    }
    @Published var newLectureNotifications = UserDefaults.standard.object(forKey:"newLectureNotifications") as? Bool ?? true {
        didSet {UserDefaults.standard.set(newLectureNotifications,forKey:"newLectureNotifications");if newLectureNotifications {requestNotifications()}}
    }
    let updater = AppUpdater()
    let loginItem = LoginItemController()
    @Published var boardPresentation: BoardPresentation?
    @Published var loggedOut = UserDefaults.standard.bool(forKey:"loggedOut")
    @Published var requestedLecture: String?
    @Published var noticeDetail: NoticeDetailResult?
    func loadNotice(_ id: String) async {
        guard !busy else { return }
        noticeDetail = nil
        await perform(["Command":"notice-detail", "ID":id]) { [self] event in
            if event.kind == "result" { noticeDetail = try event.decode(NoticeDetailResult.self) }
        }
    }
    @Published var snapshot = Snapshot()
    @Published var busy = false
    @Published var pendingDecisions: [String:String] = [:]
    @Published var studying = false
    @Published var message = "KLAS에 연결해 주세요"
    @Published var error: String?
    @Published var progress: StudyProgress?
    @Published var studyTime = StudyTime(achieved:nil,required:nil)
    @Published var queueRemaining: Double?
    private var studyQueue: [String] = []
    private var activeStudyID: String?
    private func updateStudyTime(id:String?, achieved:String?=nil, required:String?=nil) {
        guard let id, let index=studyQueue.firstIndex(of:id) else { return }
        activeStudyID=id
        let lecture=snapshot.lectures?.first(where:{$0.id == id})?.row.Lecture
        studyTime=StudyTime(achieved:achieved ?? lecture?.AchievedTime,required:required ?? lecture?.RequiredTime)
        var remaining=studyTime.remaining
        for next in studyQueue.dropFirst(index+1) {
            let row=snapshot.lectures?.first(where:{$0.id == next})?.row.Lecture
            let time=StudyTime(achieved:row?.AchievedTime,required:row?.RequiredTime)
            if let total=remaining, let next=time.remaining { remaining=total+next } else { remaining=nil }
        }
        queueRemaining=remaining
    }
    @Published var studyTitle = ""
    @Published var conflicts: [SyncConflict] = []
    @Published var selectedCourse: String? {
        didSet { if selectedCourse != oldValue { syllabus = nil; syllabusError = nil; showSyllabus = false } }
    }
    @Published var syllabus: CourseSyllabus?
    @Published var syllabusError: String?
    @Published var showSyllabus = false
    func loadSyllabus() async {
        guard !busy, let course = selectedCourse, let term = snapshot.timetable?.Term.value else { return }
        syllabusError = nil
        await perform(["Command":"syllabus", "Selector":course, "TermValue":term]) { [self] event in
            guard event.kind == "result", selectedCourse == course, snapshot.timetable?.Term.value == term else { return }
            syllabus = try event.decode(SyllabusResult.self).Syllabus
        }
        if selectedCourse == course { syllabusError = error }
    }
    @Published var lastRefresh: Date?
    @Published var lastSync: Date?
    @Published var showSettings = false
    @Published var showLogin = false
    @Published var autoSync = UserDefaults.standard.bool(forKey: "autoSync") {
        didSet { UserDefaults.standard.set(autoSync, forKey: "autoSync") }
    }
    @Published var notifications = UserDefaults.standard.object(forKey: "notifications") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifications, forKey: "notifications"); if notifications { requestNotifications() } }
    }
    let setup = SetupModel()
    @Published var onboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")
    private let bridge = BridgeClient()
    private let reminderCompletion = ReminderCompletion()
    @Published var reminderCompletionError: String?
    private var completionTasks: [Task<Void,Never>] = []
    private var timer: Timer?
    private let network = NWPathMonitor()
    private var wasOffline = false
    private var cancelled = false
    var reveal: (() -> Void)?
    @Published var notificationNavigation=UUID()
    var pendingContentActions:[(String,String)]=[]
    var handlingContentAction=false
    var activeContentAction:String?
    var courses: [Course] { snapshot.timetable?.Term.subjList ?? [] }
    var lectures: [LectureItem] { (snapshot.lectures ?? []).filter { selectedCourse == nil || $0.row.CourseName == selectedCourse } }
    var eligibleIDs: [String] { lectures.filter { $0.reason.isEmpty }.map(\.id) }

    func start() {
        contentNotifications.register()
        if notifications || newNoticeNotifications || newLectureNotifications {requestNotifications()}
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in Task { @MainActor in self?.scheduledRefresh() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.scheduledRefresh() } }
        network.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let recovered = self.wasOffline && path.status == .satisfied
                self.wasOffline = path.status != .satisfied
                if recovered { self.scheduledRefresh() }
            }
        }
        network.start(queue: DispatchQueue(label: "KLAP.network"))
        Task { await setup.requestAccess(); if !onboarding && !loggedOut { await refresh(); if autoSync && setup.ready { await sync() } } }
    }
    func scheduledRefresh() {
        guard !busy, !onboarding, !loggedOut else { return }
        Task { if !onboarding && !loggedOut { await refresh(); if autoSync { await sync() } } }
    }
    func logout() {
        guard !busy else { return }
        contentNotifications.clearDelivered()
        loggedOut=true
        UserDefaults.standard.set(true,forKey:"loggedOut")
        autoSync=false
        snapshot=Snapshot(); conflicts=[]; selectedCourse=nil
        lastRefresh=nil; lastSync=nil; error=nil; progress=nil; studyTitle=""
        showSettings=false; showLogin=false; onboarding=true; setup.step=0
        message="로그아웃했습니다"
    }
    func skipSetup() {
        if !UserDefaults.standard.bool(forKey:"destinationsConfigured") { autoSync = false }
        onboarding = false
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }
    func saveDestinations() async -> Bool {
        guard !busy, setup.ready else { return false }
        var saved = false
        await perform(["Command":"configure", "TimetableName":setup.timetable.isEmpty ? setup.newTimetable : setup.timetable, "AcademicName":setup.academic.isEmpty ? setup.newAcademic : setup.academic, "ReminderName":setup.reminder.isEmpty ? setup.newReminder : setup.reminder, "TimetableExisting":!setup.timetable.isEmpty, "AcademicExisting":!setup.academic.isEmpty, "ReminderExisting":!setup.reminder.isEmpty]) { event in saved = event.kind == "done" }
        guard saved, error == nil else { return false }
        UserDefaults.standard.set(setup.timetable.isEmpty ? setup.newTimetable : setup.timetable,forKey:"destinationTimetable")
        UserDefaults.standard.set(setup.academic.isEmpty ? setup.newAcademic : setup.academic,forKey:"destinationAcademic")
        UserDefaults.standard.set(setup.reminder.isEmpty ? setup.newReminder : setup.reminder,forKey:"destinationReminder")
        UserDefaults.standard.set(true, forKey: "destinationsConfigured")
        return true
    }
    func finishSetup() async {
        guard await saveDestinations() else { return }
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        autoSync = setup.automatic
        onboarding = false
        if notifications { requestNotifications() }
        await sync()
    }
    func requestNotifications() {
        contentNotifications.requestAuthorization()
    }
    private func notify(_ title: String, _ body: String) {
        guard notifications else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    func perform(_ request: [String: Any], handle: @escaping (BridgeEvent) throws -> Void) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await bridge.run(request) { [weak self] event in
                guard let self else { return }
                if event.kind == "error" { if !(self.studying && self.cancelled) { self.error = event.error }; return }
                do { try handle(event) } catch { self.error = "응답을 읽지 못했습니다: \(error.localizedDescription)" }
            }
        } catch { if self.error == nil && !(studying && cancelled) { self.error = error.localizedDescription } }
    }
    @discardableResult func refresh() async -> Snapshot? {
        guard !busy else { return nil }
        loggedOut=false
        UserDefaults.standard.set(false,forKey:"loggedOut")
        message = "수업과 강의를 불러오는 중…"
        var received = false
        var notificationSnapshot:Snapshot?
        await perform(["Command":"snapshot"]) { [self] event in
            guard event.kind == "result" else { return }
            let fresh = try event.decode(Snapshot.self)
            notificationSnapshot=fresh
            if let account=fresh.account,account != snapshot.account {
                if snapshot.account != nil {contentNotifications.clearDelivered()}
                snapshot=Snapshot();selectedCourse=nil
            }
            snapshot.account=fresh.account
            if let nextTerm=fresh.timetable?.Term.value, let previousTerm=snapshot.timetable?.Term.value, nextTerm != previousTerm { snapshot=Snapshot();selectedCourse=nil }
            snapshot.studentName=fresh.studentName
            // Partial failures retain the previous data and remain visibly stale.
            if let value = fresh.timetable { snapshot.timetable = value }
            if let value = fresh.lectures { snapshot.lectures = value }
            if let value = fresh.assignments { snapshot.assignments = value }
            if let value = fresh.notices { snapshot.notices = value }
            snapshot.errors = fresh.errors
            if fresh.errors.isEmpty { lastRefresh = Date() }
            error = fresh.errors.isEmpty ? nil : fresh.errors.joined(separator: "\n")
            received = true
        }
        if let notificationSnapshot {await contentNotifications.process(notificationSnapshot,preferences:{[self] in (newNoticeNotifications,newLectureNotifications)})}
        message = received && error == nil ? "최신 상태입니다" : "갱신하지 못한 정보가 있습니다"
        return notificationSnapshot
    }
    @discardableResult func login(studentID: String, password: String) async -> Bool {
        guard !busy else { return false }
        var succeeded = false
        await perform(["Command":"auth", "StudentID":studentID, "Password":password]) { event in succeeded = event.kind == "done" }
        if succeeded && error == nil { showLogin = false; await refresh(); return true }
        return false
    }
    func resolveConflict(_ key:String, decision:String) async {
        pendingDecisions[key]=decision
        if !busy { await flushDecisions() }
    }
    private func flushDecisions() async {
        guard !busy, !pendingDecisions.isEmpty else { return }
        let decisions=pendingDecisions
        await sync(decisions:decisions)
        if error == nil {
            for (key,value) in decisions where pendingDecisions[key] == value { pendingDecisions.removeValue(forKey:key) }
        }
    }
    func sync(decisions: [String: String] = [:]) async {
        guard !busy, !loggedOut else { return }
        guard UserDefaults.standard.bool(forKey: "destinationsConfigured") else { onboarding=true;setup.step=1;return }
        await setup.requestAccess(request:false)
        guard setup.ready else {
            message="동기화하려면 캘린더와 미리 알림 권한을 허용해 주세요."
            error=nil;showSettings=true;return
        }
        message = "캘린더와 미리 알림 동기화 중…"
        var succeeded = false
        await perform(["Command":"sync", "Decisions":decisions]) { [self] event in
            guard event.kind == "result" else { return }
            let result = try event.decode(SyncResult.self)
            conflicts = result.conflicts ?? []
            error = result.errors.isEmpty ? nil : result.errors.joined(separator: "\n")
            succeeded = error == nil && conflicts.isEmpty
            if succeeded { lastSync = Date() }
        }
        message = succeeded ? "일정 동기화 완료" : "동기화 결과를 확인해 주세요"
    }
    func openLecture(_ id: String) async {
        await perform(["Command":"open", "ID":id]) { event in
            guard event.kind == "result", let object = try JSONSerialization.jsonObject(with: event.data) as? [String: Any], let raw = object["URL"] as? String, let url = URL(string: raw), ["https","http"].contains(url.scheme?.lowercased() ?? "") else { return }
            NSWorkspace.shared.open(url)
        }
    }
    func attend(_ ids: [String],expectedAccount:String?=nil) async {
        guard !busy, !ids.isEmpty else { return }
        reminderCompletionError=nil
        cancelled = false; studying = true; requestNotifications()
        studyQueue=ids.reduce(into:[]) { if !$0.contains($1) { $0.append($1) } }
        updateStudyTime(id:studyQueue.first)
        progress = StudyProgress(percent: 0, current: 0, total: ids.count)
        await perform(["Command":"attend", "IDs":ids,"ExpectedAccount":expectedAccount ?? snapshot.account ?? ""]) { [self] event in
            let value = try event.decode(StudyEvent.self)
            let title = value.title ?? snapshot.lectures?.first(where: { $0.id == value.id })?.row.Lecture.Title ?? "강의"
            switch event.kind {
            case "start":
                updateStudyTime(id:value.id)
                studyTitle = title
                progress = StudyProgress(percent: 0, current: value.current ?? 0, total: value.total ?? ids.count)
                if (value.current ?? 0) > 1 { notify("다음 강의 수강 시작", "\(title) · \(progress?.label ?? "")") }
            case "progress":
                updateStudyTime(id:value.id,achieved:value.achieved,required:value.required)
                studyTitle = title
                progress = StudyProgress(percent: value.percent ?? 0, current: value.current ?? 0, total: value.total ?? ids.count)
            case "completed":
                if let id=value.id, UserDefaults.standard.bool(forKey:"destinationsConfigured"),
                   let list=UserDefaults.standard.string(forKey:"destinationReminder") {
                    completionTasks.append(Task { [self] in
                        do { try await self.reminderCompletion.complete(lectureID:id,listName:list) }
                        catch { self.reminderCompletionError="수강은 완료됐지만 미리 알림 완료 처리에 실패했습니다: " + error.localizedDescription }
                    })
                }
                notify("수강 완료", "\(title) · \(value.current ?? 0)/\(value.total ?? ids.count)")
            case "failed": notify("수강 확인 필요", "\(title): \(value.message ?? "실패")"); message = value.message ?? "수강 실패"
            case "done":
                message = "수강 종료 · 성공 \(value.success ?? 0), 실패 \(value.failed ?? 0)"
                notify("수강 작업 종료", message)
            default: break
            }
        }
        for task in completionTasks { await task.value }
        completionTasks=[]
        studying = false; progress = nil
        if cancelled { message = "수강을 취소했습니다" }
        else if let error { notify("수강 작업 중단", error) }
        // Refresh server state without replacing the final job summary.
        let summary = message
        await refresh(); message = summary
        await flushDecisions()
    }
    func cancel() { cancelled = true; bridge.cancel() }
}
