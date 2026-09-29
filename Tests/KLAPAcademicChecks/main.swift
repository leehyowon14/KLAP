import Foundation
func date(_ year:Int,_ month:Int,_ day:Int)->Date {AcademicCalendar.calendar.date(from:DateComponents(year:year,month:month,day:day))!}
let leap=AcademicCalendar.days(date(2024,2,12))
precondition(leap.compactMap{$0}.count==29 && leap.count%7==0)
precondition(AcademicCalendar.days(date(2025,2,1)).compactMap{$0}.count==28)
let month=AcademicCalendar.days(date(2026,9,1))
precondition(month.prefix(2).allSatisfy{$0==nil})
let event=AcademicEntry(Month:"9월",Date:"9.28 ~ 10.2",Title:"기간 일정",Note:"",Start:"2026-09-28",End:"2026-10-02")
precondition(event.includes(date(2026,9,28)) && event.includes(date(2026,10,2)))
precondition(!event.includes(date(2026,9,27)) && !event.includes(date(2026,10,3)))
let unknown=AcademicEntry(Month:"9월",Date:"추후",Title:"미정",Note:"",Start:"",End:"")
precondition(!unknown.includes(date(2026,9,1)))
let decoded=try JSONDecoder().decode(AcademicResult.self,from:Data(#"{"Year":"2026","SourceURL":"","Events":null}"#.utf8))
precondition(decoded.Events==nil)
print("Calendar leap year, grid alignment, inclusive range, cross-month and undated checks passed")
func entry(_ start:String,_ end:String)->AcademicEntry {AcademicEntry(Month:"9월",Date:"",Title:start,Note:"",Start:start,End:end)}
let overlapping=[entry("2026-09-03","2026-09-09"),entry("2026-09-04","2026-09-08"),entry("2026-09-04","2026-09-04"),entry("2026-09-04","2026-09-04"),entry("2026-09-10","2026-09-10")]
let weeks=AcademicCalendar.weeks(date(2026,9,1),events:overlapping)
precondition(weeks[0].markers.count==4 && weeks[0].laneCount==4)
precondition(Set(weeks[0].markers.map(\.lane)).count==4)
precondition(weeks[0].markers.filter(\.singleDay).count==2)
let first=weeks[0].markers.first{$0.eventIndex==0}!
let continuation=weeks[1].markers.first{$0.eventIndex==0}!
precondition(first.startsHere && !first.endsHere)
precondition(!continuation.startsHere && continuation.endsHere && first.lane==continuation.lane)
precondition(weeks[1].markers.first{$0.eventIndex==4}?.lane==0)
for week in weeks {
    for left in week.markers {
        for right in week.markers where left.id != right.id && left.lane == right.lane {
            precondition(left.lastColumn<right.firstColumn || right.lastColumn<left.firstColumn)
        }
    }
}
let clipped=AcademicCalendar.weeks(date(2026,9,1),events:[entry("2026-08-28","2026-10-03")])
precondition(clipped.first!.markers.first!.startsHere==false && clipped.last!.markers.first!.endsHere==false)
precondition(AcademicCalendar.weeks(date(2026,9,1),events:[]).allSatisfy{$0.markers.isEmpty})
print("Overlapping bars, multiple single-day dots, week wrapping, lane reuse and month clipping checks passed")
let sameEvent=AcademicEntry(Month:"10월",Date:"다른 표시",Title:event.Title,Note:"변경된 비고",Start:event.Start,End:event.End)
precondition(sameEvent.colorIdentity==event.colorIdentity)
precondition(entry("2026-09-01","2026-09-01").colorIdentity != entry("2026-09-02","2026-09-02").colorIdentity)
print("Calendar event color identity stays stable across display and note changes")
