import AppKit
import UserNotifications
import KLAPCore

func notificationTestID(_ kind:String,_ remote:String)->String {
    let fields=["2026,2","course-1",remote]+(kind == "notice" ? ["master"] : [])
    let encoded=fields.map{Data($0.utf8).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")}
    return ([kind,"v1"]+encoded).joined(separator:":")
}

func notificationTestSnapshot(notices:[String],lectures:[String])->Snapshot {
    let json:[String:Any]=[
        "account":"test-account",
        "errors":[],
        "timetable":["Term":["value":"2026,2","label":"2026학년도 2학기","subjList":[["name":"자료구조","value":"course-1"]]]],
        "notices":notices.map{["ID":$0,"CourseName":"course-1","Notice":["Title":"공지 \($0)"]] as [String:Any]},
        "lectures":lectures.map{["row":["ID":$0,"CourseName":"자료구조","Lecture":["Title":"강의 \($0)","Progress":"0"]],"reason":""] as [String:Any]}
    ]
    return try! JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:json))
}

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

    let notice1=notificationTestID("notice","notice-1"),notice2=notificationTestID("notice","notice-2")
    let lecture1=notificationTestID("lecture","lecture-1"),lecture2=notificationTestID("lecture","lecture-2")
    let deliverySuite="KLAP.delivery-check."+UUID().uuidString
    let deliveryDefaults=UserDefaults(suiteName:deliverySuite)!
    var submitted:[UNNotificationRequest]=[]
    let delivery=ContentNotificationService(defaults:deliveryDefaults,readAuthorization:{.authorized},submitNotification:{submitted.append($0)})
    await delivery.process(notificationTestSnapshot(notices:[notice1],lectures:[lecture1]),preferences:{(true,true)})
    precondition(submitted.isEmpty,"Initial content is a baseline, not a notification")
    await delivery.process(notificationTestSnapshot(notices:[notice1,notice2],lectures:[lecture1,lecture2]),preferences:{(true,true)})
    precondition(submitted.count==2,"New notice and lecture are submitted once")
    precondition(Set(submitted.map{$0.content.categoryIdentifier})==Set(["KLAP.NEW_NOTICE","KLAP.NEW_LECTURE"]),"Each new content kind receives its expected category")
    precondition(delivery.history.pending(account:"test-account",notices:true,lectures:true).isEmpty,"Successfully submitted alerts are marked delivered")
    let relaunched=ContentNotificationService(defaults:deliveryDefaults,readAuthorization:{.authorized},submitNotification:{submitted.append($0)})
    await relaunched.process(notificationTestSnapshot(notices:[notice1,notice2],lectures:[lecture1,lecture2]),preferences:{(true,true)})
    precondition(submitted.count==2,"Persisted delivery history prevents repeat notifications after relaunch")
    deliveryDefaults.removePersistentDomain(forName:deliverySuite)

    let retrySuite="KLAP.retry-check."+UUID().uuidString
    let retryDefaults=UserDefaults(suiteName:retrySuite)!
    var retryRequests=0
    let failingDelivery=ContentNotificationService(defaults:retryDefaults,readAuthorization:{.authorized},submitNotification:{_ in
        retryRequests+=1
        throw NSError(domain:"Test",code:1)
    })
    await failingDelivery.process(notificationTestSnapshot(notices:[notice1],lectures:[lecture1]),preferences:{(true,true)})
    await failingDelivery.process(notificationTestSnapshot(notices:[notice1,notice2],lectures:[lecture1,lecture2]),preferences:{(true,true)})
    precondition(retryRequests==2 && failingDelivery.deliveryError != nil,"Failed delivery surfaces an error and retains pending alerts")
    precondition(failingDelivery.history.pending(account:"test-account",notices:true,lectures:true).count==2,"Failed alerts remain retryable")
    var retriedRequests:[UNNotificationRequest]=[]
    let retryDelivery=ContentNotificationService(defaults:retryDefaults,readAuthorization:{.authorized},submitNotification:{retriedRequests.append($0)})
    await retryDelivery.process(notificationTestSnapshot(notices:[notice1,notice2],lectures:[lecture1,lecture2]),preferences:{(true,true)})
    precondition(retriedRequests.count==2 && retryDelivery.history.pending(account:"test-account",notices:true,lectures:true).isEmpty,"Successful retry delivers and records each pending alert")
    retryDefaults.removePersistentDomain(forName:retrySuite)

    let muteSuite="KLAP.mute-during-delivery."+UUID().uuidString
    let muteDefaults=UserDefaults(suiteName:muteSuite)!
    var mutePreference=true
    var mutedRequests:[UNNotificationRequest]=[]
    var removedIDs:[String]=[]
    let muteDelivery=ContentNotificationService(defaults:muteDefaults,readAuthorization:{.authorized},submitNotification:{request in
        mutedRequests.append(request);mutePreference=false
    },removeDeliveredNotifications:{removedIDs += $0})
    await muteDelivery.process(notificationTestSnapshot(notices:[notice1],lectures:[lecture1]),preferences:{(true,true)})
    mutePreference=true
    await muteDelivery.process(notificationTestSnapshot(notices:[notice1,notice2],lectures:[lecture1,lecture2]),preferences:{(mutePreference,true)})
    precondition(mutedRequests.count==2 && mutedRequests.contains(where:{$0.content.categoryIdentifier=="KLAP.NEW_LECTURE"}) && removedIDs==mutedRequests.filter{$0.content.categoryIdentifier=="KLAP.NEW_NOTICE"}.map(\.identifier),"Turning off notices during delivery removes the notice while unrelated lecture alerts continue: sent=\(mutedRequests.map{$0.content.categoryIdentifier}), removed=\(removedIDs)")
    precondition(muteDelivery.history.pending(account:"test-account",notices:true,lectures:true).isEmpty,"Muted in-flight alerts are not replayed")
    muteDefaults.removePersistentDomain(forName:muteSuite)
    print("Notification delivery, relaunch deduplication, failed-send retry and in-flight mute checks passed")
    defaults.removePersistentDomain(forName:suite)
    exit(0)
}
NSApplication.shared.run()
