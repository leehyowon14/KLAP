import AppKit
import Combine
import ServiceManagement

@MainActor protocol LoginItemManaging {
    var status:SMAppService.Status {get}
    func register() throws
    func unregister() async throws
}
@MainActor struct SystemLoginItem:LoginItemManaging {
    var status:SMAppService.Status {SMAppService.mainApp.status}
    func register() throws {try SMAppService.mainApp.register()}
    func unregister() async throws {try await SMAppService.mainApp.unregister()}
}

@MainActor final class LoginItemController:ObservableObject {
    @Published private(set) var status:SMAppService.Status
    @Published private(set) var changing=false
    @Published private(set) var error:String?
    private let service:any LoginItemManaging
    private var activation:AnyCancellable?
    var registered:Bool {status == .enabled || status == .requiresApproval}
    init(service:(any LoginItemManaging)?=nil) {
        let service=service ?? SystemLoginItem()
        self.service=service;status=service.status
        activation=NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification).sink {[weak self] _ in self?.refresh()}
    }
    func refresh(){status=service.status}
    func setEnabled(_ enabled:Bool) async {
        guard !changing else {return}
        changing=true;error=nil
        defer {refresh();changing=false}
        refresh()
        do {
            if enabled {
                if status == .requiresApproval {return}
                if status != .enabled {try service.register()}
            } else if status == .enabled || status == .requiresApproval {
                try await service.unregister()
            }
        } catch {self.error=error.localizedDescription}
    }
    func openSettings(){SMAppService.openSystemSettingsLoginItems()}
}
