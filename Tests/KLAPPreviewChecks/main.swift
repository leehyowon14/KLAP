import AppKit
import CoreGraphics
import KLAPCore

MainActor.assumeIsolated {
    let app=NSApplication.shared
    app.setActivationPolicy(.accessory)
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("klap-preview-check-"+UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let cache=root.appendingPathComponent("cache"), downloads=root.appendingPathComponent("downloads")
    let manager=AttachmentManager(root:cache,downloadsDirectory:downloads)
    @MainActor func makeFile(_ key:String) throws -> URL {
        let folder=cache.appendingPathComponent("attachment-"+key)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let file=folder.appendingPathComponent("sample.pdf")
        var bounds=CGRect(x:0,y:0,width:240,height:320)
        let context=CGContext(file as CFURL,mediaBox:&bounds,nil)!
        context.beginPDFPage(nil);context.setFillColor(CGColor(gray:0.5,alpha:1));context.fill(CGRect(x:20,y:20,width:80,height:80));context.endPDFPage();context.closePDF()
        try manager.register(file,key:key)
        return file
    }
    func drain() { RunLoop.main.run(until:Date().addingTimeInterval(0.3)) }
    for i in 0..<3 {
        autoreleasepool {
            let key="download-\(i)"
            let source=try! makeFile(key)
            let download = { let saved=try! manager.save(key); precondition(FileManager.default.fileExists(atPath:saved.path));precondition(!FileManager.default.fileExists(atPath:source.path)) }
            try! manager.show(source,key:key,download:download)
            drain();download();drain()
        }
        drain()
    }
    autoreleasepool {
        let file=try! makeFile("close")
        try! manager.show(file,key:"close",download:{})
        drain();manager.closePreview();drain();manager.closePreview()
        precondition(FileManager.default.fileExists(atPath:file.path))
        try! manager.show(file,key:"close",download:{})
        let next=try! makeFile("replace")
        try! manager.show(next,key:"replace",download:{})
        drain();manager.closePreview();drain()
    }
    drain()
    let files=try! FileManager.default.contentsOfDirectory(atPath:downloads.path)
    precondition(files.count==3)
    print("Preview download x3, manual close, reopen and replacement checks passed")
}
