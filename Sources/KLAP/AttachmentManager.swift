import AppKit
import Quartz
import UniformTypeIdentifiers
import KLAPCore

@MainActor final class AttachmentManager: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private var store: PreviewFileStore?
    private var startupError: Error?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var previewWindow: NSWindow?
    private var previewView: QLPreviewView?
    private var previewKey: String?
    private var previewDownload: (() -> Void)?
    private let downloadItemID = NSToolbarItem.Identifier("KLAP.preview.download")
    private let downloadsDirectory: URL?
    init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("KLAP-previews",isDirectory:true), downloadsDirectory: URL? = nil) {
        self.downloadsDirectory = downloadsDirectory
        super.init()
        do { store=try PreviewFileStore(root:root) }
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
        let directory=try downloadsDirectory ?? FileManager.default.url(for:.downloadsDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        let saved=try storage().moveToDownloads(key,directory:directory)
        scheduleCleanup()
        return saved
    }
    func show(_ url:URL,key:String,download:@escaping () -> Void) throws {
        closePreview()
        try storage().opened(key)
        previewKey=key
        let window=NSPanel(contentRect:NSRect(x:0,y:0,width:760,height:720),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title=url.lastPathComponent
        window.isReleasedWhenClosed=false
        window.delegate=self
        window.minSize=NSSize(width:520,height:420)
        window.titlebarAppearsTransparent=true
        window.toolbarStyle = .unified
        window.backgroundColor = .windowBackgroundColor
        let size=(try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize).map { ByteCountFormatter.string(fromByteCount:Int64($0),countStyle:.file) }
        window.subtitle=[url.pathExtension.uppercased(),size].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")
        let toolbar=NSToolbar(identifier:"KLAP.preview")
        toolbar.delegate=self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization=false
        window.titlebarSeparatorStyle = .none
        window.toolbar=toolbar
        previewDownload=download
        let view=QLPreviewView(frame:window.contentLayoutRect,style:.compact)!
        // This controller closes the view exactly once in windowWillClose.
        view.shouldCloseWithWindow=false
        view.autostarts=false
        view.previewItem=url as NSURL
        window.contentView=view
        previewView=view
        if let screen=NSScreen.main {
            window.setContentSize(NSSize(width:min(760,screen.visibleFrame.width-80),height:min(720,screen.visibleFrame.height-100)))
        }
        previewWindow=window
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        scheduleCleanup()
    }
    func closePreview() { previewWindow?.close() }
    func windowWillClose(_ notification:Notification) {
        previewView?.close()
        previewView=nil
        if let key=previewKey { do { try storage().closed(key) } catch { NSLog("KLAP preview expiry persistence failed") } }
        previewWindow=nil;previewKey=nil;previewDownload=nil;scheduleCleanup()
    }
    func toolbarAllowedItemIdentifiers(_ toolbar:NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace,downloadItemID] }
    func toolbarDefaultItemIdentifiers(_ toolbar:NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace,downloadItemID] }
    func toolbar(_ toolbar:NSToolbar,itemForItemIdentifier identifier:NSToolbarItem.Identifier,willBeInsertedIntoToolbar flag:Bool) -> NSToolbarItem? {
        guard identifier == downloadItemID else { return nil }
        let item=NSToolbarItem(itemIdentifier:identifier)
        item.label="다운로드"
        item.toolTip="다운로드 폴더에 저장"
        item.image=NSImage(systemSymbolName:"arrow.down.to.line",accessibilityDescription:"다운로드")
        item.target=self;item.action=#selector(downloadPreview)
        return item
    }
    @objc private func downloadPreview() {
        let action=previewDownload
        action?()
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