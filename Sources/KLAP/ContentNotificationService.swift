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
    private(set) var history:ContentNotificationHistory
    private let defaults:UserDefaults
    private let key="contentNotifications.v1"
    private let center=UNUserNotificationCenter.current()
    init(defaults:UserDefaults = .standard) {
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
    func updateAuthorization() async {authorization=await center.notificationSettings().authorizationStatus}
    func requestAuthorization() {
        Task {
            do {_ = try await center.requestAuthorization(options:[.alert,.sound]);deliveryError=nil}
            catch {deliveryError=error.localizedDescription}
            await updateAuthorization()
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
                try await center.add(UNNotificationRequest(identifier:"KLAP.content."+alert.id,content:Self.content(alert),trigger:nil))
                let enabled=preferences()
                if !(alert.kind == .notice ? enabled.notices : enabled.lectures) {
                    center.removeDeliveredNotifications(withIdentifiers:["KLAP.content."+alert.id])
                }
                history.markDelivered(alert.id);persist();deliveryError=nil
            } catch {deliveryError="알림을 보내지 못했습니다: "+error.localizedDescription}
        }
    }
    func clearDelivered() {center.removeAllDeliveredNotifications();center.removeAllPendingNotificationRequests()}
    private func persist() {
        do {defaults.set(try JSONEncoder().encode(history),forKey:key)}
        catch {deliveryError="알림 기록을 저장하지 못했습니다: "+error.localizedDescription}
    }
}
