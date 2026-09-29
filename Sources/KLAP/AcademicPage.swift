import SwiftUI
import KLAPCore

struct AcademicPage:View {
    @ObservedObject var model:AppModel
    var refreshID:UUID = UUID()
    @ViewState<Date> private var month=AcademicCalendar.monthStart(Date())
    @ViewState<Date> private var selected=AcademicCalendar.calendar.startOfDay(for:Date())
    @ViewState<AcademicResult?> private var result=nil
    @ViewState<String?> private var failure=nil
    @ViewState<Bool> private var loading=false
    private var year:Int {AcademicCalendar.calendar.component(.year,from:month)}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Button {move(-1)} label:{Image(systemName:"chevron.left").frame(width:28,height:28)}.accessibilityLabel("이전 달").disabled(loading)
                Spacer();Text("\(String(year))년 \(AcademicCalendar.calendar.component(.month,from:month))월").font(.headline);Spacer()
                Button {move(1)} label:{Image(systemName:"chevron.right").frame(width:28,height:28)}.accessibilityLabel("다음 달").disabled(loading)
                Button("오늘") {month=AcademicCalendar.monthStart(Date());selected=AcademicCalendar.calendar.startOfDay(for:Date())}.disabled(loading)
            }.buttonStyle(.plain)
            AcademicMonthGrid(month:month,selected:$selected,events:result?.Events ?? [])
            if loading {ProgressView("학사일정을 불러오는 중…")}
            if let failure {Text(failure).foregroundStyle(.red);Button("다시 시도") {Task {await load()}}.disabled(loading)}
            if let result {
                Text(selected.formatted(.dateTime.locale(Locale(identifier:"ko_KR")).month().day().weekday())).font(.callout.weight(.semibold))
                let events=(result.Events ?? []).filter{$0.includes(selected)}
                if events.isEmpty {Text("선택한 날짜에 학사일정이 없습니다.").font(.callout).foregroundStyle(.secondary)}
                ForEach(Array(events.enumerated()),id:\.offset) { _,entry in eventRow(entry) }
                let undated=(result.Events ?? []).filter{($0.Start ?? "").isEmpty}
                if !undated.isEmpty {
                    DisclosureGroup("날짜 미정 일정 \(undated.count)개") {
                        ForEach(Array(undated.enumerated()),id:\.offset) { _,entry in eventRow(entry) }
                    }.font(.caption)
                }
                if let url=URL(string:result.SourceURL),url.scheme == "https" {Link("학교 학사일정 원문 ↗",destination:url).font(.caption)}
            }
        }.task(id:"\(year)-\(refreshID)") {await load()}
    }
    private func eventRow(_ entry:AcademicEntry)->some View {
        HStack(alignment:.top,spacing:9) {
            RoundedRectangle(cornerRadius:2).fill(Color(nsColor:Theme.tone(CourseTones.assign((result?.Events ?? []).map(\.colorIdentity))[entry.colorIdentity] ?? 50))).frame(width:4).frame(minHeight:36)
            VStack(alignment:.leading,spacing:5) {
            Text(entry.Title).font(.callout.weight(.medium))
            Text(entry.Date).font(.caption).foregroundStyle(.secondary)
            if !entry.Note.isEmpty {Text(entry.Note).font(.caption).foregroundStyle(.secondary)}
            }
        }.fixedSize(horizontal:false,vertical:true).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
    }
    private func move(_ offset:Int) {
        guard let next=AcademicCalendar.calendar.date(byAdding:.month,value:offset,to:month) else{return}
        month=next;selected=next
    }
    private func load() async {
        loading=true;failure=nil;result=nil
        defer {loading=false}
        do {result=try await model.pageValue(["Command":"academic-list","Year":String(year)],as:AcademicResult.self)}
        catch is CancellationError {} catch {failure=error.localizedDescription}
    }
}

extension AppModel {
    func pageValue<T:Decodable>(_ request:[String:Any],as type:T.Type) async throws -> T {
        while busy { try await Task.sleep(nanoseconds:150_000_000) }
        try Task.checkCancellation()
        var result:T?
        await perform(request) { event in
            if event.kind == "result" { result=try event.decode(T.self) }
        }
        try Task.checkCancellation()
        guard let result else { throw BridgeFailure(message:error ?? "응답을 받지 못했습니다.") }
        return result
    }
}
