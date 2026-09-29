import SwiftUI
import KLAPCore

struct NoticesView: View {
    @ObservedObject var model: AppModel
    @ViewState<NoticeRow?> private var selected = nil
    @ViewState<Int> private var page = 0
    private var pageCount: Int { max(1, (rows.count + 2) / 3) }
    private var currentPage: Int { min(page, pageCount - 1) }
    private var rows: [NoticeRow] {
        (model.snapshot.notices ?? []).filter { $0.CourseName == model.selectedCourse }
            .sorted { a, b in
                if (a.Notice.Top ?? false) != (b.Notice.Top ?? false) { return a.Notice.Top ?? false }
                return (a.Notice.Registered ?? "") > (b.Notice.Registered ?? "")
            }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("공지", systemImage: "megaphone").font(.headline)
                Text("\(rows.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()

            }
            if rows.isEmpty {
                Text(model.snapshot.notices == nil ? "공지를 불러오지 못했습니다. 새로고침해 주세요." : "등록된 공지가 없습니다.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(Array(rows.dropFirst(currentPage * 3).prefix(3)).enumerated()), id: \.element.id) { index, row in
                if index > 0 { Rectangle().fill(Theme.line).frame(height: 0.5) }
                Button { selected = row } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                if row.Notice.Top == true { Image(systemName: "pin.fill").font(.caption).foregroundStyle(Color.accentColor) }
                                Text(row.Notice.Title).font(.system(size: 13, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Text(noticeMetadata(row.Notice.Author, row.Notice.Registered)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(model.busy)
            }
            if pageCount > 1 {
                Divider()
                HStack {
                    Button { page = max(0, currentPage - 1) } label: { Image(systemName:"chevron.left").frame(width:28,height:28) }
                        .disabled(currentPage == 0).accessibilityLabel("이전 공지 페이지")
                    Spacer()
                    Text("\(currentPage + 1) / \(pageCount)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    Button { page = min(pageCount - 1, currentPage + 1) } label: { Image(systemName:"chevron.right").frame(width:28,height:28) }
                        .disabled(currentPage == pageCount - 1).accessibilityLabel("다음 공지 페이지")
                }.buttonStyle(.plain)
            }
        }.onChange(of: model.selectedCourse) { _ in page = 0 }
            .onChange(of: rows.map(\.id)) { _ in page = 0 }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .sheet(item: $selected) { row in
                if let reference=model.boardReference(kind:"notice") { BoardDetailView(model:model,reference:reference.post(row.Notice),title:row.Notice.Title) }
            }
    }
}

private func noticeMetadata(_ author: String?, _ raw: String?) -> String {
    let date = raw.flatMap { ISO8601DateFormatter().date(from: $0) }
    return [author, date?.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
}
