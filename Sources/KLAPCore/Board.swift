import Foundation

public struct BoardReference: Codable, Hashable {
    public let Kind: String
    public let TermValue: String
    public let SubjectID: String
    public let BoardNo: String
    public let MasterNo: String
    public init(kind: String, term: String, subject: String, board: String = "", master: String = "") {
        Kind=kind; TermValue=term; SubjectID=subject; BoardNo=board; MasterNo=master
    }
    public var request: [String: Any] {
        ["Kind":Kind,"TermValue":TermValue,"SubjectID":SubjectID,"BoardNo":BoardNo,"MasterNo":MasterNo]
    }
    public func post(_ notice: Notice) -> BoardReference {
        BoardReference(kind:Kind,term:TermValue,subject:SubjectID,board:notice.BoardNo ?? "",master:notice.MasterNo ?? "")
    }
}
public struct BoardFile: Codable, Identifiable {
    public let FileSN: String
    public let Name: String
    public let Size: Int64
    public var id: String { FileSN }
}
public struct BoardDetail: Decodable {
    public let Detail: NoticeContent
    public let Files: [BoardFile]?
    public let FilesError: String?
}
public struct BoardDownload: Decodable { public let Path: String }
