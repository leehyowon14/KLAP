import SwiftUI
import AppKit
import KLAPCore

struct BoardDetailView: View {
    @ObservedObject var model: AppModel
    let reference: BoardReference
    let title: String
    let onClose: () -> Void
    @ViewState<BoardDetail?> private var detail = nil
    @ViewState<CGFloat> private var bodyHeight = 40
    @ViewState<String?> private var failure = nil
    @ViewState<Bool> private var loading = false
    @ViewState<String?> private var transferring = nil
    @ViewState<String?> private var fileError = nil
    @ViewState<URL?> private var saved = nil
    init(model:AppModel,reference:BoardReference,title:String,initialDetail:BoardDetail?=nil,onClose:@escaping () -> Void = {}) {
        self.model=model;self.reference=reference;self.title=title;self.onClose=onClose
        _detail=ViewState(initialValue:initialDetail)
    }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text(reference.Kind == "notice" ? "공지" : "강의자료").font(.headline); Spacer(); Button("닫기",action:onClose).keyboardShortcut(.cancelAction).disabled(transferring != nil) }
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    Text(title).font(.title3.bold()).textSelection(.enabled)
                    if let detail {
                        Text(boardMetadata(detail.Detail.Author,detail.Detail.Registered)).font(.caption).foregroundStyle(.secondary)
                        Divider()
                        if let html=detail.Detail.ContentHTML, !html.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                            BoardHTMLView(html:html,height:$bodyHeight).frame(height:bodyHeight)
                        } else {
                        Text(LinkedBody.attributed(detail.Detail.ContentText.isEmpty ? "본문이 없습니다." : detail.Detail.ContentText)).lineSpacing(5).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                        }
                        if let url=originalURL { Link("KLAS에서 원문 보기 ↗",destination:url).font(.caption).buttonStyle(.plain) }
                        Divider()
                        HStack { Label("첨부파일",systemImage:"paperclip").font(.headline); Text("\(detail.Files?.count ?? 0)").foregroundStyle(.secondary) }
                        if let error=detail.FilesError, !error.isEmpty {
                            Text(error).font(.callout).foregroundStyle(.secondary)
                            Button("첨부파일 다시 불러오기") { Task { await load() } }.disabled(model.busy)
                        } else if (detail.Files ?? []).isEmpty { Text("첨부파일이 없습니다.").font(.callout).foregroundStyle(.secondary) }
                        ForEach(detail.Files ?? []) { file in
                            HStack(spacing:10) {
                                Image(systemName:"doc").font(.system(size:18)).foregroundStyle(.secondary)
                                VStack(alignment:.leading,spacing:4) {
                                    Text(file.Name).font(.system(size:13,weight:.medium)).lineLimit(2).help(file.Name).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                                    Text(ByteCountFormatter.string(fromByteCount:file.Size,countStyle:.file)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength:0)
                                if transferring == file.id {
                                    ProgressView().controlSize(.small).frame(width:28,height:28).help("파일을 받는 중…")
                                } else {
                                    if AttachmentManager.canPreview(file.Name) {
                                        Button("미리보기") { Task { await transfer(file,preview:true) } }
                                            .font(.caption).foregroundStyle(.secondary).buttonStyle(.plain).fixedSize()
                                            .accessibilityLabel("\(file.Name) 미리보기")
                                    }
                                    Button { Task { await transfer(file,preview:false) } } label: {
                                        Image(systemName:"arrow.down.to.line").font(.system(size:14,weight:.medium)).frame(width:28,height:28).contentShape(Rectangle())
                                    }.buttonStyle(.plain).help("다운로드").accessibilityLabel("\(file.Name) 다운로드")
                                }
                            }.disabled(model.busy || transferring != nil)
                                .padding(.horizontal,12).padding(.vertical,12)
                                .background(Theme.canvas.opacity(0.35),in:RoundedRectangle(cornerRadius:10))
                                .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(Theme.line.opacity(0.4),lineWidth:0.5))
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
        }.buttonStyle(FormButtonStyle(compact:true)).foregroundStyle(Theme.ink)
            .padding(20).frame(width:460,height:560).background(Theme.surface,in:RoundedRectangle(cornerRadius:16))
            .task { if detail == nil { await load() } }
    }
    private var originalURL:URL? {
        let board=reference.Kind == "notice" ? "d052b8f845784c639f036b102fdc3023" : "6972896bfe72408eb72926780e85d041"
        var url=URLComponents(string:"https://klas.kw.ac.kr/std/lis/sport/\(board)/BoardViewStdPage.do")
        url?.queryItems=[URLQueryItem(name:"selectYearhakgi",value:reference.TermValue),URLQueryItem(name:"selectSubj",value:reference.SubjectID),URLQueryItem(name:"boardNo",value:reference.BoardNo),URLQueryItem(name:"masterNo",value:reference.MasterNo)]
        return url?.url
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


struct BoardOverlay<Content:View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.18).contentShape(Rectangle())
            content().compositingGroup().shadow(color:.black.opacity(0.15),radius:18,y:6)
        }.clipShape(RoundedRectangle(cornerRadius:18,style:.continuous))
    }
}
