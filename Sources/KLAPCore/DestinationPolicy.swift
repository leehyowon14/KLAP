import Foundation

public enum DestinationPolicy {
    public static func uniqueNames(_ names: [String]) -> [String] {
        let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        return names.filter { !$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && counts[$0] == 1 }.sorted()
    }
    public static func availableName(_ base: String, existing: [String]) -> String {
        let occupied = Set(existing)
        if !occupied.contains(base) { return base }
        var number = 2
        while occupied.contains("\(base) (\(number))") { number += 1 }
        return "\(base) (\(number))"
    }
}

/// The exact destination names and existing-list choices sent to the CLI and persisted by KLAP.
public struct DestinationConfiguration: Equatable {
    public let timetable: String
    public let academic: String
    public let reminder: String
    public let usesExistingTimetable: Bool
    public let usesExistingAcademic: Bool
    public let usesExistingReminder: Bool

    public init(timetable: String, academic: String, reminder: String,
                newTimetable: String, newAcademic: String, newReminder: String) {
        usesExistingTimetable = !timetable.isEmpty
        usesExistingAcademic = !academic.isEmpty
        usesExistingReminder = !reminder.isEmpty
        self.timetable = usesExistingTimetable ? timetable : newTimetable
        self.academic = usesExistingAcademic ? academic : newAcademic
        self.reminder = usesExistingReminder ? reminder : newReminder
    }

    public var bridgeRequest: [String: Any] {
        ["TimetableName": timetable, "AcademicName": academic, "ReminderName": reminder,
         "TimetableExisting": usesExistingTimetable, "AcademicExisting": usesExistingAcademic,
         "ReminderExisting": usesExistingReminder]
    }

    public func persist(in defaults: UserDefaults) {
        defaults.set(timetable, forKey: "destinationTimetable")
        defaults.set(academic, forKey: "destinationAcademic")
        defaults.set(reminder, forKey: "destinationReminder")
        defaults.set(true, forKey: "destinationsConfigured")
    }
}
