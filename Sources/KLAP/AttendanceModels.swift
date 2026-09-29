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
