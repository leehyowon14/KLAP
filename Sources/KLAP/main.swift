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
        model.$progress.sink { [weak self] progress in self?.updateIcon(progress) }.store(in:&subscriptions)
        UNUserNotificationCenter.current().delegate = self
        model.reveal = { [weak self] in self?.show() }
        if !ProcessInfo.processInfo.arguments.contains("--smoke-test") { model.start() }
        if !ProcessInfo.processInfo.arguments.contains("--smoke-test") { DispatchQueue.main.async { [weak self] in self?.show() } }
    }
    func applicationWillTerminate(_ notification: Notification) { if didInitializeModel { model.cancel() } }
    @objc private func toggle() {
        guard let item, let panel else { return }
        if NSApp.currentEvent?.type == .rightMouseUp, let button=item.button {
            let menu=NSMenu()
            let open=menu.addItem(withTitle:"KLAP 열기",action:#selector(openPanel),keyEquivalent:"")
            open.target=self
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
        show()
        let shown=panel.isVisible
        panel.hide()
        _ = applicationShouldHandleReopen(NSApp,hasVisibleWindows:false)
        let reopened=panel.isVisible
        panel.hide()
        return ["initialized":true,"delegateRetained":NSApp.delegate === self,
                "accessory":NSApp.activationPolicy() == .accessory,
                "statusVisible":item.isVisible,"iconPresent":item.button?.image != nil,
                "statusHasWidth":(item.button?.frame.width ?? 0) > 0,
                "panelOpened":shown,"reopenOpened":reopened,"panelClosed":!panel.isVisible]
    }
    private func show() {
        guard let button=item?.button, let panel else {return}
        panel.show(relativeTo:button)
    }
    private func updateIcon(_ progress:StudyProgress?) {
        guard let button=item.button else {return}
        if let progress {
            let image=NSImage(size:NSSize(width:20,height:20),flipped:false) { rect in
                NSColor.labelColor.withAlphaComponent(0.22).setStroke()
                let background=NSBezierPath(ovalIn:NSRect(x:2,y:2,width:16,height:16));background.lineWidth=2;background.stroke()
                NSColor.labelColor.setStroke()
                let arc=NSBezierPath();arc.lineWidth=2.5;arc.lineCapStyle = .round
                arc.appendArc(withCenter:NSPoint(x:10,y:10),radius:8,startAngle:90,endAngle:90-CGFloat(progress.fraction)*360,clockwise:true);arc.stroke()
                return true
            }
            image.isTemplate=true;button.image=image;button.title=" \(progress.label)"
            button.toolTip="KLAP · \(Int(progress.fraction*100))% · \(progress.label)"
            button.setAccessibilityLabel(button.toolTip)
        } else {
            button.image=NSImage(systemSymbolName:"graduationcap.fill",accessibilityDescription:"KLAP 열기")
            button.title="";button.toolTip="KLAP · 시간표와 강의";button.setAccessibilityLabel("KLAP 열기")
        }
    }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void) { completionHandler([.banner,.sound]) }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping ()->Void) { Task { @MainActor in self.show();completionHandler() } }
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
