import Foundation

public enum TimetableClock {
    public static func minutes(period: Int, span: Int) -> (start: Int, end: Int)? {
        let singles = [(480,645),(540,615),(630,705),(720,795),(810,885),(900,975),(990,1065),(1080,1125),(1130,1175),(1180,1225),(1230,1275),(1280,1325)]
        guard singles.indices.contains(period), span >= 1, span <= 12 else { return nil }
        let overrides: [String: (Int, Int)] = ["0:2":(480,590),"1:2":(540,650),"3:2":(720,830),"5:2":(900,1010),"0:3":(480,645),"6:3":(990,1155),"0:4":(480,710),"5:4":(900,1130)]
        if let value = overrides["\(period):\(span)"] { return value }
        guard singles.indices.contains(period + span - 1) else { return nil }
        return (singles[period].0, singles[period + span - 1].1)
    }
}

public struct TimetablePlacement {
    public let index: Int
    public let day: Int
    public let start: Int
    public let end: Int
    public let lane: Int
    public let laneCount: Int
}
public extension TimetableClock {
    static func placements(_ entries: [TimetableEntry], byPeriod:Bool = false) -> [TimetablePlacement] {
        (1...7).flatMap { day -> [TimetablePlacement] in
            let sorted = entries.enumerated().compactMap { index, entry -> (Int,Int,Int)? in
                guard !entry.Online, entry.Weekday == day, let range=minutes(period:entry.Period,span:max(1,entry.Span)) else {return nil}
                return byPeriod ? (index,entry.Period,min(12,entry.Period+max(1,entry.Span))) : (index,range.start,range.end)
            }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }
            var ends: [Int] = []
            var slots: [(Int,Int,Int,Int)] = []
            for (index,start,end) in sorted {
                let lane=ends.firstIndex(where:{$0 <= start}) ?? ends.count
                if lane == ends.count {ends.append(end)} else {ends[lane]=end}
                slots.append((index,start,end,lane))
            }
            return slots.map { TimetablePlacement(index:$0.0,day:day,start:$0.1,end:$0.2,lane:$0.3,laneCount:ends.count) }
        }
    }
}
