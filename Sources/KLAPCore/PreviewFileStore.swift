import Foundation

/// Owns only files created under its private root. Downloaded files leave this store.
public final class PreviewFileStore {
    private struct Entry: Codable { var path: String; var expires: Date? }
    public static let lifetime: TimeInterval = 3 * 60 * 60
    public let root: URL
    private var entries: [String: Entry] = [:]
    private let fm = FileManager.default
    private var manifest: URL { root.appendingPathComponent("manifest.json") }
    public var nextExpiration: Date? { entries.values.compactMap(\.expires).min() }

    public init(root: URL, now: Date = Date()) throws {
        self.root = root.standardizedFileURL
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if let data = try? Data(contentsOf: manifest) { entries = (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:] }
        // A prior process has ended, so none of its previews can still be open.
        for key in Array(entries.keys) where entries[key]?.expires == nil { entries[key]?.expires = now.addingTimeInterval(Self.lifetime) }
        try cleanup(now: now)
    }
    public func cached(_ key: String, now: Date = Date()) throws -> URL? {
        try cleanup(now: now)
        guard let item = entries[key], owns(URL(fileURLWithPath:item.path)), fm.fileExists(atPath:item.path) else { return nil }
        return URL(fileURLWithPath: item.path)
    }
    public func register(_ file: URL, key: String, now: Date = Date()) throws {
        guard owns(file), fm.fileExists(atPath:file.path) else { throw CocoaError(.fileReadInvalidFileName) }
        entries[key] = Entry(path:file.path,expires:now.addingTimeInterval(Self.lifetime))
        try persist()
    }
    public func opened(_ key: String) throws { entries[key]?.expires = nil; try persist() }
    public func closed(_ key: String, now: Date = Date()) throws { entries[key]?.expires = now.addingTimeInterval(Self.lifetime); try persist() }
    public func cleanup(now: Date = Date()) throws {
        for (key,item) in entries {
            let file = URL(fileURLWithPath:item.path)
            if !owns(file) { entries.removeValue(forKey:key); continue }
            if !fm.fileExists(atPath:item.path) || item.expires.map({ $0 <= now }) == true {
                if fm.fileExists(atPath:file.deletingLastPathComponent().path) { try fm.removeItem(at:file.deletingLastPathComponent()) }
                entries.removeValue(forKey:key)
            }
        }
        // Clean transfers abandoned before registration (e.g. a terminated app).
        let tracked = Set(entries.values.map { URL(fileURLWithPath:$0.path).deletingLastPathComponent().standardizedFileURL.path })
        for folder in try fm.contentsOfDirectory(at:root,includingPropertiesForKeys:[.contentModificationDateKey,.isDirectoryKey]) where folder.lastPathComponent.hasPrefix("attachment-") && !tracked.contains(folder.standardizedFileURL.path) {
            let values=try folder.resourceValues(forKeys:[.contentModificationDateKey,.isDirectoryKey])
            if values.isDirectory == true, let date=values.contentModificationDate, now.timeIntervalSince(date)>=Self.lifetime { try fm.removeItem(at:folder) }
        }
        try persist()
    }
    public func moveToDownloads(_ key: String, directory: URL, now: Date = Date()) throws -> URL {
        guard let source = try cached(key,now:now) else { throw CocoaError(.fileNoSuchFile) }
        try fm.createDirectory(at:directory,withIntermediateDirectories:true)
        let ext=source.pathExtension, stem=source.deletingPathExtension().lastPathComponent
        var number=0
        while true {
            let name = number == 0 ? source.lastPathComponent : "\(stem) (\(number))" + (ext.isEmpty ? "" : ".\(ext)")
            let target=directory.appendingPathComponent(name)
            do { try fm.moveItem(at:source,to:target)
                entries.removeValue(forKey:key)
                try? fm.removeItem(at:source.deletingLastPathComponent())
                try persist()
                return target
            } catch let error as CocoaError where error.code == .fileWriteFileExists { number += 1 }
        }
    }
    private func owns(_ file: URL) -> Bool {
        let parent=file.standardizedFileURL.deletingLastPathComponent()
        return parent.lastPathComponent.hasPrefix("attachment-") && parent.deletingLastPathComponent().standardizedFileURL.path == root.path && file.resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().path == root.resolvingSymlinksInPath().path
    }
    private func persist() throws { try JSONEncoder().encode(entries).write(to:manifest,options:.atomic) }
}
