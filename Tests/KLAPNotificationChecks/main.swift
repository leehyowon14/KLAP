import AppKit
import UserNotifications
import KLAPCore

Task { @MainActor in
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

    var permission:UNAuthorizationStatus = .notDetermined
    var requests=0
    let suite="KLAP.permission-check."+UUID().uuidString
    let defaults=UserDefaults(suiteName:suite)!
    let service=ContentNotificationService(defaults:defaults,readAuthorization:{permission},authorize:{
        requests+=1;permission = .authorized;return true
    })
    await service.requestAuthorizationIfNeeded()
    precondition(requests==1 && service.authorization == .authorized && !service.requestingPermission)
    await service.requestAuthorizationIfNeeded()
    precondition(requests==1,"Authorized app must not request again")
    permission = .denied
    await service.requestAuthorizationIfNeeded()
    precondition(requests==1 && service.deliveryError==nil,"Denied state must not create duplicate error")
    permission = .notDetermined
    let denied=ContentNotificationService(defaults:defaults,readAuthorization:{permission},authorize:{
        permission = .denied
        throw NSError(domain:UNErrorDomain,code:UNError.Code.notificationsNotAllowed.rawValue)
    })
    await denied.requestAuthorizationIfNeeded()
    precondition(denied.authorization == .denied && denied.deliveryError==nil)
    permission = .notDetermined
    let failed=ContentNotificationService(defaults:defaults,readAuthorization:{permission},authorize:{throw NSError(domain:"Test",code:1)})
    await failed.requestAuthorizationIfNeeded()
    precondition(failed.deliveryError?.contains("알림 권한") == true && !failed.requestingPermission)
    let url=ContentNotificationService.settingsURL(bundleID:"dev.leehyowon.klap.mac")
    precondition(URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first?.value=="dev.leehyowon.klap.mac")
    precondition(url.absoluteString.contains("Notifications-Settings.extension?id="))
    print("Permission request, already allowed/denied, error deduplication and app-specific settings URL checks passed")
    defaults.removePersistentDomain(forName:suite)
    exit(0)
}
NSApplication.shared.run()
