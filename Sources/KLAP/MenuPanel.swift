import AppKit
import SwiftUI
import KLAPCore

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct MenuBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// A rounded menu-bar panel without NSPopover's pointer. The model outlives it.
@MainActor final class MenuPanel {
    private let window: KeyablePanel
    private let model: AppModel
    private var pendingShow: DispatchWorkItem?
    private var outsideMonitor: Any?
    private var keyMonitor: Any?
    func isAnchored(to button:NSStatusBarButton) -> Bool {
        guard let statusWindow=button.window, let screen=statusWindow.screen else { return false }
        let anchor=statusWindow.convertToScreen(button.convert(button.bounds,to:nil))
        guard MenuPanelPlacement.validAnchor(anchor,screen:screen.frame) else { return false }
        let expected=MenuPanelPlacement.frame(anchor:anchor,visibleScreen:screen.visibleFrame,size:CGSize(width:540,height:700))
        return abs(window.frame.minX-expected.minX) < 1 && abs(window.frame.maxY-expected.maxY) < 1
    }
    var isVisible: Bool { window.isVisible }

    init(model: AppModel) {
        self.model=model
        window = KeyablePanel(contentRect:NSRect(x:0,y:0,width:540,height:700),styleMask:[.borderless],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        // Visibility is managed by our outside-click handler, not NSPanel's
        // implicit app-deactivation hiding.
        window.hidesOnDeactivate = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        window.title = "KLAP"
        window.contentView = NSHostingView(rootView:
            DashboardView(model:model)
                .background(MenuBackdrop())
                .clipShape(RoundedRectangle(cornerRadius:18,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:18,style:.continuous).strokeBorder(.primary.opacity(0.12),lineWidth:0.5))
        )
    }

    func show(relativeTo button: NSStatusBarButton) {
        pendingShow?.cancel()
        present(relativeTo:button,attempt:0)
    }

    private func present(relativeTo button:NSStatusBarButton, attempt:Int) {
        guard let statusWindow=button.window, let screen=statusWindow.screen,
              MenuPanelPlacement.validAnchor(statusWindow.convertToScreen(button.convert(button.bounds,to:nil)),screen:screen.frame) else {
            // A newly registered status item can temporarily report an origin of
            // (0,0). Wait for AppKit layout instead of opening in a guessed corner.
            guard attempt < 20 else { pendingShow=nil;return }
            let retry=DispatchWorkItem { [weak self, weak button] in
                guard let self, let button else { return }
                self.present(relativeTo:button,attempt:attempt+1)
            }
            pendingShow=retry
            DispatchQueue.main.asyncAfter(deadline:.now()+0.05,execute:retry)
            return
        }
        pendingShow=nil
        let anchor=statusWindow.convertToScreen(button.convert(button.bounds,to:nil))
        let frame=MenuPanelPlacement.frame(anchor:anchor,visibleScreen:screen.visibleFrame,size:CGSize(width:540,height:700))
        window.setFrame(frame,display:true)
        NSApp.activate(ignoringOtherApps:true)
        window.makeKeyAndOrderFront(nil)
        window.setFrame(frame,display:true)
        if outsideMonitor == nil {
            outsideMonitor=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) { [weak self, weak button] _ in
                MainActor.assumeIsolated {
                    // The status button handles its own click on mouse-up.
                    // Do not queue a hide that can run after that click opens us.
                    if let button, let statusWindow=button.window {
                        let bounds=statusWindow.convertToScreen(button.convert(button.bounds,to:nil))
                        if bounds.contains(NSEvent.mouseLocation) { return }
                    }
                    self?.hide()
                }
            }
            keyMonitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.leftMouseDown,.rightMouseDown]) { [weak self, weak button] event in
                guard let self else { return event }
                if event.type == .leftMouseDown || event.type == .rightMouseDown {
                    // Global monitors exclude this app's other windows (e.g. a preview).
                    if event.window !== self.window, event.window !== button?.window, event.window?.sheetParent !== self.window { self.hide() }
                    return event
                }
                if event.keyCode == 53, event.window === self.window, self.window.attachedSheet == nil {
                    if self.model.boardPresentation == nil { self.hide();return nil }
                    // Let the detail view's cancel button handle Escape, including its disabled state.
                    return event
                }
                return event
            }
        }
    }

    func hide() {
        pendingShow?.cancel()
        pendingShow=nil
        guard window.attachedSheet == nil else {return}
        window.orderOut(nil)
        if let monitor=outsideMonitor {NSEvent.removeMonitor(monitor);outsideMonitor=nil}
        if let monitor=keyMonitor {NSEvent.removeMonitor(monitor);keyMonitor=nil}
    }
}
