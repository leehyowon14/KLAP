import SwiftUI
import KLAPCore

private struct MaterialSelection: Identifiable {
    let reference:BoardReference
    let title:String
    var id:String { reference.BoardNo+":"+reference.MasterNo }
}
struct MaterialsView:View {
    @ObservedObject var model:AppModel
    @ViewState<[Notice]> private var rows=[]
    @ViewState<Bool> private var loading=true
    @ViewState<String?> private var failure=nil
    @ViewState<Int> private var page=0
    @ViewState<MaterialSelection?> private var selected=nil
    private var pages:Int { max(1,(rows.count+2)/3) }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Label("강의자료",systemImage:"folder").font(.headline);Text("\(rows.count)").font(.caption).foregroundStyle(.secondary);Spacer() }
            if loading { ProgressView("강의자료를 불러오는 중…").controlSize(.small) }
            else if let failure {
                Text(failure).font(.callout).foregroundStyle(.secondary)
                Button("다시 시도") { Task { await load() } }.disabled(model.busy)
            } else if rows.isEmpty { Text("등록된 강의자료가 없습니다.").font(.callout).foregroundStyle(.secondary) }
            ForEach(Array(rows.dropFirst(page*3).prefix(3).enumerated()),id:\.offset) { index,row in
                if index>0 { Divider() }
                Button {
                    if let reference=model.boardReference(kind:"material") { selected=MaterialSelection(reference:reference.post(row),title:row.Title) }
                } label: {
                    HStack {
                        VStack(alignment:.leading,spacing:5) {
                            Text(row.Title).font(.system(size:13,weight:.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                            Text(boardMetadata(row.Author,row.Registered)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength:4);Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(model.busy)
            }
            if pages>1 {
                Divider()
                HStack {
                    Button {page-=1} label:{Image(systemName:"chevron.left").frame(width:28,height:28)}.disabled(page==0).accessibilityLabel("이전 강의자료 페이지")
                    Spacer();Text("\(page+1) / \(pages)").font(.caption).monospacedDigit().foregroundStyle(.secondary);Spacer()
                    Button {page+=1} label:{Image(systemName:"chevron.right").frame(width:28,height:28)}.disabled(page>=pages-1).accessibilityLabel("다음 강의자료 페이지")
                }.buttonStyle(.plain)
            }
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
            .task(id:"\(model.selectedCourse ?? "")-\(model.lastRefresh?.timeIntervalSince1970 ?? 0)"){await load()}
            .sheet(item:$selected){post in BoardDetailView(model:model,reference:post.reference,title:post.title)}
    }
    private func load() async {
        loading=true;failure=nil;rows=[];page=0
        defer{loading=false}
        guard let reference=model.boardReference(kind:"material") else { failure="과목 정보를 불러오지 못했습니다.";return }
        do {
            while model.busy { try await Task.sleep(nanoseconds:150_000_000) }
            try Task.checkCancellation()
            let result=try await model.boardValue("board-list",reference:reference,as:[Notice].self)
            guard !Task.isCancelled, model.boardReference(kind:"material") == reference else { return }
            rows=result
        } catch is CancellationError { }
        catch { failure=error.localizedDescription }
    }
}
