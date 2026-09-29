import AppKit
import UserNotifications
import KLAPCore

extension AppModel {
    func receiveContentAction(token:String,action:String) {
        guard action != UNNotificationDismissActionIdentifier else {return}
        let valid=[UNNotificationDefaultActionIdentifier,ContentNotificationService.open,ContentNotificationService.startOne,ContentNotificationService.startAll]
        guard valid.contains(action),activeContentAction != token,!pendingContentActions.contains(where:{$0.0==token && $0.1==action}) else {return}
        pendingContentActions.append((token,action))
        reveal?()
        guard !handlingContentAction else {return}
        handlingContentAction=true
        Task { @MainActor in
            defer {handlingContentAction=false}
            while !pendingContentActions.isEmpty {
                while busy || studying {try? await Task.sleep(nanoseconds:200_000_000)}
                let request=pendingContentActions.removeFirst()
                activeContentAction=request.0
                await executeContentAction(token:request.0,action:request.1)
                activeContentAction=nil
            }
        }
    }
    private func executeContentAction(token:String,action:String) async {
        guard let alert=contentNotifications.history.alert(token) else {message="오래된 알림입니다. 대시보드에서 최신 내용을 확인해 주세요.";return}
        guard !loggedOut,!onboarding else {message="로그인과 초기 설정을 마친 뒤 알림을 다시 눌러 주세요.";return}
        guard let fresh=await refresh(),fresh.account==alert.account,
              fresh.timetable?.Term.value==alert.term else {
            message="알림의 계정·학기를 확인하지 못했습니다. 현재 대시보드를 확인해 주세요.";return
        }
        notificationNavigation=UUID()
        showSettings=false;showLogin=false;showSyllabus=false;boardPresentation=nil
        let courseIDs=Set(alert.ids.compactMap{ContentAddress($0)?.course})
        selectedCourse=courseIDs.count==1 ? fresh.timetable?.Term.subjList?.first{$0.id==courseIDs.first}?.name : nil
        if action==ContentNotificationService.startOne || action==ContentNotificationService.startAll {
            guard alert.kind == .lecture else {return}
            let ids=contentNotifications.history.eligibleIDs(for:alert,in:fresh)
            guard !ids.isEmpty else {message="지금 수강할 수 있는 강의가 없습니다. 완료 여부와 수강 기간을 확인해 주세요.";return}
            await attend(ids,expectedAccount:alert.account)
        } else if alert.kind == .notice,alert.ids.count==1,
                  let row=fresh.notices?.first(where:{$0.id==alert.ids[0]}),let address=ContentAddress(row.id) {
            boardPresentation=BoardPresentation(reference:BoardReference(kind:"notice",term:address.term,subject:address.course,board:address.parts[0],master:address.parts[1]),title:row.Notice.Title)
        }
    }
}
