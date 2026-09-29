import SwiftUI

struct AttendancePage: View {
    @ObservedObject var model:AppModel
    @ViewState<Bool> private var cdp=false
    @ViewState<AttendanceResult?> private var result=nil
    @ViewState<CdpResult?> private var cdpResult=nil
    @ViewState<String?> private var failure=nil
    @ViewState<Bool> private var loading=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Picker("출석 구분",selection:$cdp) { Text("과목별 출석").tag(false);Text("CDP 출석").tag(true) }.pickerStyle(.segmented).disabled(loading)
            HStack { Text("KLAS 최신 학기 기준").font(.caption).foregroundStyle(.secondary);Spacer();Button("새로고침") {Task {await load()}}.disabled(loading) }
            if loading { ProgressView("출석을 불러오는 중…") }
            if let failure { Text(failure).foregroundStyle(.red);Button("다시 시도") {Task {await load()}}.disabled(loading) }
            if cdp,let report=cdpResult?.Report {
                Text("총 \(report.TotalCount)회").font(.headline)
                if (report.Rows ?? []).isEmpty { Text("CDP 출석 기록이 없습니다.") }
                ForEach(Array((report.Rows ?? []).enumerated()),id:\.offset) { _,row in
                    VStack(alignment:.leading,spacing:5) {Text(row.Title);Text([row.Date,row.Speaker].filter{!$0.isEmpty}.joined(separator:" · ")).font(.caption).foregroundStyle(.secondary)}
                    Divider()
                }
            } else if !cdp,let result {
                Text(result.Term.label).font(.headline)
                if (result.Rows ?? []).isEmpty {Text("출석 조회 대상 과목이 없습니다.")}
                ForEach(result.Rows ?? [],id:\.Index) { row in
                    DisclosureGroup {
                        if !row.Error.isEmpty {Text(row.Error).foregroundStyle(.red)}
                        else if (row.Sessions ?? []).isEmpty {Text("등록된 출석 기록이 없습니다.").foregroundStyle(.secondary)}
                        ForEach(Array((row.Sessions ?? []).enumerated()),id:\.offset) { _,session in
                            VStack(alignment:.leading,spacing:6) {
                                Text("\(session.Week)주차").font(.callout.weight(.medium))
                                ForEach(Array((session.Slots ?? []).enumerated()),id:\.offset) { _,slot in
                                    HStack {Text(slot.Date.isEmpty ? "\(slot.Index)차시" : slot.Date);Spacer();Text(slot.Mark.isEmpty ? (slot.Status.isEmpty ? "미등록" : slot.Status) : slot.Mark)}.font(.caption)
                                }
                            }.padding(.vertical,6)
                        }
                    } label: {VStack(alignment:.leading,spacing:4) {Text(row.Course.Name);Text(row.Course.Professor).font(.caption).foregroundStyle(.secondary)}}
                    .padding(14).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
                }
            }
        }.task(id:cdp) {await load()}
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
