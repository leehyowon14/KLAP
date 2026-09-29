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
    var sessionAllowed=granted
    for request in [false,false,true,false] {
        sessionAllowed=await EventPermission.allowed(status:.notDetermined,request:request,previouslyAllowed:sessionAllowed) {preconditionFailure("An approved session must not prompt again")}
        precondition(sessionAllowed)
    }
    for state:EKAuthorizationStatus in [.denied,.restricted] {
        for request in [false,true] {
            let revoked=await EventPermission.allowed(status:state,request:request,previouslyAllowed:true) {preconditionFailure()}
            precondition(!revoked)
        }
    }
    let independentPermission=await EventPermission.allowed(status:.notDetermined,request:false,previouslyAllowed:false) {preconditionFailure()}
    precondition(!independentPermission)
    let rejected=await EventPermission.allowed(status:.notDetermined,request:true) {false}
    precondition(!rejected)
    let failed=await EventPermission.allowed(status:.notDetermined,request:true) {throw NSError(domain:"XPC",code:1)}
    precondition(!failed)
    if #available(macOS 14.0, *) {
        let writeOnly=await EventPermission.allowed(status:.writeOnly,request:false) {preconditionFailure()}
        precondition(!writeOnly)
        let downgraded=await EventPermission.allowed(status:.writeOnly,request:false,previouslyAllowed:true) {preconditionFailure()}
        precondition(!downgraded)
        let upgraded=await EventPermission.allowed(status:.writeOnly,request:true) {true}
        precondition(upgraded)
    }
    print("Permission denial, restriction, no-prompt refresh, grant, rejection and XPC failure checks passed")
    exit(0)
}
NSApplication.shared.run()
