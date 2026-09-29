import AppKit
import SwiftUI
import Combine
import UserNotifications
import KLAPCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var item: NSStatusItem!
    private var panel: MenuPanel!
    private(set) var didInitializeModel = false
    // EventKit setup must not run before NSApplication has its delegate.
    // Create it only after the status item has a usable icon and action.
    private lazy var model: AppModel = {
        didInitializeModel = true
        return AppModel()
    }()
    private var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.sendAction(on:[.leftMouseUp,.rightMouseUp])
        updateIcon(nil)
        panel = MenuPanel(model:model)
        Publishers.CombineLatest(model.$progress,model.$downloadState).sink { [weak self] progress,download in
            self?.updateIcon(progress ?? (download.running ? StudyProgress(percent:download.displayFraction*100,current:download.displayCurrent,total:download.displayTotal) : nil))
            if download.running {self?.item.button?.toolTip="KLAP · \(download.transcribing ? "전사" : "다운로드") \(download.displayCurrent)/\(download.displayTotal)"}
        }.store(in:&subscriptions)
        UNUserNotificationCenter.current().delegate = self
        model.reveal = { [weak self] in self?.show() }
        if !ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            let loginLaunch=LoginLaunch.isLoginItem(NSAppleEventManager.shared().currentAppleEvent)
            InstallationNotice.showIfNeeded { [weak self] in
                guard let self else {return}
                self.model.start()
                self.model.updater.observeActivity(Publishers.CombineLatest4(self.model.$busy,self.model.$studying,self.model.$onboarding,self.model.$downloadState).map {$0 || $1 || $2 || $3.running}.eraseToAnyPublisher())
                self.model.updater.start()
                if !loginLaunch {DispatchQueue.main.async {self.show()}}
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) { if didInitializeModel { model.cancel();model.cancelDownloads() } }
    @objc private func toggle() {
        guard let item, let panel else { return }
        if NSApp.currentEvent?.type == .rightMouseUp, let button=item.button {
            let menu=NSMenu()
            let open=menu.addItem(withTitle:"KLAP 열기",action:#selector(openPanel),keyEquivalent:"")
            open.target=self
            let update=menu.addItem(withTitle:"업데이트 확인…",action:#selector(AppUpdater.check),keyEquivalent:"")
            update.target=model.updater
            update.isEnabled=model.updater.canCheck
            menu.addItem(.separator())
            let quit=menu.addItem(withTitle:"KLAP 종료",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
            quit.target=NSApp
            NSMenu.popUpContextMenu(menu,with:NSApp.currentEvent!,for:button)
            return
        }
        if panel.isVisible {panel.hide()} else {show()}
    }
    @objc private func openPanel() { show() }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {
        show()
        return false
    }
    func smokeCheck() -> [String:Bool] {
        guard let item, let panel else { return ["initialized":false] }
        panel.hide()
        item.button?.performClick(nil)
        let firstClickOpened=panel.isVisible
        show()
        let shown=panel.isVisible
        let anchored=item.button.map { panel.isAnchored(to:$0) } ?? false
        panel.hide()
        _ = applicationShouldHandleReopen(NSApp,hasVisibleWindows:false)
        let reopened=panel.isVisible
        model.boardPresentation=BoardPresentation(reference:BoardReference(kind:"notice",term:"test",subject:"test",board:"1",master:"1"),title:"테스트")
        item.button?.performClick(nil)
        let detailIconClosed = !panel.isVisible
        show()
        panel.hide() // The global outside-click monitor follows this same path.
        let detailOutsideClosed = !panel.isVisible
        show()
        model.boardPresentation=nil
        NSApp.keyWindow?.resignKey()
        item.button?.performClick(nil)
        let inactiveIconClosed = !panel.isVisible
        var repeatedToggle=true
        for _ in 0..<4 {
            item.button?.performClick(nil);repeatedToggle = repeatedToggle && panel.isVisible
            item.button?.performClick(nil);repeatedToggle = repeatedToggle && !panel.isVisible
        }
        show()
        model.studyConfirmationPresented=true
        if let window=NSApp.windows.first(where:{$0.title == "KLAP"}),let event=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,characters:"\u{1b}",charactersIgnoringModifiers:"\u{1b}",isARepeat:false,keyCode:53) {NSApp.sendEvent(event)}
        let studyEscapeCancelled = !model.studyConfirmationPresented && panel.isVisible
        model.studyConfirmationPresented=true
        panel.hide()
        let studyHideCancelled = !model.studyConfirmationPresented
        return ["studyEscapeCancelled":studyEscapeCancelled,"studyHideCancelled":studyHideCancelled,"initialized":true,"delegateRetained":NSApp.delegate === self,
                "accessory":NSApp.activationPolicy() == .accessory,
                "statusVisible":item.isVisible,"iconPresent":item.button?.image != nil,
                "statusHasWidth":(item.button?.frame.width ?? 0) > 0,
                "detailIconClosed":detailIconClosed,"detailOutsideClosed":detailOutsideClosed,"inactiveIconClosed":inactiveIconClosed,"repeatedToggle":repeatedToggle,
                "panelAnchored":anchored,"firstClickOpened":firstClickOpened,"panelOpened":shown,"reopenOpened":reopened,"panelClosed":!panel.isVisible]
    }
    private func show() {
        guard let button=item?.button, let panel else {return}
        panel.show(relativeTo:button)
    }
    private func updateIcon(_ progress:StudyProgress?) {
        guard let button=item.button else {return}
        if let progress {
            let image=NSImage(size:NSSize(width:24,height:24),flipped:false) { rect in
                NSColor.labelColor.withAlphaComponent(0.22).setStroke()
                let background=NSBezierPath(ovalIn:NSRect(x:1,y:1,width:22,height:22));background.lineWidth=2;background.stroke()
                NSColor.labelColor.setStroke()
                let arc=NSBezierPath();arc.lineWidth=2.5;arc.lineCapStyle = .round
                arc.appendArc(withCenter:NSPoint(x:12,y:12),radius:11,startAngle:90,endAngle:90-CGFloat(progress.fraction)*360,clockwise:true);arc.stroke()
                NSImage(systemSymbolName:"graduationcap.fill",accessibilityDescription:nil)?
                    .draw(in:NSRect(x:5,y:6,width:14,height:12))
                return true
            }
            image.isTemplate=true;button.image=image;button.title="\(progress.label) ";button.imagePosition = .imageTrailing
            button.toolTip="KLAP · \(Int(progress.fraction*100))% · \(progress.label)"
            button.setAccessibilityLabel(button.toolTip)
        } else {
            button.image=NSImage(systemSymbolName:"graduationcap.fill",accessibilityDescription:"KLAP 열기")
            button.imagePosition = .imageOnly;button.title="";button.toolTip="KLAP · 시간표와 강의";button.setAccessibilityLabel("KLAP 열기")
        }
    }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void) { completionHandler([.banner,.sound]) }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping ()->Void) { Task { @MainActor in
        if response.actionIdentifier != UNNotificationDismissActionIdentifier {
            self.show()
            if let token=response.notification.request.content.userInfo[ContentNotificationService.tokenKey] as? String {
                self.model.receiveContentAction(token:token,action:response.actionIdentifier)
            }
        }
        completionHandler()
    } }
}
MainActor.assumeIsolated {
 let app=NSApplication.shared
 let delegate=AppDelegate()
 app.delegate=delegate
 let deferredModel = !delegate.didInitializeModel
 if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
     DispatchQueue.main.asyncAfter(deadline:.now()+1) { [weak delegate] in
         var checks=delegate?.smokeCheck() ?? ["delegateRetained":false]
         checks["modelDeferredUntilLaunch"] = deferredModel
         let data=try! JSONSerialization.data(withJSONObject:checks,options:.sortedKeys)
         FileHandle.standardOutput.write(data)
         FileHandle.standardOutput.write(Data("\n".utf8))
         exit(checks.values.allSatisfy{$0} ? 0 : 1)
     }
 }
 withExtendedLifetime(delegate) { app.run() }
}
