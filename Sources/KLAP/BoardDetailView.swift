import SwiftUI
import AppKit
import KLAPCore

struct BoardDetailView: View {
    @ObservedObject var model: AppModel
    let reference: BoardReference
    let title: String
    @Environment(\.dismiss) private var dismiss
    @ViewState<BoardDetail?> private var detail = nil
    @ViewState<String?> private var failure = nil
    @ViewState<Bool> private var loading = false
    @ViewState<String?> private var transferring = nil
    @ViewState<String?> private var fileError = nil
    @ViewState<URL?> private var saved = nil
    init(model:AppModel,reference:BoardReference,title:String,initialDetail:BoardDetail?=nil) {
        self.model=model;self.reference=reference;self.title=title
        _detail=ViewState(initialValue:initialDetail)
    }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text(reference.Kind == "notice" ? "공지" : "강의자료").font(.headline); Spacer(); Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction).disabled(transferring != nil) }
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    Text(title).font(.title3.bold()).textSelection(.enabled)
                    if let detail {
                        Text(boardMetadata(detail.Detail.Author,detail.Detail.Registered)).font(.caption).foregroundStyle(.secondary)
                        Divider()
                        Text(detail.Detail.ContentText.isEmpty ? "본문이 없습니다." : detail.Detail.ContentText).lineSpacing(5).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                        Divider()
                        HStack { Label("첨부파일",systemImage:"paperclip").font(.headline); Text("\(detail.Files?.count ?? 0)").foregroundStyle(.secondary) }
                        if let error=detail.FilesError, !error.isEmpty {
                            Text(error).font(.callout).foregroundStyle(.secondary)
                            Button("첨부파일 다시 불러오기") { Task { await load() } }.disabled(model.busy)
                        } else if (detail.Files ?? []).isEmpty { Text("첨부파일이 없습니다.").font(.callout).foregroundStyle(.secondary) }
                        ForEach(detail.Files ?? []) { file in
                            VStack(alignment:.leading,spacing:10) {
                                HStack(alignment:.top) {
                                    Image(systemName:"doc").foregroundStyle(.secondary)
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(file.Name).font(.callout.weight(.medium)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                                        Text(ByteCountFormatter.string(fromByteCount:file.Size,countStyle:.file)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength:0)
                                }
                                HStack {
                                    if transferring == file.id { ProgressView().controlSize(.small); Text("파일을 받는 중…").font(.caption).foregroundStyle(.secondary) }
                                    Spacer()
                                    if AttachmentManager.canPreview(file.Name) { Button("미리보기") { Task { await transfer(file,preview:true) } } }
                                    Button("다운로드") { Task { await transfer(file,preview:false) } }
                                }.disabled(model.busy || transferring != nil)
                            }.padding(12).background(Theme.canvas,in:RoundedRectangle(cornerRadius:10))
                        }
                        if let fileError { Text(fileError).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
                        if let saved {
                            HStack { Text("다운로드 폴더에 저장했습니다.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Finder에서 보기") { NSWorkspace.shared.activateFileViewerSelecting([saved]) } }
                        }
                    } else if loading { ProgressView("게시물을 불러오는 중…").frame(maxWidth:.infinity).padding() }
                    else {
                        Text(failure ?? "게시물을 불러오지 못했습니다.").foregroundStyle(.secondary)
                        Button("다시 시도") { Task { await load() } }.disabled(model.busy)
                    }
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
        }.padding(20).frame(width:460,height:560).background(Theme.surface)
            .task { if detail == nil { await load() } }
    }
    private func load() async {
        loading=true;failure=nil;defer{loading=false}
        do { detail=try await model.boardValue("board-detail",reference:reference,as:BoardDetail.self) }
        catch { failure=error.localizedDescription }
    }
    private func transfer(_ file:BoardFile,preview:Bool) async {
        transferring=file.id;fileError=nil;saved=nil;defer{transferring=nil}
        do { let url=try await model.attachment(file,reference:reference,preview:preview); if !preview { saved=url } }
        catch { fileError=error.localizedDescription }
    }
}
func boardMetadata(_ author:String?,_ raw:String?) -> String {
    let formatter=ISO8601DateFormatter()
    let date=raw.flatMap { formatter.date(from:$0) }
    return [author,date?.formatted(date:.abbreviated,time:.omitted)].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")
}
