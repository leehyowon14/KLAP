import AppKit
import SwiftUI
import Combine
import UserNotifications
import KLAPCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var item: NSStatusItem!
    private var panel: MenuPanel!
    private let model = AppModel()
    private var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        item.button?.target = self
        item.button?.action = #selector(toggle)
        panel = MenuPanel(model:model)
        model.$progress.sink { [weak self] progress in self?.updateIcon(progress) }.store(in:&subscriptions)
        UNUserNotificationCenter.current().delegate = self
        model.reveal = { [weak self] in self?.show() }
        model.start()
        if model.onboarding { DispatchQueue.main.async { [weak self] in self?.show() } }
    }
    func applicationWillTerminate(_ notification: Notification) { model.cancel() }
    @objc private func toggle() { if panel.isVisible {panel.hide()} else {show()} }
    private func show() {
        guard let button=item.button else {return}
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
 app.run()
}
