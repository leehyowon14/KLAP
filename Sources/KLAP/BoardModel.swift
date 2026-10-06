import AppKit
import KLAPCore

struct BoardEntry {
    let reference:BoardReference
    let title:String
}

struct BoardPresentation: Identifiable {
    let reference: BoardReference
    let title: String
    var entries:[BoardEntry]=[]
    var id: BoardReference { reference }
    func adjacent(_ offset:Int)->BoardPresentation? {
        guard let index=entries.firstIndex(where:{$0.reference==reference}),entries.indices.contains(index+offset) else {return nil}
        let entry=entries[index+offset]
        guard entry.reference.Kind==reference.Kind,entry.reference.TermValue==reference.TermValue,entry.reference.SubjectID==reference.SubjectID else {return nil}
        return BoardPresentation(reference:entry.reference,title:entry.title,entries:entries)
    }
}

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
    func attachment(_ file:BoardFile,reference:BoardReference,preview:Bool) async throws -> URL? {
        let key=attachments.key(reference,file)
        if attachments.cached(key) == nil {
            if !preview {
                let directory=FileManager.default.temporaryDirectory.appendingPathComponent("KLAP-downloads")
                let result=try await boardValue("board-download",reference:reference,extra:["FileSN":file.FileSN,"Directory":directory.path],as:BoardDownload.self)
                return try attachments.saveDownloadedFile(URL(fileURLWithPath:result.Path))
            }
            guard !busy else {throw BridgeFailure(message:"다른 작업이 끝난 뒤 다시 시도해 주세요.")}
            var request=reference.request;request["Command"]="board-read";request["FileSN"]=file.FileSN
            var bytes=Data();var expected:Int?
            await perform(request) { event in
                if event.kind=="chunk" {
                    let chunk=try event.decode(Data.self)
                    guard bytes.count+chunk.count<=128*1024*1024 else {throw BridgeFailure(message:"128MB보다 큰 파일은 다운로드 후 열어 주세요.")}
                    bytes.append(chunk)
                } else if event.kind=="result" { expected=try event.decode([String:Int].self)["Bytes"] }
            }
            guard error == nil, expected == bytes.count else {throw BridgeFailure(message:error ?? "파일 수신이 완료되지 않았습니다.")}
            try attachments.register(bytes,name:file.Name,key:key)
        }
        if preview {
            try attachments.show(key:key) { [weak self] in
                guard let self else {return}
                do {let saved=try self.attachments.save(key);NSWorkspace.shared.activateFileViewerSelecting([saved])}
                catch {NSAlert(error:error).runModal()}
            }
            return nil
        }
        return try attachments.save(key)
    }
}
