import AppKit
import CoreGraphics
import PDFKit
import KLAPCore

MainActor.assumeIsolated {
    let app=NSApplication.shared
    app.setActivationPolicy(.accessory)
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("klap-preview-check-"+UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let cache=root.appendingPathComponent("cache"), downloads=root.appendingPathComponent("downloads")
    let manager=AttachmentManager(root:cache,downloadsDirectory:downloads)
    @MainActor func makeFile(_ key:String) throws -> Data {
        let bytes=NSMutableData()
        var bounds=CGRect(x:0,y:0,width:1280,height:720)
        let context=CGContext(consumer:CGDataConsumer(data:bytes)!,mediaBox:&bounds,nil)!
        for _ in 0..<3 {context.beginPDFPage(nil);context.setFillColor(CGColor(gray:0.5,alpha:1));context.fill(CGRect(x:20,y:650,width:80,height:50));context.endPDFPage()}
        context.closePDF()
        let data=bytes as Data
        try manager.register(data,name:"sample.pdf",key:key)
        precondition(!FileManager.default.fileExists(atPath:cache.path))
        return data
    }
    func drain() { RunLoop.main.run(until:Date().addingTimeInterval(0.3)) }
    for i in 0..<3 {
        autoreleasepool {
            let key="download-\(i)"
            let source=try! makeFile(key)
            let download = { let saved=try! manager.save(key); precondition(FileManager.default.fileExists(atPath:saved.path));precondition(try! Data(contentsOf:saved)==source) }
            try! manager.show(key:key,download:download)
            drain()
            let window=app.windows.first { $0.isVisible && $0.toolbar?.identifier == "KLAP.preview" }!
            precondition(window.subtitle == "1 / 3페이지")
            let pdf=window.contentView!.subviews.first as! PDFView
            precondition(pdf.displayMode == .singlePageContinuous && pdf.displayDirection == .vertical)
            precondition(pdf.document?.pageCount == 3)
            let first=pdf.document!.page(at:0)!
            let top=pdf.convert(NSPoint(x:640,y:720),from:first)
            precondition(top.y <= pdf.bounds.maxY+2 && top.y >= pdf.bounds.minY,"First page top must be visible")
            let zoom=window.toolbar!.items.first{$0.itemIdentifier.rawValue=="zoomIn"}!
            let previousScale=pdf.scaleFactor
            precondition(app.sendAction(zoom.action!,to:zoom.target,from:zoom))
            precondition(pdf.scaleFactor>previousScale)
            let fit=window.toolbar!.items.first{$0.itemIdentifier.rawValue=="fit"}!
            precondition(app.sendAction(fit.action!,to:fit.target,from:fit))
            precondition(pdf.autoScales)
            pdf.goToLastPage(nil)
            precondition(pdf.currentPage == pdf.document?.page(at:2))
            if i == 0, let path=ProcessInfo.processInfo.environment["KLAP_PREVIEW_SCREENSHOT"], let view=window.contentView?.superview,
               let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                view.cacheDisplay(in:view.bounds,to:bitmap)
                try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
            }
            let item=window.toolbar!.items.first { $0.itemIdentifier.rawValue == "KLAP.preview.download" }!
            precondition(app.sendAction(item.action!,to:item.target,from:item))
            drain()
        }
        drain()
    }
    autoreleasepool {
        let file=try! makeFile("close")
        try! manager.show(key:"close",download:{})
        drain();manager.closePreview();drain();manager.closePreview()
        precondition(manager.cached("close")?.data==file)
        try! manager.show(key:"close",download:{})
        _ = try! makeFile("replace")
        try! manager.show(key:"replace",download:{})
        drain();manager.closePreview();drain()
    }
    drain()
    let files=try! FileManager.default.contentsOfDirectory(atPath:downloads.path)
    precondition(files.count==3)
    print("Preview download x3, manual close, reopen and replacement checks passed")
}
