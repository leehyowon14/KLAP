import AppKit
import Combine
import Sparkle

@MainActor final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheck=false
    @Published private(set) var automatic=false
    @Published private(set) var lastChecked:Date?
    @Published private(set) var status:String?
    private var engine:SPUUpdater?
    private var target:Bundle?
    private var subscriptions=Set<AnyCancellable>()
    private var installWhenIdle:(()->Void)?
    private var occupied=false
    private var started=false

    override init() {
        super.init()
        do {
            let host=try UpdateTarget.resolve(running:Bundle.main)
            target=host
            let driver=SPUStandardUserDriver(hostBundle:host,delegate:nil)
            let updater=SPUUpdater(hostBundle:host,applicationBundle:host,userDriver:driver,delegate:self)
            engine=updater
            updater.publisher(for:\.canCheckForUpdates).assign(to:&$canCheck)
            updater.publisher(for:\.automaticallyChecksForUpdates).assign(to:&$automatic)
            updater.publisher(for:\.lastUpdateCheckDate).assign(to:&$lastChecked)
        } catch {status=error.localizedDescription}
    }
    func observeActivity(_ activity:AnyPublisher<Bool,Never>) {
        activity.sink {[weak self] occupied in
            guard let self else {return}
            self.occupied=occupied
            if !occupied,let install=installWhenIdle {
                installWhenIdle=nil
                install()
            }
        }.store(in:&subscriptions)
    }
    func start() {
        guard Bundle.main.object(forInfoDictionaryKey:"KLAPDevelopmentBuild") as? Bool != true else {
            status="개발 빌드는 자동 업데이트를 사용하지 않습니다."
            return
        }
        guard !started,let engine else {return}
        started=true
        do {try engine.start()} catch {started=false;status=error.localizedDescription}
    }
    func setAutomatic(_ enabled:Bool) {
        guard Bundle.main.object(forInfoDictionaryKey:"KLAPDevelopmentBuild") as? Bool != true else {return}
        engine?.automaticallyDownloadsUpdates=enabled
        engine?.automaticallyChecksForUpdates=enabled
    }
    @objc func check() {guard canCheck else {return};engine?.checkForUpdates()}
    func updater(_ updater:SPUUpdater,mayPerform updateCheck:SPUUpdateCheck)throws {
        guard !occupied else {
            throw NSError(domain:"KLAP.Update",code:1,userInfo:[NSLocalizedDescriptionKey:"진행 중인 수강·동기화 또는 초기 설정이 끝난 뒤 업데이트를 확인해 주세요."])
        }
        guard let target else {throw UpdateTarget.failure}
        if Bundle.main.bundleURL.pathComponents.contains("AppTranslocation") {
            let current=try UpdateTarget.resolve(running:Bundle.main)
            guard current.bundleURL == target.bundleURL else {throw UpdateTarget.failure}
        }
        status=nil
    }
    func updater(_ updater:SPUUpdater,shouldPostponeRelaunchForUpdate item:SUAppcastItem,untilInvokingBlock installHandler:@escaping ()->Void)->Bool {
        guard occupied else {return false}
        installWhenIdle=installHandler
        status="진행 중인 작업이 끝나면 업데이트를 설치합니다."
        return true
    }
    func updater(_ updater:SPUUpdater,didFinishUpdateCycleFor updateCheck:SPUUpdateCheck,error:Error?) {
        if let error {
            // Sparkle treats an up-to-date result as SUNoUpdateError.
            status=(error as NSError).domain == SUSparkleErrorDomain && (error as NSError).code == SUError.noUpdateError.rawValue ? "최신 버전입니다." : error.localizedDescription
        }
    }
}
