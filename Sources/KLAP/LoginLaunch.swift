import AppKit
import CoreServices

enum LoginLaunch {
    static func isLoginItem(_ event:NSAppleEventDescriptor?)->Bool {
        event?.eventID == kAEOpenApplication &&
        event?.paramDescriptor(forKeyword:keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
