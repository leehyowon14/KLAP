import SwiftUI
import KLAPCore

struct NoticesView: View {
    @ObservedObject var model: AppModel
    @ViewState<NoticeRow?> private var selected = nil
    @ViewState<Bool> private var expanded = false
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
                if rows.count > 3 {
                    Button(expanded ? "접기" : "전체 보기") { expanded.toggle() }.buttonStyle(.plain)
                        .font(.caption).foregroundStyle(Color.accentColor)
                }
            }
            if rows.isEmpty {
                Text(model.snapshot.notices == nil ? "공지를 불러오지 못했습니다. 새로고침해 주세요." : "등록된 공지가 없습니다.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array((expanded ? rows : Array(rows.prefix(3))).enumerated()), id: \.element.id) { index, row in
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
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .sheet(item: $selected) { row in NoticeDetailView(model: model, row: row) }
    }
}

private func noticeMetadata(_ author: String?, _ raw: String?) -> String {
    let date = raw.flatMap { ISO8601DateFormatter().date(from: $0) }
    return [author, date?.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
}

private struct NoticeDetailView: View {
    @ObservedObject var model: AppModel
    let row: NoticeRow
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("공지").font(.headline); Spacer(); Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(row.Notice.Title).font(.title3.bold()).textSelection(.enabled)
                    Text(noticeMetadata(row.Notice.Author, row.Notice.Registered)).font(.caption).foregroundStyle(.secondary)
                    Divider()
                    if let result = model.noticeDetail, result.ID == row.ID {
                        Text(result.Detail.ContentText.isEmpty ? "본문이 없습니다. 원문에서 이미지·첨부파일을 확인해 주세요." : result.Detail.ContentText)
                            .font(.body).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        if let url = URL(string: result.DetailURL), url.scheme == "https", url.host == "klas.kw.ac.kr" {
                            Link("KLAS에서 원문·첨부파일 보기 ↗", destination: url).font(.callout)
                        }
                    } else if model.busy {
                        ProgressView("공지를 불러오는 중…").frame(maxWidth: .infinity).padding()
                    } else {
                        Text(model.error ?? "공지를 불러오지 못했습니다.").foregroundStyle(.secondary)
                        Button("다시 시도") { Task { await model.loadNotice(row.ID) } }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(20).frame(width: 460, height: 480).background(Theme.surface)
            .task { await model.loadNotice(row.ID) }
    }
}
