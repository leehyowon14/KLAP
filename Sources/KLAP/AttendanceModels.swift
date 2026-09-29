import Foundation

struct AttendanceResult: Decodable {
    struct TermValue: Decodable { let label:String }
    let Term:TermValue
    let Rows:[AttendanceCourseRow]?
}
struct AttendanceCourseRow: Decodable {
    struct CourseValue: Decodable { let Name:String; let Professor:String }
    struct Session: Decodable {
        struct Slot: Decodable { let Index:Int; let Status:String; let Mark:String; let Date:String }
        let Week:String
        let Slots:[Slot]?
    }
    let Index:Int
    let Course:CourseValue
    let Sessions:[Session]?
    let Error:String
}
struct CdpResult: Decodable {
    struct ReportValue: Decodable {
        struct Row: Decodable { let Date:String; let Title:String; let Speaker:String }
        let TotalCount:String
        let Rows:[Row]?
    }
    let Report:ReportValue
}

extension AttendanceCourseRow.Session.Slot {
    var statusLabel:String {
        switch Status.trimmingCharacters(in:.whitespacesAndNewlines).uppercased() {
        case "AT": return "출석"
        case "AB": return "결석"
        case "LT": return "지각"
        case "LE": return "조퇴"
        case "OA": return "공결"
        case "":
            switch Mark.uppercased() {
            case "O":return "출석"
            case "X":return "결석"
            case "L":return "지각"
            case "R":return "조퇴"
            case "A":return "공결"
            case "":return "미등록"
            default:return "확인 필요"
            }
        default:return "확인 필요"
        }
    }
}
struct AttendanceDay {
    let week:String
    let date:String
    var slots:[AttendanceCourseRow.Session.Slot]
    var dateLabel:String { attendanceDateLabel(date) }
}
extension AttendanceCourseRow {
    var days:[AttendanceDay] {
        var result:[AttendanceDay]=[]
        for session in Sessions ?? [] {
            for slot in session.Slots ?? [] {
                if !slot.Date.isEmpty, let index=result.firstIndex(where:{$0.week == session.Week && $0.date == slot.Date}) {
                    result[index].slots.append(slot)
                } else {result.append(AttendanceDay(week:session.Week,date:slot.Date,slots:[slot]))}
            }
        }
        return result
    }
    var weeks:[AttendanceWeek] {
        let grouped=Dictionary(grouping:days,by: \.week)
        return grouped.keys.sorted {
            let left=Int($0.trimmingCharacters(in:.whitespaces))
            let right=Int($1.trimmingCharacters(in:.whitespaces))
            if let left,let right,left != right {return left<right}
            if (left != nil) != (right != nil) {return left != nil}
            return $0<$1
        }.map { week in
            let ordered=(grouped[week] ?? []).enumerated().sorted { a,b in
                let left=attendanceDate(a.element.date),right=attendanceDate(b.element.date)
                if let left,let right,left != right {return left<right}
                if (left != nil) != (right != nil) {return left != nil}
                return a.offset<b.offset
            }.map { entry -> AttendanceDay in
                var day=entry.element
                day.slots=day.slots.enumerated().sorted {
                    $0.element.Index == $1.element.Index ? $0.offset<$1.offset : $0.element.Index<$1.element.Index
                }.map(\.element)
                return day
            }
            return AttendanceWeek(week:week,days:ordered)
        }
    }
    var summary:String {
        let slots=(Sessions ?? []).flatMap{$0.Slots ?? []}
        let labels=["출석","결석","지각","조퇴","공결","미등록","확인 필요"]
        return labels.compactMap { label -> String? in
            let count=slots.filter{$0.statusLabel == label}.count
            return count == 0 ? nil : "\(label) \(count)"
        }.joined(separator:" · ")
    }
}
struct AttendanceWeek {
    let week:String
    let days:[AttendanceDay]
}
func attendanceDate(_ raw:String)->Date? {
    let value=raw.trimmingCharacters(in:.whitespacesAndNewlines)
    let parser=DateFormatter()
    parser.locale=Locale(identifier:"en_US_POSIX")
    parser.calendar=Calendar(identifier:.gregorian)
    parser.timeZone=TimeZone(secondsFromGMT:9*3600)
    parser.dateFormat=value.count == 8 ? "yyyyMMdd" : "yyyy-MM-dd"
    parser.isLenient=false
    guard let date=parser.date(from:value),parser.string(from:date)==value else {return nil}
    return date
}
func attendanceDateLabel(_ raw:String)->String {
    let value=raw.trimmingCharacters(in:.whitespacesAndNewlines)
    if value.isEmpty {return "날짜 미등록"}
    guard let date=attendanceDate(value) else {return value}
    let formatter=DateFormatter()
    formatter.locale=Locale(identifier:"ko_KR")
    formatter.calendar=Calendar(identifier:.gregorian)
    formatter.timeZone=TimeZone(secondsFromGMT:9*3600)
    formatter.dateFormat="M월 d일 (E)"
    return formatter.string(from:date)
}
