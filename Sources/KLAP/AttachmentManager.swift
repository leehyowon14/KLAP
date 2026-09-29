import AppKit
import PDFKit
import UniformTypeIdentifiers
import KLAPCore

@MainActor final class PreviewWindow: NSWindow {
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        let modifiers=event.modifierFlags.intersection([.command,.control,.option,.shift])
        if ((event.charactersIgnoringModifiers?.lowercased()=="w" || event.keyCode==13) && modifiers == .command) || (event.keyCode==53 && modifiers.isEmpty) {
            performClose(nil);return true
        }
        return super.performKeyEquivalent(with:event)
    }
    override func cancelOperation(_ sender:Any?) { performClose(sender) }
}

@MainActor final class AttachmentManager: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let store=MemoryPreviewStore()
    private var timer:Timer?
    private var pageObserver:NSObjectProtocol?
    private var shortcutMonitor:Any?
    private var previousMenu:NSMenu?
    private var previousActivationPolicy:NSApplication.ActivationPolicy?
    private var previewWindow:NSWindow?
    private var pdfView:PDFView?
    private var previewKey:String?
    private var previewDownload:(()->Void)?
    private let downloadItemID=NSToolbarItem.Identifier("KLAP.preview.download")
    private let downloadsDirectory:URL?
    init(root:URL=FileManager.default.temporaryDirectory.appendingPathComponent("KLAP-previews"),downloadsDirectory:URL?=nil) {
        self.downloadsDirectory=downloadsDirectory
        super.init()
        // Migration: previews are no longer persisted.
        if FileManager.default.fileExists(atPath:root.path) {try? FileManager.default.removeItem(at:root)}
    }
    func key(_ reference:BoardReference,_ file:BoardFile) -> String {
        let values=[reference.Kind,reference.TermValue,reference.SubjectID,reference.BoardNo,reference.MasterNo,file.FileSN,file.Name,String(file.Size)]
        return (try? String(data:JSONEncoder().encode(values),encoding:.utf8)) ?? UUID().uuidString
    }
    func cached(_ key:String)->MemoryPreviewStore.Item? {store.cached(key)}
    func register(_ data:Data,name:String,key:String)throws {try store.register(data,name:name,key:key);scheduleCleanup()}
    private func downloads()throws->URL {try downloadsDirectory ?? FileManager.default.url(for:.downloadsDirectory,in:.userDomainMask,appropriateFor:nil,create:true)}
    func save(_ key:String)throws->URL {
        let saved=try store.save(key,to:downloads())
        if previewKey==key {closePreview()}
        scheduleCleanup()
        return saved
    }
    func saveDownloadedFile(_ url:URL)throws->URL {
        let destination=try downloads()
        try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
        var index=0
        while true {
            let name=index==0 ? url.lastPathComponent : "\(url.deletingPathExtension().lastPathComponent) (\(index)).\(url.pathExtension)"
            let target=destination.appendingPathComponent(name)
            do {try FileManager.default.moveItem(at:url,to:target);return target}
            catch let error as CocoaError where error.code == .fileWriteFileExists {index+=1}
        }
    }
    func show(key:String,download:@escaping ()->Void)throws {
        guard let item=store.cached(key) else {throw CocoaError(.fileNoSuchFile)}
        closePreview()
        let window=PreviewWindow(contentRect:NSRect(x:0,y:0,width:900,height:720),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title=item.name
        window.isReleasedWhenClosed=false
        window.delegate=self
        window.minSize=NSSize(width:520,height:420)
        window.toolbarStyle = .unified
        let toolbar=NSToolbar(identifier:"KLAP.preview")
        toolbar.delegate=self;toolbar.displayMode = .iconOnly
        window.toolbar=toolbar
        if let screen=NSScreen.main {window.setContentSize(NSSize(width:min(900,screen.visibleFrame.width-80),height:min(720,screen.visibleFrame.height-100)))}
        let host=NSView()
        window.contentView=host
        let content:NSView
        if URL(fileURLWithPath:item.name).pathExtension.lowercased()=="pdf",let document=PDFDocument(data:item.data) {
            let view=PDFView()
            view.displayMode = .singlePageContinuous
            view.displayDirection = .vertical
            view.displaysPageBreaks=true
            view.document=document
            content=view;pdfView=view
        } else if let image=NSImage(data:item.data) {
            let view=NSImageView()
            view.image=image;view.imageScaling = .scaleProportionallyUpOrDown
            content=view
        } else if let text=String(data:item.data,encoding:.utf8) ?? String(data:item.data,encoding:.utf16) {
            let scroll=NSScrollView();scroll.hasVerticalScroller=true
            let view=NSTextView();view.string=text;view.isEditable=false
            view.isVerticallyResizable=true;view.autoresizingMask=[.width]
            view.textContainer?.widthTracksTextView=true
            scroll.documentView=view;content=scroll
        } else {throw CocoaError(.fileReadCorruptFile)}
        host.addSubview(content);content.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo:host.leadingAnchor),
            content.trailingAnchor.constraint(equalTo:host.trailingAnchor),
            content.topAnchor.constraint(equalTo:(window.contentLayoutGuide as! NSLayoutGuide).topAnchor),
            content.bottomAnchor.constraint(equalTo:host.bottomAnchor)
        ])
        previewWindow=window;previewKey=key;previewDownload=download;store.opened(key)
        previousMenu=NSApp.mainMenu
        ApplicationMenu.install(application:NSApp,preview:window)
        previousActivationPolicy=NSApp.activationPolicy()
        if let url=Bundle.main.url(forResource:"KLAP",withExtension:"icns"),let icon=NSImage(contentsOf:url) {NSApp.applicationIconImage=icon}
        NSApp.setActivationPolicy(.regular)
        window.center();window.makeKeyAndOrderFront(nil)
        shortcutMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak window] event in
            guard let window, event.window === window else {return event}
            let modifiers=event.modifierFlags.intersection([.command,.control,.option,.shift])
            if modifiers == .command && event.keyCode == 12 {window.performClose(nil);return nil}
            if (modifiers == .command && event.keyCode == 13) || (modifiers.isEmpty && event.keyCode == 53) {
                window.performClose(nil);return nil
            }
            return event
        }
        host.layoutSubtreeIfNeeded()
        if let view=pdfView {
            view.autoScales=true
            view.layoutDocumentView()
            if let first=view.document?.page(at:0) {
                let bounds=first.bounds(for:view.displayBox)
                view.go(to:PDFDestination(page:first,at:NSPoint(x:bounds.minX,y:bounds.maxY)))
            }
            pageObserver=NotificationCenter.default.addObserver(forName:.PDFViewPageChanged,object:view,queue:.main) {[weak self] _ in
                MainActor.assumeIsolated {self?.updatePage()}
            }
            updatePage()
        } else {window.subtitle=ByteCountFormatter.string(fromByteCount:Int64(item.data.count),countStyle:.file)}
        NSApp.activate(ignoringOtherApps:true);scheduleCleanup()
    }
    private func updatePage() {
        guard let view=pdfView,let document=view.document,let page=view.currentPage else {return}
        previewWindow?.subtitle="\(document.index(for:page)+1) / \(document.pageCount)페이지"
    }
    func closePreview(){previewWindow?.close()}
    func windowWillClose(_ notification:Notification) {
        guard let closing=notification.object as? NSWindow, closing === previewWindow else {return}
        if let policy=previousActivationPolicy {NSApp.setActivationPolicy(policy)}
        previousActivationPolicy=nil
        NSApp.mainMenu=previousMenu;previousMenu=nil
        if let monitor=shortcutMonitor {NSEvent.removeMonitor(monitor);shortcutMonitor=nil}
        if let observer=pageObserver {NotificationCenter.default.removeObserver(observer)}
        pageObserver=nil;pdfView=nil
        if let key=previewKey {store.closed(key)}
        previewWindow=nil;previewKey=nil;previewDownload=nil;scheduleCleanup()
    }
    func toolbarAllowedItemIdentifiers(_ toolbar:NSToolbar)->[NSToolbarItem.Identifier] {
        [.flexibleSpace,.init("zoomOut"),.init("actualSize"),.init("zoomIn"),downloadItemID]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar:NSToolbar)->[NSToolbarItem.Identifier] {toolbarAllowedItemIdentifiers(toolbar)}
    func toolbar(_ toolbar:NSToolbar,itemForItemIdentifier id:NSToolbarItem.Identifier,willBeInsertedIntoToolbar flag:Bool)->NSToolbarItem? {
        let item=NSToolbarItem(itemIdentifier:id)
        let config:(String,String,Selector)
        switch id.rawValue {
        case "zoomOut":config=("축소","minus.magnifyingglass",#selector(zoomOut))
        case "zoomIn":config=("확대","plus.magnifyingglass",#selector(zoomIn))
        case "actualSize":config=("실제 크기 (100%)","1.magnifyingglass",#selector(actualSize))
        case downloadItemID.rawValue:config=("다운로드","arrow.down.to.line",#selector(downloadPreview))
        default:return nil
        }
        item.label=config.0;item.toolTip=config.0;item.image=NSImage(systemSymbolName:config.1,accessibilityDescription:config.0)
        item.target=self;item.action=config.2
        return item
    }
    @objc private func zoomOut(){pdfView?.autoScales=false;pdfView?.zoomOut(nil)}
    @objc private func zoomIn(){pdfView?.autoScales=false;pdfView?.zoomIn(nil)}
    @objc private func actualSize(){pdfView?.autoScales=false;pdfView?.scaleFactor=1}
    @objc private func downloadPreview(){let action=previewDownload;action?()}
    private func scheduleCleanup() {
        timer?.invalidate()
        guard let next=store.nextExpiration else {return}
        timer=Timer.scheduledTimer(withTimeInterval:max(1,next.timeIntervalSinceNow),repeats:false) {[weak self] _ in
            MainActor.assumeIsolated {self?.store.cleanup();self?.scheduleCleanup()}
        }
    }
    static func canPreview(_ name:String)->Bool {
        guard let type=UTType(filenameExtension:URL(fileURLWithPath:name).pathExtension) else {return false}
        return type.conforms(to:.pdf) || type.conforms(to:.image) || type.conforms(to:.plainText)
    }
}
