import AppKit
import SwiftUI
import KLAPCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "graduationcap.fill", accessibilityDescription: "KLAP 열기")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 520, height: 660)
        popover.contentViewController = NSHostingController(rootView: ShellView())
    }
    @objc private func toggle() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = item.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct ShellView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Label("KLAP", systemImage: "graduationcap.fill").font(.title2.bold()); Spacer(); Text("나의 캠퍼스").foregroundStyle(.secondary) }
            ScrollView { VStack(alignment: .leading, spacing: 12) {
                Text("오늘의 수업과 할 일").font(.headline)
                Text("KLAS에 연결하면 과목과 수강 상태가 여기에 표시됩니다.").foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: .infinity)
            Divider()
            Text("주간 시간표").font(.headline)
            HStack { ForEach(["월", "화", "수", "목", "금"], id: \.self) { day in Text(day).frame(maxWidth: .infinity) } }.foregroundStyle(.secondary)
            Text("연결된 시간표가 없습니다").foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 260).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            Divider()
            HStack { Text("메뉴바에서 실행 중").font(.caption).foregroundStyle(.secondary); Spacer(); Button("종료") { NSApp.terminate(nil) } }
        }.padding(20).frame(width: 520, height: 660)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
