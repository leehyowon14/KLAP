import Foundation

public enum CourseTones {
    /// Spread distinct course identities across the usable tonal range.
    /// Repeated meetings and input ordering never change a course's tone.
    private static func tone(at index:Int,count:Int) -> Double {
        let t=Double(index)/Double(count-1)
        return t < 0.4 ? 15 + t*25 : 40 + (t-0.4)/0.6*40
    }
    public static func assign(_ ids:[String]) -> [String:Double] {
        let courses=Array(Set(ids)).sorted()
        guard !courses.isEmpty else { return [:] }
        if courses.count == 1 { return [courses[0]:50] }
        return Dictionary(uniqueKeysWithValues:courses.enumerated().map {
            ($0.element, tone(at:$0.offset,count:courses.count))
        })
    }
}
