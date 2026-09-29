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
