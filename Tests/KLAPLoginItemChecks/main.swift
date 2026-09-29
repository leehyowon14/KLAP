import AppKit
import CoreServices
import ServiceManagement

@MainActor final class FakeLoginItem:LoginItemManaging {
    var status:SMAppService.Status = .notRegistered
    var registers=0,unregisters=0
    var failure=false,needsApproval=false
    func register() throws {
        registers+=1
        if failure {throw NSError(domain:"Test",code:1)}
        status=needsApproval ? .requiresApproval : .enabled
    }
    func unregister() async throws {
        unregisters+=1
        if failure {throw NSError(domain:"Test",code:2)}
        status = .notRegistered
    }
}
Task { @MainActor in
    let fake=FakeLoginItem()
    let controller=LoginItemController(service:fake)
    precondition(!controller.registered && fake.registers==0,"Initialization must not register")
    await controller.setEnabled(true)
    precondition(controller.registered && fake.registers==1 && controller.error==nil)
    await controller.setEnabled(true)
    precondition(fake.registers==1,"Already enabled must not re-register")
    fake.failure=true
    await controller.setEnabled(false)
    precondition(controller.registered && controller.error != nil && !controller.changing,"Failed unregister preserves real status")
    fake.failure=false
    await controller.setEnabled(false)
    precondition(!controller.registered && controller.error==nil)
    fake.needsApproval=true
    await controller.setEnabled(true)
    precondition(controller.status == .requiresApproval && controller.registered)
    await controller.setEnabled(true)
    precondition(fake.registers==2,"Approval pending must not register again")
    fake.status = .enabled;controller.refresh()
    precondition(controller.status == .enabled,"External system setting reflected")
    await controller.setEnabled(false)
    fake.failure=true
    await controller.setEnabled(true)
    precondition(!controller.registered && controller.error != nil,"Failed register stays off")
    fake.status = .notFound;controller.refresh()
    precondition(controller.status == .notFound && !controller.registered)
    precondition(!LoginLaunch.isLoginItem(nil))
    let normal=NSAppleEventDescriptor(eventClass:kCoreEventClass,eventID:kAEOpenApplication,targetDescriptor:nil,returnID:AEReturnID(kAutoGenerateReturnID),transactionID:AETransactionID(kAnyTransactionID))
    precondition(!LoginLaunch.isLoginItem(normal))
    normal.setParam(NSAppleEventDescriptor(enumCode:keyAELaunchedAsLogInItem),forKeyword:keyAEPropData)
    precondition(LoginLaunch.isLoginItem(normal),"Login launch stays in menu bar")
    let other=NSAppleEventDescriptor(eventClass:kCoreEventClass,eventID:kAEReopenApplication,targetDescriptor:nil,returnID:AEReturnID(kAutoGenerateReturnID),transactionID:AETransactionID(kAnyTransactionID))
    other.setParam(NSAppleEventDescriptor(enumCode:keyAELaunchedAsLogInItem),forKeyword:keyAEPropData)
    precondition(!LoginLaunch.isLoginItem(other))
    print("Login item enable/disable, pending approval, failures, external state and launch event checks passed")
    exit(0)
}
NSApplication.shared.run()
