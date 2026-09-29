import AppKit

@MainActor enum InstallationNotice {
    static func isInstalled(_ url:URL, home:URL = FileManager.default.homeDirectoryForCurrentUser)->Bool {
        let path=url.resolvingSymlinksInPath().standardizedFileURL.path
        return [URL(fileURLWithPath:"/Applications"),home.appendingPathComponent("Applications")].contains {
            path.hasPrefix($0.resolvingSymlinksInPath().standardizedFileURL.path + "/")
        }
    }
    static func showIfNeeded() {
        guard !isInstalled(Bundle.main.bundleURL), !UserDefaults.standard.bool(forKey:"installationNoticeShown") else {return}
        let name=Bundle.main.object(forInfoDictionaryKey:"CFBundleName") as? String ?? "KLAP"
        let alert=NSAlert()
        alert.messageText="\(name)을 응용 프로그램 폴더로 옮겨주세요"
        alert.informativeText="현재 응용 프로그램 폴더 밖에서 실행 중입니다. 안정적인 자동 업데이트와 로그인 시 실행을 위해 앱을 Applications 폴더로 옮겨 사용하는 것을 권장합니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle:"응용 프로그램 폴더 열기")
        alert.addButton(withTitle:"계속 사용")
        NSApp.activate(ignoringOtherApps:true)
        let response=alert.runModal()
        UserDefaults.standard.set(true,forKey:"installationNoticeShown")
        if response == .alertFirstButtonReturn {NSWorkspace.shared.open(URL(fileURLWithPath:"/Applications"))}
    }
}
