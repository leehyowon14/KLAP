import Foundation

public struct StudyProgress: Equatable {
    public var fraction: Double
    public var current: Int
    public var total: Int
    public init(percent: Double, current: Int, total: Int) {
        fraction = percent.isFinite ? min(1, max(0, percent / 100)) : 0
        self.total = max(0, total)
        self.current = min(max(0, current), self.total)
    }
    public var label: String { total > 0 ? "\(current)/\(total)" : "" }
}

public struct StudyTime {
    public let achieved: Double?
    public let required: Double?
    public init(achieved:String?, required:String?) {
        func parse(_ value:String?) -> Double? {
            guard let value, let number=Double(value.trimmingCharacters(in:.whitespacesAndNewlines)),
                  number.isFinite, number >= 0 else { return nil }
            return number
        }
        self.achieved=parse(achieved)
        self.required=parse(required).flatMap { $0 > 0 ? $0 : nil }
    }
    public var remaining:Double? {
        guard let achieved, let required else { return nil }
        return max(0,required-achieved)
    }
    public static func minutes(_ value:Double?) -> String {
        guard let value else { return "확인 중" }
        return "\(Int(ceil(value)))분"
    }
}
