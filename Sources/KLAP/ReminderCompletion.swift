import EventKit
import KLAPCore

@MainActor final class ReminderCompletion {
    private let store=EKEventStore()
    func complete(lectureID:String, listName:String) async throws {
        let calendars=store.calendars(for:.reminder).filter { $0.title == listName && $0.allowsContentModifications }
        guard calendars.count == 1 else {
            throw BridgeFailure(message:"미리 알림 목록을 확인해 주세요: " + listName)
        }
        let predicate=store.predicateForReminders(in:calendars)
        let reminders:[EKReminder]? = await withCheckedContinuation { continuation in
            store.fetchReminders(matching:predicate) { continuation.resume(returning:$0) }
        }
        guard let reminders else { throw BridgeFailure(message:"미리 알림을 읽지 못했습니다") }
        let matches=reminders.filter { ReminderIdentity.matches(notes:$0.notes,lectureID:lectureID) }
        guard matches.count <= 1 else { throw BridgeFailure(message:"같은 강의의 미리 알림이 여러 개라 완료 처리하지 않았습니다") }
        guard let reminder=matches.first, !reminder.isCompleted else { return }
        reminder.isCompleted=true
        try store.save(reminder,commit:true)
    }
}
