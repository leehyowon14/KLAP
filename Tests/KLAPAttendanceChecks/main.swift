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
