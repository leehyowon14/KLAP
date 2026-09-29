import Foundation

public enum LinkedBody {
    public static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return result }
        for match in detector.matches(in:text,range:NSRange(text.startIndex...,in:text)) {
            guard let url=match.url, ["https","http","mailto"].contains(url.scheme?.lowercased() ?? ""),
                  let range=Range(match.range,in:text), let attributedRange=Range(range,in:result) else { continue }
            result[attributedRange].link=url
        }
        return result
    }
}
