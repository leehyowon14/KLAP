import Foundation

public struct Timetable: Codable {
    public let Term: Term
    public let Entries: [TimetableEntry]?
}
public struct Term: Codable {
    public let label: String
    public let value: String
    public let subjList: [Course]?
}
public struct Course: Codable, Identifiable {
    public let name: String
    public let value: String
    public var id: String { value }
}
public struct TimetableEntry: Codable, Identifiable {
    public let SubjectID: String
    public let SubjectName: String
    public let Weekday: Int
    public let Period: Int
    public let Span: Int
    public let Room: String
    public let Online: Bool
    public var id: String { "\(SubjectID)-\(Weekday)-\(Period)-\(Room)" }
}
public struct LectureRow: Codable, Identifiable {
    public let ID: String
    public let CourseName: String
    public let Lecture: Lecture
    public var id: String { self.ID }
}
public struct Lecture: Codable {
    public let Title: String
    public let Progress: String
    public let EndAt: String?
}
public struct LectureItem: Codable, Identifiable {
    public let row: LectureRow
    public let reason: String
    public var id: String { row.id }
}
public struct AssignmentRow: Codable, Identifiable {
    public let ID: String
    public let CourseName: String
    public let Assignment: Assignment
    public var id: String { self.ID }
}
public struct Assignment: Codable {
    public let Title: String
    public let Submitted: Bool
    public let DueAt: String?
}
public struct NoticeRow: Codable, Identifiable {
    public let ID: String
    public let CourseName: String
    public let Notice: Notice
    public var id: String { self.ID }
}
public struct Notice: Codable { public let Title: String }
public struct Snapshot: Codable {
    public var timetable: Timetable?
    public var lectures: [LectureItem]?
    public var assignments: [AssignmentRow]?
    public var notices: [NoticeRow]?
    public var errors: [String]
    public init() { errors = [] }
}
public struct SyncConflict: Codable, Identifiable {
    public let Key: String
    public let Title: String
    public let Summary: String
    public var id: String { Key }
}
public struct SyncResult: Codable {
    public let errors: [String]
    public let conflicts: [SyncConflict]?
}
public struct StudyEvent: Decodable {
    public var id: String?
    public var title: String?
    public var percent: Double?
    public var current: Int?
    public var total: Int?
    public var message: String?
    public var success: Int?
    public var failed: Int?
}
