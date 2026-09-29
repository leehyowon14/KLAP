import Foundation

public enum CourseTones {
    /// Spread distinct course identities across the usable tonal range.
    /// Repeated meetings and input ordering never change a course's tone.
    public static func assign(_ ids:[String]) -> [String:Double] {
        let courses=Array(Set(ids)).sorted()
        guard !courses.isEmpty else { return [:] }
        if courses.count == 1 { return [courses[0]:50] }
        return Dictionary(uniqueKeysWithValues:courses.enumerated().map {
            ($0.element,15 + 65 * Double($0.offset) / Double(courses.count-1))
        })
    }
}
