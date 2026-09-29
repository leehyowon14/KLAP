import Foundation

/// Matches the CLI stable resource ID contract: kind:v1:base64url(term):base64url(course):...
public struct ContentAddress:Equatable {
    public let kind:String
    public let term:String
    public let course:String
    public let parts:[String]
    public init?(_ id:String) {
        let values=id.split(separator:":",omittingEmptySubsequences:false).map(String.init)
        guard values.count>=5,values[1]=="v1",
              (values[0]=="lecture" && values.count==5) || (values[0]=="notice" && values.count==6) else {return nil}
        var decoded:[String]=[]
        for value in values.dropFirst(2) {
            var base=value.replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/")
            base += String(repeating:"=",count:(4-base.count%4)%4)
            guard let data=Data(base64Encoded:base),let text=String(data:data,encoding:.utf8),!text.isEmpty else {return nil}
            decoded.append(text)
        }
        kind=values[0];term=decoded[0];course=decoded[1];parts=Array(decoded.dropFirst(2))
    }
}

public struct ContentAlert:Codable,Identifiable {
    public enum Kind:String,Codable {case notice,lecture}
    public let id:String
    public let account:String
    public let term:String
    public let kind:Kind
    public let ids:[String]
    public let title:String
    public let body:String
    public let actionable:Bool
    public let created:Date
    public var delivered:Bool=false
}

public struct ContentNotificationHistory:Codable {
    private var seen:[String:Set<String>]=[:]
    public private(set) var alerts:[ContentAlert]=[]
    public init() {}
    public mutating func ingest(_ snapshot:Snapshot,notices:Bool,lectures:Bool,now:Date=Date()) {
        alerts.removeAll {now.timeIntervalSince($0.created)>14*86400}
        guard let account=snapshot.account,!account.isEmpty,let table=snapshot.timetable else {return}
        let term=table.Term.value
        // A newly added course is baselined separately, including empty successful lists.
        for course in table.Term.subjList ?? [] {
            if let rows=snapshot.notices {
                let valid=rows.filter{ContentAddress($0.id)?.term==term && ContentAddress($0.id)?.course==course.id}
                let added=newIDs(account:account,term:term,course:course.id,kind:"notice",ids:valid.map(\.id))
                let fresh=valid.filter{added.contains($0.id)}
                if notices,!fresh.isEmpty {
                    append(account:account,term:term,kind:.notice,ids:fresh.map(\.id),
                           title:"\(course.name) · 새 공지 \(fresh.count)개",
                           body:fresh.prefix(3).map{$0.Notice.Title}.joined(separator:"\n"),actionable:false,now:now)
                }
            }
        }
        if let rows=snapshot.lectures {
            var added=Set<String>()
            for course in table.Term.subjList ?? [] {
                let valid=rows.filter{ContentAddress($0.id)?.term==term && ContentAddress($0.id)?.course==course.id}
                added.formUnion(newIDs(account:account,term:term,course:course.id,kind:"lecture",ids:valid.map(\.id)))
            }
            let fresh=rows.filter{added.contains($0.id)}
            if lectures,!fresh.isEmpty {
                append(account:account,term:term,kind:.lecture,ids:fresh.map(\.id),
                       title:fresh.count==1 ? "\(fresh[0].row.CourseName) · 새 강의" : "새 강의 \(fresh.count)개",
                       body:fresh.prefix(3).map{"\($0.row.CourseName) · \($0.row.Lecture.Title)"}.joined(separator:"\n"),
                       actionable:fresh.contains{$0.reason.isEmpty},now:now)
            }
        }
    }
    private mutating func newIDs(account:String,term:String,course:String,kind:String,ids:[String])->Set<String> {
        let key=([account,term,course,kind].map{Data($0.utf8).base64EncodedString()}).joined(separator:":")
        let current=Set(ids)
        let result=seen[key].map{current.subtracting($0)} ?? []
        seen[key,default:[]].formUnion(current)
        return result
    }
    private mutating func append(account:String,term:String,kind:ContentAlert.Kind,ids:[String],title:String,body:String,actionable:Bool,now:Date) {
        var unique:[String]=[]
        for id in ids where !unique.contains(id) {unique.append(id)}
        alerts.append(ContentAlert(id:UUID().uuidString,account:account,term:term,kind:kind,ids:unique,title:title,body:body,actionable:actionable,created:now))
    }
    public mutating func markDelivered(_ id:String) {
        if let index=alerts.firstIndex(where:{$0.id==id}) {alerts[index].delivered=true}
    }
    public func alert(_ id:String,now:Date=Date())->ContentAlert? {
        alerts.first{$0.id==id && now.timeIntervalSince($0.created)<=14*86400}
    }
    public func pending(account:String,notices:Bool,lectures:Bool)->[ContentAlert] {
        alerts.filter{!$0.delivered && $0.account==account && ($0.kind == .notice ? notices : lectures)}
    }
    public func eligibleIDs(for alert:ContentAlert,in snapshot:Snapshot)->[String] {
        guard alert.kind == .lecture,alert.account==snapshot.account,alert.term==snapshot.timetable?.Term.value,
              let lectures=snapshot.lectures else {return []}
        let available=Set(lectures.filter{$0.reason.isEmpty}.map(\.id))
        return alert.ids.filter{available.contains($0)}
    }
}
