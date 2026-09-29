import SwiftUI
import KLAPCore

struct LectureStatusView: View {
    let item: LectureItem
    @ObservedObject var model: AppModel
    var body: some View {
        TimelineView(.periodic(from:.now,by:60)) { context in
            let lecture=item.row.Lecture
            let due=LectureStatus.date(lecture.EndAt)
            let time=StudyTime(achieved:lecture.AchievedTime,required:lecture.RequiredTime)
            let completed=(Double(lecture.Progress) ?? 0) >= 100 || (time.remaining == 0)
            let state=LectureStatus.resolve(complete:completed,deadline:due,started:LectureStatus.date(lecture.FirstStartedAt),finished:LectureStatus.date(lecture.FirstCompletedAt),now:context.date)
            HStack(spacing:12) {
                VStack(alignment:.leading,spacing:6) {
                    Text(lecture.Title).font(.system(size:13,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                    if let due, due > context.date {
                        Text(deadlineText(due)).font(.system(size:11))
                            .foregroundStyle(LectureStatus.urgency(deadline:due,now:context.date) == 2 ? Color.red : LectureStatus.urgency(deadline:due,now:context.date) == 1 ? Color.orange : Color.secondary)
                    }
                }
                Spacer(minLength:8)
                Group {
                    switch state {
                    case .complete: Image(systemName:"circle").foregroundStyle(.blue).accessibilityLabel("기간 내 수강 완료")
                    case .missed: Image(systemName:"xmark").foregroundStyle(.red).accessibilityLabel("기간 종료, 미수강")
                    case .late:
                        (Text("L").foregroundColor(.orange) + Text(" / ").foregroundColor(.gray) + Text("X").foregroundColor(.red)).accessibilityLabel("기간 내 시작, 마감 후 완료")
                    case .unknown: Image(systemName:"circle").foregroundStyle(.gray).help("수강 완료 · 완료 시각이 없어 기간 내 완료 여부를 확인할 수 없습니다")
                    case .pending:
                        Text("\(time.achieved.map { String(format:"%02d",Int($0)) } ?? "??")/\(time.required.map { String(format:"%02d",Int($0)) } ?? "??")분").foregroundStyle(.gray).monospacedDigit()
                    }
                }.font(.system(size:12,weight:.semibold))
                Button("열기") { Task { await model.openLecture(item.id) } }.disabled(model.busy)
                if item.reason.isEmpty { Button("수강") { model.requestedLecture=item.id }.disabled(model.busy) }
            }.padding(12).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
        }
    }
    private func deadlineText(_ date:Date) -> String {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"ko_KR")
        formatter.timeZone=TimeZone(identifier:"Asia/Seoul")
        formatter.dateFormat="~M월dd일 HH시 mm분까지"
        return formatter.string(from:date)
    }
}
