import Foundation

public enum ReminderIdentity {
    public static func matches(notes:String?, lectureID:String) -> Bool {
        guard !lectureID.isEmpty, let notes else { return false }
        let lines=notes.components(separatedBy:.newlines).map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }
        guard let footer=lines.lastIndex(of:"[This reminder is created by KLAP.]"),
              let header=lines[..<footer].lastIndex(of:"--- KLAP ---") else { return false }
        let expected=lectureID.hasPrefix("lecture:") ? lectureID : "lecture:" + lectureID
        return lines[(header+1)..<footer].contains("ID: " + expected)
    }
}
