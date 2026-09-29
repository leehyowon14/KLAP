import AppKit
import UserNotifications
import KLAPCore

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let categories=ContentNotificationService.categories()
    precondition(categories.count==4)
    let single=categories.first{$0.identifier=="KLAP.NEW_LECTURE"}!
    precondition(single.actions.map(\.identifier)==[ContentNotificationService.startOne,ContentNotificationService.open])
    let many=categories.first{$0.identifier=="KLAP.NEW_LECTURES"}!
    precondition(many.actions.first?.identifier==ContentNotificationService.startAll)
    precondition(many.actions.allSatisfy{$0.options.contains(.foreground)})
    precondition(categories.first{$0.identifier=="KLAP.NEW_CONTENT"}!.actions.count==1)
    func alert(kind:String,ids:[String],actionable:Bool)->ContentAlert {
        let data=try! JSONSerialization.data(withJSONObject:["id":"token","account":"hash","term":"term","kind":kind,"ids":ids,"title":"Title","body":"Body","actionable":actionable,"created":0,"delivered":false])
        return try! JSONDecoder().decode(ContentAlert.self,from:data)
    }
    for (item,category) in [
        (alert(kind:"notice",ids:["n"],actionable:false),"KLAP.NEW_NOTICE"),
        (alert(kind:"lecture",ids:["l"],actionable:true),"KLAP.NEW_LECTURE"),
        (alert(kind:"lecture",ids:["l","m"],actionable:true),"KLAP.NEW_LECTURES"),
        (alert(kind:"lecture",ids:["l"],actionable:false),"KLAP.NEW_CONTENT")
    ] {
        let content=ContentNotificationService.content(item)
        precondition(content.categoryIdentifier==category)
        precondition(content.userInfo.count==1 && content.userInfo[ContentNotificationService.tokenKey] as? String=="token")
        precondition(content.title=="Title" && content.body=="Body")
        precondition(content.sound != nil)
    }
    print("Notification categories, foreground actions, single/batch eligibility and opaque payload checks passed")
}
