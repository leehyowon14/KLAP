import SwiftUI

struct AttendancePage: View {
    @ObservedObject var model:AppModel
    var courseName:String? = nil
    var refreshID:UUID = UUID()
    var onBack:()->Void = {}
    @ViewState<Bool> private var showAll=false
    @ViewState<Bool> private var cdp=false
    @ViewState<AttendanceResult?> private var result=nil
    @ViewState<CdpResult?> private var cdpResult=nil
    @ViewState<String?> private var failure=nil
    @ViewState<Bool> private var loading=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            AttendanceHeader(cdp:$cdp,showsPicker:courseName == nil || showAll,loading:loading,onBack:onBack)
            if let courseName,!showAll {
                HStack { Text("\(courseName) 출석").font(.headline);Spacer();Button("전체 과목") {showAll=true} }
            }
            Text("KLAS 최신 학기 기준").font(.caption).foregroundStyle(.secondary)
            if loading { ProgressView("출석을 불러오는 중…") }
            if let failure { Text(failure).foregroundStyle(.red);Button("다시 시도") {Task {await load()}}.disabled(loading) }
            if cdp,let report=cdpResult?.Report {
                Text("총 \(report.TotalCount)회").font(.headline)
                if (report.Rows ?? []).isEmpty { Text("CDP 출석 기록이 없습니다.") }
                ForEach(Array((report.Rows ?? []).enumerated()),id:\.offset) { _,row in
                    VStack(alignment:.leading,spacing:5) {Text(row.Title);Text([attendanceDateLabel(row.Date),row.Speaker].filter{!$0.isEmpty}.joined(separator:" · ")).font(.caption).foregroundStyle(.secondary)}
                    Divider()
                }
            } else if !cdp,let result {
                Text(result.Term.label).font(.headline)
                let rows=(!showAll && courseName != nil) ? (result.Rows ?? []).filter{$0.Course.Name == courseName} : (result.Rows ?? [])
                if rows.isEmpty {Text(courseName != nil && !showAll ? "이 과목의 최신 학기 출석 기록을 찾지 못했습니다." : "출석 조회 대상 과목이 없습니다.").foregroundStyle(.secondary)}
                ForEach(rows,id:\.Index) { row in
                    AttendanceCourseCard(row:row,expanded:courseName != nil && !showAll).id("\(row.Index)-\(showAll)")
                }
            }
        }.task(id:"\(cdp)-\(refreshID)") {await load()}
    }
    private func load() async {
        loading=true;failure=nil;result=nil;cdpResult=nil
        defer {loading=false}
        do {
            if cdp {cdpResult=try await model.pageValue(["Command":"attendance-cdp"],as:CdpResult.self)}
            else {result=try await model.pageValue(["Command":"attendance-list"],as:AttendanceResult.self)}
        } catch is CancellationError {} catch {failure=error.localizedDescription}
    }
}
