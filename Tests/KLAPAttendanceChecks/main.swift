import Foundation

func decode<T:Decodable>(_ raw:String,_ type:T.Type) throws -> T {try JSONDecoder().decode(type,from:Data(raw.utf8))}
let empty=try decode(#"{"Term":{"label":"2026년 2학기"},"Rows":null}"#,AttendanceResult.self)
precondition(empty.Rows == nil && empty.Term.label == "2026년 2학기")
let partial=try decode(#"{"Term":{"label":"2026년 2학기"},"Rows":[{"Index":1,"Course":{"Name":"A","Professor":""},"Sessions":null,"Error":"조회 실패"},{"Index":2,"Course":{"Name":"B","Professor":"교수"},"Sessions":[{"Week":"1","Slots":null},{"Week":"2","Slots":[{"Index":1,"Status":"AT","Mark":"O","Date":""},{"Index":2,"Status":"NEW","Mark":"NEW","Date":"2026-09-01"}]}],"Error":""}]}"#,AttendanceResult.self)
precondition(partial.Rows?.count == 2)
precondition(partial.Rows?[0].Error == "조회 실패")
precondition(partial.Rows?[1].Sessions?[0].Slots == nil)
precondition(partial.Rows?[1].Sessions?[1].Slots?[1].Status == "NEW")
let cdp=try decode(#"{"Report":{"TotalCount":"0","Rows":null}}"#,CdpResult.self)
precondition(cdp.Report.Rows == nil)
do { _ = try decode(#"{"Term":{},"Rows":[]}"#,AttendanceResult.self);fatalError("Missing term must fail") } catch {}
print("Attendance null collections, partial failure, unknown status and malformed response checks passed")
precondition(attendanceDateLabel("20260901") == "9월 1일 (화)")
precondition(attendanceDateLabel("2026-09-01") == "9월 1일 (화)")
precondition(attendanceDateLabel("20260230") == "20260230")
precondition(attendanceDateLabel("") == "날짜 미등록")
typealias Slot=AttendanceCourseRow.Session.Slot
for (code,label) in [("AT","출석"),("AB","결석"),("LT","지각"),("LE","조퇴"),("OA","공결"),("NEW","확인 필요"),("","미등록")] {
    precondition(Slot(Index:1,Status:code,Mark:"",Date:"").statusLabel == label)
}
precondition(Slot(Index:1,Status:"NEW",Mark:"O",Date:"").statusLabel == "확인 필요")
let course=AttendanceCourseRow(Index:1,Course:.init(Name:"테스트",Professor:""),Sessions:[.init(Week:"1",Slots:[.init(Index:1,Status:"AT",Mark:"O",Date:"20260901"),.init(Index:2,Status:"AB",Mark:"X",Date:"20260901"),.init(Index:3,Status:"",Mark:"",Date:"")]),.init(Week:"2",Slots:[.init(Index:1,Status:"LT",Mark:"L",Date:"20260901")])],Error:"")
precondition(course.days.count == 3 && course.days[0].slots.count == 2)
precondition(course.days[0].slots[1].statusLabel == "결석")
precondition(course.summary == "출석 1 · 결석 1 · 지각 1 · 미등록 1")
print("Attendance formatting, grouping, mixed statuses and summary checks passed")
let unsorted=AttendanceCourseRow(Index:1,Course:.init(Name:"정렬",Professor:""),Sessions:[
    .init(Week:"10",Slots:[.init(Index:1,Status:"AT",Mark:"O",Date:"20261001")]),
    .init(Week:"2",Slots:[.init(Index:2,Status:"AB",Mark:"X",Date:"20260910"),.init(Index:2,Status:"AT",Mark:"O",Date:"20260908"),.init(Index:1,Status:"LT",Mark:"L",Date:"20260908"),.init(Index:3,Status:"",Mark:"",Date:"bad")]),
    .init(Week:"1",Slots:[.init(Index:1,Status:"AT",Mark:"O",Date:"20260901")])],Error:"")
precondition(unsorted.weeks.map(\.week)==["1","2","10"])
precondition(unsorted.weeks[1].days.map(\.date)==["20260908","20260910","bad"])
precondition(unsorted.weeks[1].days[0].slots.map(\.Index)==[1,2])
precondition(unsorted.weeks[1].days[0].slots.map(\.statusLabel)==["지각","출석"])
precondition(unsorted.weeks.flatMap(\.days).flatMap(\.slots).count==6)
print("Week grouping, numeric week order, chronological dates, slot order and record preservation passed")
