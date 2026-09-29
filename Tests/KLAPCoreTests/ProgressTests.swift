import KLAPCore
import Foundation
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
expect(StudyProgress(percent: -2, current: -1, total: -1) == StudyProgress(percent: 0, current: 0, total: 0), "Negative values")
expect(StudyProgress(percent: 150, current: 9, total: 3).fraction == 1, "Upper bound")
expect(StudyProgress(percent: .nan, current: 1, total: 3).fraction == 0, "NaN")
expect(StudyProgress(percent: .infinity, current: 1, total: 3).fraction == 0, "Infinity")
expect(StudyProgress(percent: 35, current: 2, total: 5).label == "2/5", "Queue position")
expect(StudyProgress(percent: 0, current: 1, total: 0).label == "", "Empty queue")
expect(StudyProgress(percent: 0, current: 8, total: 5).label == "5/5", "Queue clamp")
print("7 progress checks passed")
expect(TimetableClock.minutes(period: -1, span: 1) == nil, "Negative period")
expect(TimetableClock.minutes(period: 1, span: 0) == nil, "Invalid span")
expect(TimetableClock.minutes(period: 11, span: 2) == nil, "Overflow period")
expect(TimetableClock.minutes(period: 0, span: 2)?.end == 590, "Special consecutive class")
expect(TimetableClock.minutes(period: 6, span: 3)?.end == 1155, "Evening consecutive class")
expect(TimetableClock.minutes(period: 11, span: 1)?.end == 1325, "Night class")
expect(DestinationPolicy.uniqueNames(["A","A","B"," "]) == ["B"], "Ambiguous destinations")
expect(DestinationPolicy.uniqueNames([]).isEmpty, "Empty destinations")
expect(DestinationPolicy.availableName("KLAP",existing:["KLAP","KLAP (2)"]) == "KLAP (3)", "New destination collisions")
expect(DestinationPolicy.availableName("KLAP",existing:[]) == "KLAP", "First destination")
print("10 timetable and destination checks passed")

func makeEntry(_ period:Int, _ span:Int=1, day:Int=1, online:Bool=false) throws -> TimetableEntry {
    let data=try JSONSerialization.data(withJSONObject:["SubjectID":"course", "SubjectName":"과목", "Weekday":day, "Period":period, "Span":span, "Room":"101", "Online":online])
    return try JSONDecoder().decode(TimetableEntry.self,from:data)
}
let layout=TimetableClock.placements(try [makeEntry(0),makeEntry(1),makeEntry(2)])
expect(layout.map(\.lane) == [0,1,1], "Overlapping intervals reuse only free lanes")
expect(layout.allSatisfy{$0.laneCount == 2}, "Consistent overlapping lane widths")
let excluded = try [makeEntry(1,day:0),makeEntry(2,online:true)]
expect(TimetableClock.placements(excluded).isEmpty,"Unknown and online classes excluded from grid")
let empty=try JSONDecoder().decode(Snapshot.self,from:Data("{\"timetable\":null,\"lectures\":null,\"errors\":[]}".utf8))
expect(empty.lectures == nil && empty.errors.isEmpty,"Nullable CLI collections")
print("4 layout and decoding checks passed")
