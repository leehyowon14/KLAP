import AppKit
import UserNotifications
import KLAPCore

@MainActor final class ContentNotificationService:ObservableObject {
    static let startOne="KLAP.START_LECTURE"
    static let startAll="KLAP.START_ALL_LECTURES"
    static let open="KLAP.OPEN_CONTENT"
    static let tokenKey="KLAP.contentAlert"
    @Published private(set) var authorization:UNAuthorizationStatus = .notDetermined
    @Published private(set) var deliveryError:String?
    @Published private(set) var requestingPermission=false
    private let readAuthorization:() async -> UNAuthorizationStatus
    private let authorize:() async throws -> Bool
    private let submitNotification:(UNNotificationRequest) async throws -> Void
    private let removeDeliveredNotifications:([String]) -> Void
    private(set) var history:ContentNotificationHistory
    private let defaults:UserDefaults
    private let key="contentNotifications.v1"
    private let center=UNUserNotificationCenter.current()
    init(defaults:UserDefaults = .standard,
         readAuthorization:(() async -> UNAuthorizationStatus)?=nil,
         authorize:(() async throws -> Bool)?=nil,
         submitNotification:((UNNotificationRequest) async throws -> Void)?=nil,
         removeDeliveredNotifications:(([String]) -> Void)?=nil) {
        self.readAuthorization=readAuthorization ?? {await UNUserNotificationCenter.current().notificationSettings().authorizationStatus}
        self.authorize=authorize ?? {try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound])}
        self.submitNotification=submitNotification ?? {try await UNUserNotificationCenter.current().add($0)}
        self.removeDeliveredNotifications=removeDeliveredNotifications ?? {UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:$0)}
        self.defaults=defaults
        history=defaults.data(forKey:key).flatMap{try? JSONDecoder().decode(ContentNotificationHistory.self,from:$0)} ?? ContentNotificationHistory()
    }
    static func categories()->Set<UNNotificationCategory> {
        let open=UNNotificationAction(identifier:open,title:"내용 보기",options:[.foreground])
        let single=UNNotificationAction(identifier:startOne,title:"수강 시작",options:[.foreground])
        let all=UNNotificationAction(identifier:startAll,title:"전체 수강 시작",options:[.foreground])
        return Set([
            UNNotificationCategory(identifier:"KLAP.NEW_NOTICE",actions:[open],intentIdentifiers:[]),
            UNNotificationCategory(identifier:"KLAP.NEW_LECTURE",actions:[single,open],intentIdentifiers:[]),
            UNNotificationCategory(identifier:"KLAP.NEW_LECTURES",actions:[all,open],intentIdentifiers:[]),
            UNNotificationCategory(identifier:"KLAP.NEW_CONTENT",actions:[open],intentIdentifiers:[])
        ])
    }
    func register() {center.setNotificationCategories(Self.categories());Task {await updateAuthorization()}}
    func updateAuthorization() async {
        authorization=await readAuthorization()
        if authorization == .denied {deliveryError=nil}
    }
    func requestAuthorization() {Task {await requestAuthorizationIfNeeded()}}
    func requestAuthorizationIfNeeded() async {
        guard !requestingPermission else {return}
        requestingPermission=true
        defer {requestingPermission=false}
        await updateAuthorization()
        // macOS only presents the permission dialog for an undecided app.
        // Repeating the call after denial produces a redundant system error.
        guard authorization == .notDetermined else {return}
        deliveryError=nil
        do {_ = try await authorize()}
        catch {
            deliveryError="알림 권한을 요청하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
        await updateAuthorization()
    }
    static func settingsURL(bundleID:String)->URL {
        var url=URLComponents(string:"x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
        url.queryItems=[URLQueryItem(name:"id",value:bundleID)]
        return url.url!
    }
    func openSettings() {
        let url=Self.settingsURL(bundleID:Bundle.main.bundleIdentifier ?? "dev.leehyowon.klap.mac")
        if !NSWorkspace.shared.open(url) {
            deliveryError="알림 설정을 열지 못했습니다. 시스템 설정의 알림에서 KLAP을 선택해 주세요."
        }
    }
    static func content(_ alert:ContentAlert)->UNMutableNotificationContent {
        let content=UNMutableNotificationContent()
        content.title=alert.title;content.body=alert.body;content.sound = .default
        content.userInfo=[tokenKey:alert.id]
        content.threadIdentifier="KLAP."+alert.kind.rawValue
        if alert.kind == .notice {content.categoryIdentifier="KLAP.NEW_NOTICE"}
        else if !alert.actionable {content.categoryIdentifier="KLAP.NEW_CONTENT"}
        else {content.categoryIdentifier=alert.ids.count==1 ? "KLAP.NEW_LECTURE" : "KLAP.NEW_LECTURES"}
        return content
    }
    func process(_ snapshot:Snapshot,preferences:()->(notices:Bool,lectures:Bool)) async {
        await updateAuthorization()
        let (notices,lectures)=preferences()
        let allowed=authorization == .authorized || authorization == .provisional
        // Muted/denied alerts are not replayed after permission is enabled later.
        for alert in history.alerts where !allowed || (alert.kind == .notice ? !notices : !lectures) {
            history.markDelivered(alert.id)
        }
        history.ingest(snapshot,notices:notices && allowed,lectures:lectures && allowed)
        persist()
        guard let account=snapshot.account,let term=snapshot.timetable?.Term.value,allowed else {return}
        for alert in history.pending(account:account,notices:notices,lectures:lectures).filter({$0.term==term}) {
            let enabled=preferences()
            guard alert.kind == .notice ? enabled.notices : enabled.lectures else {history.markDelivered(alert.id);persist();continue}
            do {
                let identifier="KLAP.content."+alert.id
                try await submitNotification(UNNotificationRequest(identifier:identifier,content:Self.content(alert),trigger:nil))
                let enabled=preferences()
                if !(alert.kind == .notice ? enabled.notices : enabled.lectures) {
                    removeDeliveredNotifications([identifier])
                }
                history.markDelivered(alert.id);persist();deliveryError=nil
            } catch {
                await updateAuthorization()
                if authorization != .denied {deliveryError="알림을 보내지 못했습니다. 잠시 후 다시 시도해 주세요."}
            }
        }
    }
    func clearDelivered() {center.removeAllDeliveredNotifications();center.removeAllPendingNotificationRequests()}
    private func persist() {
        do {defaults.set(try JSONEncoder().encode(history),forKey:key)}
        catch {deliveryError="알림 기록을 저장하지 못했습니다: "+error.localizedDescription}
    }
}
