import Foundation

/// KW academic bylaws, article 16-2 (2025-12-17): A <= 40%, A+B <= 80%.
/// A maximum-filled example, not independent B quota or the instructor's allocation.
public struct GradeAllocation {
    public let a: Int
    public let b: Int
    public let lower: Int
    public init?(count: Int) {
        guard count > 0 else { return nil }
        // Integer division floors the cumulative limits without multiplication overflow.
        let a = (count / 5) * 2 + (count % 5) * 2 / 5
        let ab = (count / 5) * 4 + (count % 5) * 4 / 5
        self.a = a
        self.b = ab - a
        self.lower = count - ab
    }
}
