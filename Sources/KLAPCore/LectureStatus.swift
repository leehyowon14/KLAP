import Foundation

public enum LectureStatus: Equatable {
    case complete, late, missed, pending, unknown
    public static func date(_ raw:String?) -> Date? {
        guard let raw else { return nil }
        let parser=ISO8601DateFormatter()
        if let date=parser.date(from:raw) { return date }
        parser.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return parser.date(from:raw)
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
