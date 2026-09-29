import Foundation

public enum LectureStatus: Equatable {
    case complete, late, missed, pending, unknown
    public static func date(_ raw:String?) -> Date? {
        guard let raw, hasValidCalendarDate(raw) else { return nil }
        let parser=ISO8601DateFormatter()
        if let date=parser.date(from:raw) { return date }
        parser.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return parser.date(from:raw)
    }
    private static func hasValidCalendarDate(_ raw:String) -> Bool {
        let fields=raw.prefix(10).split(separator:"-",omittingEmptySubsequences:false)
        guard fields.count==3,fields[0].count==4,fields[1].count==2,fields[2].count==2,
              fields.allSatisfy({$0.unicodeScalars.allSatisfy{$0.value >= 48 && $0.value <= 57}}),
              let year=Int(fields[0]),let month=Int(fields[1]),let day=Int(fields[2]) else {return false}
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(secondsFromGMT:0)!
        guard let date=calendar.date(from:DateComponents(year:year,month:month,day:day)) else {return false}
        let resolved=calendar.dateComponents([.year,.month,.day],from:date)
        return resolved.year==year && resolved.month==month && resolved.day==day
    }
    public static func resolve(complete:Bool,deadline:Date?,started:Date?,finished:Date?,now:Date) -> LectureStatus {
        guard let deadline else { return complete ? .unknown : .pending }
        if complete {
            if let finished {
                if finished <= deadline { return .complete }
                if let started, started < deadline { return .late }
                return .unknown
            }
            return now <= deadline ? .complete : .unknown
        }
        return now > deadline ? .missed : .pending
    }
    public static func urgency(deadline:Date,now:Date) -> Int {
        let remaining=deadline.timeIntervalSince(now)
        return remaining <= 5*3600 ? 2 : remaining <= 24*3600 ? 1 : 0
    }
}
