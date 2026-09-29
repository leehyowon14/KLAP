import AppKit
import Combine
import Sparkle

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let root=URL(fileURLWithPath:CommandLine.arguments[1])
    let running=Bundle(url:root.appendingPathComponent("AppTranslocation/test/KLAP.app"))!
    let original=root.appendingPathComponent("original.app")
    let selected=try! UpdateTarget.resolve(running:running,original:{_ in original},installed:{_ in true})
    precondition(selected.bundleURL == original)
    precondition(try! UpdateTarget.resolve(running:Bundle.main,original:{_ in preconditionFailure()}).bundleURL == Bundle.main.bundleURL)
    for name in ["tampered.app","different.app","unsigned.app","missing.app","AppTranslocation/test/KLAP.app"] {
        do { _=try UpdateTarget.resolve(running:running,original:{_ in root.appendingPathComponent(name)},installed:{_ in true});fatalError("Accepted invalid target: \(name)") } catch {}
    }
    do {_=try UpdateTarget.resolve(running:running,original:{_ in nil});fatalError("Accepted unknown origin")} catch {}
    do {_=try UpdateTarget.resolve(running:running,original:{_ in original},installed:{_ in false});fatalError("Accepted external origin")} catch {}
    print("Original target, unknown origin, external location, signature tamper and version mismatch checks passed")
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
