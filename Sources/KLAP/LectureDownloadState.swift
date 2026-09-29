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
    var speed:Double=0
    var sampleTime:Date?
    var sampleBytes:Int64=0
    var finished:Bool {stage == "done" || stage == "skip"}
    var fraction:Double? {total>0 ? min(1,max(0,Double(bytes)/Double(total))) : nil}
    var label:String {
        switch stage {
        case "resolve":return "다운로드 준비 중"
        case "download":return "다운로드 중"
        case "paused":return "속도 조절을 위해 일시정지"
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
    var transcripts:[String:LectureTranscriptProgressData]=[:]
    var running=false
    var cancelling=false
    var failure:String?
    var expected:[String]=[]
    var fraction:Double {expected.isEmpty ? 0 : expected.reduce(0.0){$0 + (rows[$1]?.finished == true ? 1 : rows[$1]?.fraction ?? 0)} / Double(expected.count)}
    var active:Int {rows.values.filter{$0.stage == "download"}.count}
    var paused:Int {rows.values.filter{$0.stage == "paused"}.count}
    var speedLabel:String {String(format:"%.1f MB/s",rows.values.filter{$0.stage == "download"}.reduce(0){$0+$1.speed}/1_000_000)}
    var completed:Int {rows.values.filter(\.finished).count}
    var retryIDs:[String] {expected.filter{rows[$0]?.stage == "error" || rows[$0]?.stage == "cancelled"}}
    mutating func apply(_ value:LectureTranscriptProgressData) {
        guard rows[value.ID] != nil else{return}
        transcripts[value.ID]=cancelling && value.Stage == "transcript-error" ? LectureTranscriptProgressData(ID:value.ID,Stage:"cancelled",Path:value.Path,Error:"") : value
    }
    mutating func begin(_ ids:[String]) {
        expected=Array(NSOrderedSet(array:ids)) as? [String] ?? []
        rows=Dictionary(uniqueKeysWithValues:expected.map{($0,LectureDownloadRow())})
        running=true;cancelling=false;failure=nil;transcripts=[:]
    }
    mutating func apply(_ progress:LectureDownloadProgressData) {
        guard rows[progress.ID] != nil else{return}
        if let path=progress.Path,!path.isEmpty {rows[progress.ID]?.path=path}
        let now=Date()
        if var row=rows[progress.ID] {
            if progress.Stage == "download",row.stage == "download",let last=row.sampleTime {
                let elapsed=now.timeIntervalSince(last)
                if elapsed>=0.5 {row.speed=Double(max(0,progress.Bytes-row.sampleBytes))/elapsed;row.sampleTime=now;row.sampleBytes=progress.Bytes}
            } else {row.speed=0;row.sampleTime=now;row.sampleBytes=progress.Bytes}
            rows[progress.ID]=row
        }
        rows[progress.ID]?.stage=cancelling && progress.Stage == "error" ? "cancelled" : progress.Stage
        rows[progress.ID]?.bytes=max(0,progress.Bytes)
        rows[progress.ID]?.total=max(0,progress.TotalBytes)
        rows[progress.ID]?.error=cancelling || progress.Error.isEmpty ? nil : progress.Error
    }
    mutating func apply(_ results:[LectureDownloadResultData]) {
        for result in results where rows[result.ID] != nil {
            if cancelling && !result.Error.isEmpty {
                if rows[result.ID]?.finished != true && rows[result.ID]?.stage != "error" {rows[result.ID]?.stage="cancelled";rows[result.ID]?.error=nil}
                continue
            }
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

struct LectureTranscriptProgressData:Decodable {
    let ID:String
    let Stage:String
    let Path:String
    let Error:String
}
