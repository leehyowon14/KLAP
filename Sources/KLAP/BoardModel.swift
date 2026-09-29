import AppKit
import KLAPCore

extension AppModel {
    func boardReference(kind:String) -> BoardReference? {
        guard let term=snapshot.timetable?.Term,let course=term.subjList?.first(where:{$0.name==selectedCourse}) else {return nil}
        return BoardReference(kind:kind,term:term.value,subject:course.value)
    }
    func boardValue<T:Decodable>(_ command:String,reference:BoardReference,extra:[String:Any]=[:],as type:T.Type) async throws -> T {
        guard !busy else { throw BridgeFailure(message:"다른 작업이 끝난 뒤 다시 시도해 주세요.") }
        var request=reference.request;request["Command"]=command;request.merge(extra){_,new in new}
        var result:T?
        await perform(request) { event in if event.kind=="result" { result=try event.decode(T.self) } }
        guard let result else { throw BridgeFailure(message:error ?? "응답을 받지 못했습니다.") }
        return result
    }
    func attachment(_ file:BoardFile,reference:BoardReference,preview:Bool) async throws -> URL {
        let key=attachments.key(reference,file)
        let url:URL
        if let cached=try attachments.cached(key) { url=cached }
        else {
            let result=try await boardValue("board-download",reference:reference,extra:["FileSN":file.FileSN,"Directory":try attachments.directory],as:BoardDownload.self)
            url=URL(fileURLWithPath:result.Path)
            try attachments.register(url,key:key)
        }
        if preview {
            try attachments.show(url,key:key) { [weak self] in
                guard let self else {return}
                do { let saved=try self.attachments.save(key); NSWorkspace.shared.activateFileViewerSelecting([saved]) }
                catch { let alert=NSAlert(error:error); alert.runModal() }
            }
            return url
        }
        return try attachments.save(key)
    }
}
