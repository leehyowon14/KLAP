import AppKit
import SwiftUI
import Quartz
import UniformTypeIdentifiers
import KLAPCore

@MainActor final class AttachmentManager: NSObject, NSWindowDelegate {
    private var store: PreviewFileStore?
    private var startupError: Error?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var previewWindow: NSWindow?
    private var previewKey: String?
    override init() {
        super.init()
        do { store=try PreviewFileStore(root:FileManager.default.temporaryDirectory.appendingPathComponent("KLAP-previews",isDirectory:true)) }
        catch { startupError=error }
        scheduleCleanup()
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePreview() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cleanExpired() }
        })
    }
    private func storage() throws -> PreviewFileStore {
        guard let store else { throw startupError ?? CocoaError(.fileWriteUnknown) }; return store
    }
    var directory: String { get throws { try storage().root.path } }
    func key(_ reference:BoardReference,_ file:BoardFile) -> String {
        let values=[reference.Kind,reference.TermValue,reference.SubjectID,reference.BoardNo,reference.MasterNo,file.FileSN,file.Name,String(file.Size)]
        return (try? String(data:JSONEncoder().encode(values),encoding:.utf8)) ?? UUID().uuidString
    }
    func cached(_ key:String) throws -> URL? { try storage().cached(key) }
    func register(_ url:URL,key:String) throws { try storage().register(url,key:key); scheduleCleanup() }
    func save(_ key:String) throws -> URL {
        if previewKey == key { closePreview() }
        let directory=try FileManager.default.url(for:.downloadsDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        let saved=try storage().moveToDownloads(key,directory:directory)
        scheduleCleanup()
        return saved
    }
    func show(_ url:URL,key:String,download:@escaping () -> Void) throws {
        closePreview()
        try storage().opened(key)
        previewKey=key
        let window=NSPanel(contentRect:NSRect(x:0,y:0,width:720,height:620),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title=url.lastPathComponent
        window.isReleasedWhenClosed=false
        window.delegate=self
        window.contentView=NSHostingView(rootView:VStack(spacing:0) {
            HStack { Text(url.lastPathComponent).lineLimit(1); Spacer(); Button("다운로드",action:download) }.padding(12)
            Divider()
            QuickLookFile(url:url)
        })
        previewWindow=window
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        scheduleCleanup()
    }
    func closePreview() { previewWindow?.close() }
    func windowWillClose(_ notification:Notification) {
        if let key=previewKey { do { try storage().closed(key) } catch { NSLog("KLAP preview expiry persistence failed") } }
        previewWindow=nil;previewKey=nil;scheduleCleanup()
    }
    private func cleanExpired() { do { try store?.cleanup() } catch { NSLog("KLAP preview cleanup failed") }; scheduleCleanup() }
    private func scheduleCleanup() {
        timer?.invalidate()
        guard let next=store?.nextExpiration else { return }
        timer=Timer.scheduledTimer(withTimeInterval:max(1,next.timeIntervalSinceNow),repeats:false) { [weak self] _ in
            MainActor.assumeIsolated { self?.cleanExpired() }
        }
    }
    static func canPreview(_ name:String) -> Bool {
        let ext=URL(fileURLWithPath:name).pathExtension.lowercased()
        guard let type=UTType(filenameExtension:ext) else { return false }
        return type.conforms(to:.pdf) || type.conforms(to:.image) || type.conforms(to:.text) || type.conforms(to:.movie) || type.conforms(to:.audio) || ["doc","docx","xls","xlsx","ppt","pptx","pages","numbers","key"].contains(ext)
    }
}
private struct QuickLookFile: NSViewRepresentable {
    let url:URL
    func makeNSView(context:Context) -> QLPreviewView {
        let view=QLPreviewView(frame:.zero,style:.normal)!
        view.previewItem=url as NSURL
        view.autostarts=false
        return view
    }
    func updateNSView(_ view:QLPreviewView,context:Context) { }
    static func dismantleNSView(_ view:QLPreviewView,coordinator:()) { view.close() }
}
