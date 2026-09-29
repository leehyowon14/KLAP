import AppKit

@MainActor enum InstallationNotice {
    static func isInstalled(_ url:URL, home:URL = FileManager.default.homeDirectoryForCurrentUser)->Bool {
        let path=url.resolvingSymlinksInPath().standardizedFileURL.path
        return [URL(fileURLWithPath:"/Applications"),home.appendingPathComponent("Applications")].contains {
            path.hasPrefix($0.resolvingSymlinksInPath().standardizedFileURL.path + "/")
        }
    }
    // Stage the complete bundle before replacing anything; failed copies leave both apps intact.
    static func install(source:URL, destination:URL, replace:Bool) throws {
        let fm=FileManager.default
        let parent=destination.deletingLastPathComponent()
        try fm.createDirectory(at:parent,withIntermediateDirectories:true)
        guard source.standardizedFileURL != destination.standardizedFileURL else {return}
        let exists=fm.fileExists(atPath:destination.path)
        if exists && !replace {throw CocoaError(.fileWriteFileExists)}
        let stage=parent.appendingPathComponent(".KLAP-install-"+UUID().uuidString+".app")
        let backup=parent.appendingPathComponent(".KLAP-backup-"+UUID().uuidString+".app")
        defer {try? fm.removeItem(at:stage)}
        try fm.copyItem(at:source,to:stage)
        if exists {try fm.moveItem(at:destination,to:backup)}
        do {try fm.moveItem(at:stage,to:destination)}
        catch {
            if exists {try? fm.moveItem(at:backup,to:destination)}
            throw error
        }
        if exists {try? fm.trashItem(at:backup,resultingItemURL:nil)}
    }
    static func showIfNeeded(continueLaunch:@escaping ()->Void) {
        let source=Bundle.main.bundleURL
        guard !isInstalled(source), !UserDefaults.standard.bool(forKey:"installationMoveNoticeShown") else {continueLaunch();return}
        let name=Bundle.main.object(forInfoDictionaryKey:"CFBundleName") as? String ?? "KLAP"
        let fm=FileManager.default
        let folder=fm.isWritableFile(atPath:"/Applications") ? URL(fileURLWithPath:"/Applications") : fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let destination=folder.appendingPathComponent(name+".app")
        let alert=NSAlert()
        alert.messageText="\(name)을 응용 프로그램 폴더로 옮길까요?"
        alert.informativeText="현재 응용 프로그램 폴더 밖에서 실행 중입니다. ‘\(folder.path)’로 옮긴 뒤 다시 실행합니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle:"응용 프로그램으로 옮기기")
        alert.addButton(withTitle:"계속 사용")
        NSApp.activate(ignoringOtherApps:true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            UserDefaults.standard.set(true,forKey:"installationMoveNoticeShown")
            continueLaunch();return
        }
        let exists=fm.fileExists(atPath:destination.path)
        if exists {
            let confirmation=NSAlert()
            confirmation.messageText="기존 \(name)을 교체할까요?"
            confirmation.informativeText="응용 프로그램 폴더의 기존 앱을 교체합니다. 계정과 설정은 유지됩니다. 실행 중인 기존 앱은 먼저 종료해 주세요."
            confirmation.addButton(withTitle:"취소")
            confirmation.addButton(withTitle:"교체")
            guard confirmation.runModal() == .alertSecondButtonReturn else {continueLaunch();return}
            if NSWorkspace.shared.runningApplications.contains(where:{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.bundleURL?.standardizedFileURL == destination.standardizedFileURL}) {
                let error=NSAlert();error.messageText="기존 앱을 종료한 뒤 다시 시도해 주세요.";error.runModal();continueLaunch();return
            }
        }
        do {try install(source:source,destination:destination,replace:exists)}
        catch {showFailure(error);continueLaunch();return}
        let configuration=NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance=true
        NSWorkspace.shared.openApplication(at:destination,configuration:configuration) { application,error in
            DispatchQueue.main.async {
                guard application != nil, error == nil else {
                    showFailure(error ?? CocoaError(.executableNotLoadable));continueLaunch();return
                }
                // A read-only disk image can keep its source copy; the installed app is already running.
                try? FileManager.default.trashItem(at:source,resultingItemURL:nil)
                NSApp.terminate(nil)
            }
        }
    }
    private static func showFailure(_ error:Error) {
        let alert=NSAlert();alert.alertStyle = .warning
        alert.messageText="앱을 옮겨 실행하지 못했습니다."
        alert.informativeText="현재 위치에서 계속 실행합니다. \(error.localizedDescription)"
        alert.runModal()
    }
}
