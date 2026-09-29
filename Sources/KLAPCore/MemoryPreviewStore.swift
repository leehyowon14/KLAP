import Foundation

public final class MemoryPreviewStore {
    public struct Item { public let data:Data; public let name:String; var expires:Date? }
    private var items:[String:Item]=[:]
    public static let lifetime:TimeInterval=10800
    public let limit:Int
    public init(limit:Int=256*1024*1024) {self.limit=limit}
    public var nextExpiration:Date? {items.values.compactMap(\.expires).min()}
    public var byteCount:Int {items.values.reduce(0){$0+$1.data.count}}
    public func cleanup(now:Date=Date()) {items=items.filter{$0.value.expires.map{$0>now} ?? true}}
    public func cached(_ key:String,now:Date=Date())->Item? {cleanup(now:now);return items[key]}
    public func register(_ data:Data,name:String,key:String,now:Date=Date()) throws {
        cleanup(now:now)
        guard data.count<=limit else {throw CocoaError(.fileReadTooLarge)}
        let old=items.removeValue(forKey:key)
        for (candidate,_) in items.filter({$0.value.expires != nil}).sorted(by:{$0.value.expires! < $1.value.expires!}) where byteCount+data.count>limit {items.removeValue(forKey:candidate)}
        guard byteCount+data.count<=limit else {items[key]=old;throw CocoaError(.fileReadTooLarge)}
        items[key]=Item(data:data,name:name,expires:now.addingTimeInterval(Self.lifetime))
    }
    public func opened(_ key:String){items[key]?.expires=nil}
    public func closed(_ key:String,now:Date=Date()){items[key]?.expires=now.addingTimeInterval(Self.lifetime)}
    public func save(_ key:String,to directory:URL)throws->URL {
        guard let item=cached(key) else {throw CocoaError(.fileNoSuchFile)}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let cleaned=item.name.replacingOccurrences(of:"\\",with:"/").components(separatedBy:"/").last ?? "첨부파일"
        let name=(cleaned.isEmpty || cleaned=="." || cleaned=="..") ? "첨부파일" : cleaned.replacingOccurrences(of:":",with:"_")
        let base=URL(fileURLWithPath:name), ext=base.pathExtension,stem=base.deletingPathExtension().lastPathComponent
        var index=0
        while true {
            let filename=index==0 ? name : "\(stem) (\(index))"+(ext.isEmpty ? "" : ".\(ext)")
            let url=directory.appendingPathComponent(filename)
            do {try item.data.write(to:url,options:.withoutOverwriting);items.removeValue(forKey:key);return url}
            catch let e as CocoaError where e.code == .fileWriteFileExists {index+=1}
        }
    }
}
