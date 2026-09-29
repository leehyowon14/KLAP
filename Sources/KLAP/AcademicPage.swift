import SwiftUI

struct AcademicResult: Decodable {
    let Year: String
    let SourceURL: String
    let Events: [AcademicEntry]?
}
struct AcademicEntry: Decodable {
    let Month: String
    let Date: String
    let Title: String
    let Note: String
}

struct AcademicPage: View {
    @ObservedObject var model: AppModel
    @ViewState<Int> private var year = Calendar.current.component(.year, from: Date())
    @ViewState<AcademicResult?> private var result = nil
    @ViewState<String?> private var failure = nil
    @ViewState<Bool> private var loading = false
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Button { year -= 1 } label: { Image(systemName:"chevron.left") }.disabled(loading || year <= 1900).accessibilityLabel("이전 연도")
                Spacer(); Text("\(String(year))년").font(.headline); Spacer()
                Button { year += 1 } label: { Image(systemName:"chevron.right") }.disabled(loading || year >= 2100).accessibilityLabel("다음 연도")
            }
            if loading { ProgressView("학사일정을 불러오는 중…") }
            if let failure { Text(failure).foregroundStyle(.red); Button("다시 시도") { Task { await load() } }.disabled(loading) }
            if let result {
                if let url=URL(string:result.SourceURL),url.scheme == "https" { Link("학교 학사일정 원문 ↗",destination:url).font(.caption) }
                if (result.Events ?? []).isEmpty { Text("이 연도의 학사일정이 없습니다.").foregroundStyle(.secondary) }
                ForEach(Array((result.Events ?? []).enumerated()),id:\.offset) { _,entry in
                    VStack(alignment:.leading,spacing:5) {
                        Text("\(entry.Month)월 · \(entry.Date)").font(.caption).foregroundStyle(.secondary)
                        Text(entry.Title).font(.callout.weight(.medium))
                        if !entry.Note.isEmpty { Text(entry.Note).font(.caption).foregroundStyle(.secondary) }
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(14).background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
                }
            }
        }.task(id:year) { await load() }
    }
    private func load() async {
        loading=true;failure=nil;result=nil
        defer { loading=false }
        do { result=try await model.pageValue(["Command":"academic-list","Year":String(year)],as:AcademicResult.self) }
        catch is CancellationError { }
        catch { failure=error.localizedDescription }
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
