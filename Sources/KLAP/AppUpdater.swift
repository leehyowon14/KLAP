import AppKit
import Combine
import Sparkle

@MainActor final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheck=false
    @Published private(set) var automatic=false
    @Published private(set) var lastChecked:Date?
    @Published private(set) var status:String?
    private var controller:SPUStandardUpdaterController!
    private var subscriptions=Set<AnyCancellable>()
    private var installWhenIdle:(()->Void)?
    private var occupied=false
    private var started=false

    override init() {
        super.init()
        controller=SPUStandardUpdaterController(startingUpdater:false,updaterDelegate:self,userDriverDelegate:nil)
        controller.updater.publisher(for:\.canCheckForUpdates).assign(to:&$canCheck)
        controller.updater.publisher(for:\.automaticallyChecksForUpdates).assign(to:&$automatic)
        controller.updater.publisher(for:\.lastUpdateCheckDate).assign(to:&$lastChecked)
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
        guard !started else {return}
        started=true
        controller.startUpdater()
    }
    func setAutomatic(_ enabled:Bool) {
        controller.updater.automaticallyDownloadsUpdates=enabled
        controller.updater.automaticallyChecksForUpdates=enabled
    }
    @objc func check() {guard canCheck else {return};controller.checkForUpdates(nil)}
    func updater(_ updater:SPUUpdater,mayPerform updateCheck:SPUUpdateCheck)throws {
        guard !occupied else {
            throw NSError(domain:"KLAP.Update",code:1,userInfo:[NSLocalizedDescriptionKey:"진행 중인 수강·동기화 또는 초기 설정이 끝난 뒤 업데이트를 확인해 주세요."])
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
