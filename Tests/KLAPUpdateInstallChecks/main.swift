import AppKit
import Sparkle

// Isolated local-feed harness. Never uses the user's KLAP bundle, account or feed.
@MainActor func record(_ text:String) {
    let path=Bundle.main.object(forInfoDictionaryKey:"TestResult") as! String
    let data=Data((text+"\n").utf8)
    if let file=FileHandle(forWritingAtPath:path) {file.seekToEndOfFile();file.write(data);try? file.close()}
    else {try! data.write(to:URL(fileURLWithPath:path))}
}
@MainActor final class Driver:SPUStandardUserDriver {
    override func showUserInitiatedUpdateCheck(cancellation:@escaping ()->Void) {}
    override func showUpdateFound(with item:SUAppcastItem,state:SPUUserUpdateState,reply:@escaping (SPUUserUpdateChoice)->Void) {record("found");reply(.install)}
    override func showReady(toInstallAndRelaunch reply:@escaping (SPUUserUpdateChoice)->Void) {record("ready");reply(.install)}
    override func showUpdaterError(_ error:Error,acknowledgement:@escaping ()->Void) {record("ERROR: \(error)");acknowledgement();NSApp.terminate(nil)}
    override func showUpdateNotFoundWithError(_ error:Error,acknowledgement:@escaping ()->Void) {record("ERROR: no update \(error)");acknowledgement();NSApp.terminate(nil)}
}
@MainActor final class Delegate:NSObject,NSApplicationDelegate {
    var updater:SPUUpdater?
    func applicationDidFinishLaunching(_ notification:Notification) {
        record("launch \(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion")!) \(Bundle.main.bundlePath)")
        if Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String == "2" {record("PASS relaunched");NSApp.terminate(nil);return}
        do {
            let path=Bundle.main.object(forInfoDictionaryKey:"TestOriginal") as! String
            let host=try UpdateTarget.resolve(running:Bundle.main,original:{_ in URL(fileURLWithPath:path)},installed:{_ in true})
            record("target \(host.bundlePath)")
            guard host.bundleURL.resolvingSymlinksInPath().path == URL(fileURLWithPath:path).resolvingSymlinksInPath().path else {throw UpdateTarget.failure}
            updater=SPUUpdater(hostBundle:host,applicationBundle:host,userDriver:Driver(hostBundle:host,delegate:nil),delegate:nil)
            try updater!.start()
            updater!.automaticallyChecksForUpdates=false
            updater!.checkForUpdates()
        } catch {record("ERROR: \(error)");NSApp.terminate(nil)}
        DispatchQueue.main.asyncAfter(deadline:.now()+90) {record("ERROR: timeout");NSApp.terminate(nil)}
    }
}
MainActor.assumeIsolated {
let app=NSApplication.shared
let delegate=Delegate()
app.delegate=delegate
app.setActivationPolicy(.accessory)
app.run()

}
