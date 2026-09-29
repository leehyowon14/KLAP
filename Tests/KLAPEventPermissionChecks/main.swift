import AppKit
import EventKit
Task { @MainActor in
    var calls=0
    let full:EKAuthorizationStatus
    if #available(macOS 14.0, *) {full = .fullAccess} else {full = .authorized}
    for state:EKAuthorizationStatus in [.denied,.restricted,full,.notDetermined] {
        let result=await EventPermission.allowed(status:state,request:false) {calls+=1;return true}
        precondition(result == (state == full))
    }
    precondition(calls==0)
    for state:EKAuthorizationStatus in [.denied,.restricted] {
        let result=await EventPermission.allowed(status:state,request:true) {calls+=1;return true}
        precondition(!result)
    }
    precondition(calls==0)
    let granted=await EventPermission.allowed(status:.notDetermined,request:true) {calls+=1;return true}
    precondition(granted && calls==1)
    let rejected=await EventPermission.allowed(status:.notDetermined,request:true) {false}
    precondition(!rejected)
    let failed=await EventPermission.allowed(status:.notDetermined,request:true) {throw NSError(domain:"XPC",code:1)}
    precondition(!failed)
    if #available(macOS 14.0, *) {
        let writeOnly=await EventPermission.allowed(status:.writeOnly,request:false) {preconditionFailure()}
        precondition(!writeOnly)
        let upgraded=await EventPermission.allowed(status:.writeOnly,request:true) {true}
        precondition(upgraded)
    }
    print("Permission denial, restriction, no-prompt refresh, grant, rejection and XPC failure checks passed")
    exit(0)
}
NSApplication.shared.run()
