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

    var calendarStatus:EKAuthorizationStatus = .notDetermined
    var reminderStatus:EKAuthorizationStatus = .notDetermined
    var calendarPrompts=0,reminderPrompts=0
    var calendarAllowed=await EventPermission.allowed(status:calendarStatus,request:true) {
        calendarPrompts+=1;calendarStatus=full;return true
    }
    var reminderAllowed=await EventPermission.allowed(status:reminderStatus,request:true) {
        reminderPrompts+=1;return false
    }
    precondition(calendarAllowed && !reminderAllowed && calendarPrompts==1 && reminderPrompts==1,"Permissions are requested independently")
    // Model an authorization callback that succeeds before EventKit's status query catches up.
    calendarStatus = .notDetermined
    calendarAllowed=await EventPermission.allowed(status:calendarStatus,request:false,previouslyAllowed:calendarAllowed) {
        preconditionFailure("Read-only refresh must not prompt")
    }
    reminderAllowed=await EventPermission.allowed(status:reminderStatus,request:false,previouslyAllowed:reminderAllowed) {
        preconditionFailure("Read-only refresh must not prompt")
    }
    precondition(calendarAllowed && !reminderAllowed,"Refresh preserves the independently approved permission only")
    reminderAllowed=await EventPermission.allowed(status:reminderStatus,request:true,previouslyAllowed:reminderAllowed) {
        reminderPrompts+=1;reminderStatus=full;return true
    }
    precondition(calendarAllowed && reminderAllowed && calendarPrompts==1 && reminderPrompts==2,"Retry requests only the missing permission")
    reminderStatus = .denied
    reminderAllowed=await EventPermission.allowed(status:reminderStatus,request:false,previouslyAllowed:reminderAllowed) {
        preconditionFailure("Revoked permission must not prompt during refresh")
    }
    precondition(calendarAllowed && !reminderAllowed,"A denial clears only its own permission")

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
    print("Permission denial, partial grants, retries, stale status, revocation and XPC failure checks passed")
    exit(0)
}
NSApplication.shared.run()
