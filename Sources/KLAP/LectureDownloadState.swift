import Foundation

struct LectureDownloadProgressData:Decodable {
    let ID:String
    let Stage:String
    let Bytes:Int64
    let TotalBytes:Int64
    let Error:String
    var Path:String? = nil
}
struct LectureDownloadResultData:Decodable {
    let ID:String
    let Path:String
    let Bytes:Int64
    let Skipped:Bool
    let Error:String
}
struct LectureDownloadRow {
    var stage="waiting"
    var bytes:Int64=0
    var total:Int64=0
    var path:String?
    var error:String?
    var finished:Bool {stage == "done" || stage == "skip"}
    var fraction:Double? {total>0 ? min(1,max(0,Double(bytes)/Double(total))) : nil}
    var label:String {
        switch stage {
        case "resolve":return "다운로드 준비 중"
        case "download":return "다운로드 중"
        case "done":return "완료"
        case "skip":return "이미 다운로드됨"
        case "error":return "실패"
        case "cancelled":return "취소됨"
        default:return "대기 중"
        }
    }
}
struct LectureDownloadState {
    var rows:[String:LectureDownloadRow]=[:]
    var running=false
    var cancelling=false
    var failure:String?
    var expected:[String]=[]
    var completed:Int {rows.values.filter(\.finished).count}
    var retryIDs:[String] {expected.filter{rows[$0]?.stage == "error" || rows[$0]?.stage == "cancelled"}}
    mutating func begin(_ ids:[String]) {
        expected=Array(NSOrderedSet(array:ids)) as? [String] ?? []
        rows=Dictionary(uniqueKeysWithValues:expected.map{($0,LectureDownloadRow())})
        running=true;cancelling=false;failure=nil
    }
    mutating func apply(_ progress:LectureDownloadProgressData) {
        guard rows[progress.ID] != nil else{return}
        if let path=progress.Path,!path.isEmpty {rows[progress.ID]?.path=path}
        rows[progress.ID]?.stage=progress.Stage
        rows[progress.ID]?.bytes=max(0,progress.Bytes)
        rows[progress.ID]?.total=max(0,progress.TotalBytes)
        rows[progress.ID]?.error=progress.Error.isEmpty ? nil : progress.Error
    }
    mutating func apply(_ results:[LectureDownloadResultData]) {
        for result in results where rows[result.ID] != nil {
            rows[result.ID]=LectureDownloadRow(stage:result.Error.isEmpty && !result.Path.isEmpty ? (result.Skipped ? "skip" : "done") : "error",bytes:max(0,result.Bytes),total:max(0,result.Bytes),path:result.Path.isEmpty ? nil : result.Path,error:result.Error.isEmpty ? nil : result.Error)
        }
    }
    mutating func finish(error:String?,receivedResult:Bool) {
        if !cancelling {failure=error ?? (receivedResult ? nil : "다운로드 완료 응답을 받지 못했습니다.")}
        for id in expected where (rows[id]?.finished != true || rows[id]?.path == nil) && rows[id]?.stage != "error" {
            rows[id]?.stage=cancelling ? "cancelled" : "error"
            rows[id]?.error=cancelling ? nil : (failure ?? "다운로드 결과를 확인하지 못했습니다.")
        }
        running=false;cancelling=false
    }
}
