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
