import AppKit
import SwiftUI
import KLAPCore

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A rounded menu-bar panel without NSPopover's pointer. The model outlives it.
@MainActor final class MenuPanel {
    private let window: KeyablePanel
    private var outsideMonitor: Any?
    private var keyMonitor: Any?
    var isVisible: Bool { window.isVisible }

    init(model: AppModel) {
        window = KeyablePanel(contentRect:NSRect(x:0,y:0,width:540,height:700),styleMask:[.borderless],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        window.title = "KLAP"
        window.contentView = NSHostingView(rootView:
            DashboardView(model:model)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius:18,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:18,style:.continuous).strokeBorder(.primary.opacity(0.12),lineWidth:0.5))
        )
    }

    func show(relativeTo button: NSStatusBarButton) {
        guard let screen=button.window?.screen ?? NSScreen.main else {return}
        // Keep the controls reachable when macOS temporarily has no status-item window.
        let anchor: CGRect
        if let statusWindow=button.window {
            anchor=statusWindow.convertToScreen(button.convert(button.bounds,to:nil))
        } else {
            anchor=CGRect(x:screen.visibleFrame.maxX-32,y:screen.visibleFrame.maxY,width:24,height:24)
        }
        let frame=MenuPanelPlacement.frame(anchor:anchor,visibleScreen:screen.visibleFrame,size:CGSize(width:540,height:700))
        window.setFrame(frame,display:true)
        NSApp.activate(ignoringOtherApps:true)
        window.makeKeyAndOrderFront(nil)
        if outsideMonitor == nil {
            outsideMonitor=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.hide() }
            }
            keyMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
                if event.keyCode == 53, self?.window.attachedSheet == nil { self?.hide();return nil }
                return event
            }
        }
    }

    func hide() {
        guard window.attachedSheet == nil else {return}
        window.orderOut(nil)
        if let monitor=outsideMonitor {NSEvent.removeMonitor(monitor);outsideMonitor=nil}
        if let monitor=keyMonitor {NSEvent.removeMonitor(monitor);keyMonitor=nil}
    }
}
