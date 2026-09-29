import Foundation

public struct SyllabusResult: Decodable {
    public let SubjectID: String
    public let Syllabus: CourseSyllabus
}
public struct CourseSyllabus: Decodable {
    public let KoreanName: String
    public let Professor: String
    public let CourseType: String
    public let Credits: String
    public let CurrentNum: String
    public let Summary: String
    public let Purpose: String
    public let Outcome: String
    public let Competency: String
    public let BookName: String
    public let Operation: String
    public let Evaluation: SyllabusEvaluation
    public let Schedule: [SyllabusWeek]?
    public var enrollment: Int? {
        guard let value = Int(CurrentNum.trimmingCharacters(in: .whitespacesAndNewlines)), value >= 0 else { return nil }
        return value
    }
}
public struct SyllabusEvaluation: Decodable {
    public let Attendance: Int
    public let Learning: Int
    public let Midterm: Int
    public let Final: Int
    public let Report: Int
    public let Quiz: Int
    public let Other: Int
}
public struct SyllabusWeek: Decodable {
    public let Week: Int
    public let Topic: String
    public let SubNote: String
}
