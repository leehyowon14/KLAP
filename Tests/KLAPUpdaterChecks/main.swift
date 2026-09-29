import AppKit
import Combine
import Sparkle

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let service=AppUpdater()
    let activity=CurrentValueSubject<Bool,Never>(false)
    service.observeActivity(activity.eraseToAnyPublisher())
    let controller=SPUStandardUpdaterController(startingUpdater:false,updaterDelegate:nil,userDriverDelegate:nil)
    let updater=controller.updater
    try! service.updater(updater,mayPerform:.updates)
    activity.send(true)
    for mode:SPUUpdateCheck in [.updates,.updatesInBackground,.updateInformation] {
        do {try service.updater(updater,mayPerform:mode);fatalError("Busy activity allowed update")} catch {}
    }
    // Only a placeholder item is required for the delegate's relaunch gate.
    let item=SUAppcastItem(dictionary:["title":"Test","sparkle:version":"2","enclosure":["url":"https://example.com/KLAP.zip","sparkle:version":"2"]])!
    var installs=0
    precondition(service.updater(updater,shouldPostponeRelaunchForUpdate:item,untilInvokingBlock:{installs+=1}))
    activity.send(true)
    precondition(installs==0)
    activity.send(false)
    precondition(installs==1)
    activity.send(false)
    precondition(installs==1,"Deferred handler called twice")
    precondition(!service.updater(updater,shouldPostponeRelaunchForUpdate:item,untilInvokingBlock:{installs+=1}))
    precondition(installs==1,"Idle installation must be handled by Sparkle")
    try! service.updater(updater,mayPerform:.updatesInBackground)
    service.setAutomatic(false)
    precondition(!service.automatic)
    service.setAutomatic(true)
    precondition(service.automatic)
    service.updater(updater,didFinishUpdateCycleFor:.updates,error:NSError(domain:SUSparkleErrorDomain,code:Int(SUError.noUpdateError.rawValue)))
    precondition(service.status=="최신 버전입니다.")
    service.updater(updater,didFinishUpdateCycleFor:.updates,error:NSError(domain:"Test",code:3,userInfo:[NSLocalizedDescriptionKey:"Offline"]))
    precondition(service.status=="Offline")
    UserDefaults.standard.removePersistentDomain(forName:Bundle.main.bundleIdentifier!)
    print("Updater busy checks, delayed relaunch, repeated idle, preference and failure checks passed")
}
