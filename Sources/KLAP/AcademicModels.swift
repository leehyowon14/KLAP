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
