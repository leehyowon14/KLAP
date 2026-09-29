import Foundation

enum LectureDownloadLocation {
    static func root(in base:URL)->URL {
        base.standardizedFileURL.appendingPathComponent("KLAP",isDirectory:true)
    }
}
