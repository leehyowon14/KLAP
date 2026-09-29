import Foundation

struct AcademicResult: Decodable {
    let Year: String
    let SourceURL: String
    let Events: [AcademicEntry]?
}
struct AcademicEntry: Decodable {
    let Month: String
    let Date: String
    let Title: String
    let Note: String
    let Start:String?
    let End:String?
}

enum AcademicCalendar {
    static var calendar:Calendar {
        var value=Calendar(identifier:.gregorian)
        value.timeZone=TimeZone(identifier:"Asia/Seoul")!
        value.locale=Locale(identifier:"ko_KR")
        return value
    }
    static func monthStart(_ date:Date)->Date {calendar.date(from:calendar.dateComponents([.year,.month],from:date))!}
    static func days(_ month:Date)->[Date?] {
        let start=monthStart(month)
        let prefix=calendar.component(.weekday,from:start)-1
        let count=calendar.range(of:.day,in:.month,for:start)!.count
        var result:[Date?]=Array(repeating:nil,count:prefix)
        result += (0..<count).map{calendar.date(byAdding:.day,value:$0,to:start)}
        result += Array(repeating:nil,count:(7-result.count%7)%7)
        return result
    }
    static func key(_ date:Date)->String {
        let components=calendar.dateComponents([.year,.month,.day],from:date)
        return String(format:"%04d-%02d-%02d",components.year!,components.month!,components.day!)
    }
}
extension AcademicEntry {
    func includes(_ date:Date)->Bool {
        guard let Start,let End,!Start.isEmpty,!End.isEmpty else{return false}
        let key=AcademicCalendar.key(date)
        return Start<=key && key<=End
    }
}

struct AcademicMarker:Identifiable {
    let eventIndex:Int
    let lane:Int
    let firstColumn:Int
    let lastColumn:Int
    let singleDay:Bool
    let startsHere:Bool
    let endsHere:Bool
    var id:Int {eventIndex}
}
struct AcademicWeek {
    let dates:[Date?]
    let markers:[AcademicMarker]
    var laneCount:Int {(markers.map(\.lane).max() ?? -1)+1}
}
extension AcademicCalendar {
    static func weeks(_ month:Date,events:[AcademicEntry])->[AcademicWeek] {
        let cells=days(month)
        // Assign lanes across the entire month so a wrapped event keeps its row.
        let ranges=events.enumerated().compactMap { index,event -> (index:Int,first:Int,last:Int)? in
            let covered=cells.indices.filter { offset in cells[offset].map{event.includes($0)} ?? false }
            guard let first=covered.first,let last=covered.last else{return nil}
            return (index,first,last)
        }.sorted {
            if $0.first != $1.first {return $0.first<$1.first}
            if $0.last != $1.last {return $0.last>$1.last}
            return $0.index<$1.index
        }
        var laneEnds:[Int]=[]
        var assigned:[(index:Int,first:Int,last:Int,lane:Int)]=[]
        for range in ranges {
            let lane=laneEnds.firstIndex(where:{$0<range.first}) ?? laneEnds.count
            if lane == laneEnds.count {laneEnds.append(range.last)} else {laneEnds[lane]=range.last}
            assigned.append((range.index,range.first,range.last,lane))
        }
        return stride(from:0,to:cells.count,by:7).map { offset in
            let markers=assigned.compactMap { range -> AcademicMarker? in
                let first=max(offset,range.first),last=min(offset+6,range.last)
                guard first<=last,let firstDate=cells[first],let lastDate=cells[last] else{return nil}
                let event=events[range.index]
                return AcademicMarker(eventIndex:range.index,lane:range.lane,firstColumn:first-offset,lastColumn:last-offset,
                    singleDay:event.Start == event.End,startsHere:event.Start == key(firstDate),endsHere:event.End == key(lastDate))
            }
            return AcademicWeek(dates:Array(cells[offset..<offset+7]),markers:markers)
        }
    }
}
