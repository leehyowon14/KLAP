import EventKit

@MainActor enum EventPermission {
    static func allowed(status:EKAuthorizationStatus, request:Bool, previouslyAllowed:Bool = false, prompt:() async throws -> Bool) async -> Bool {
        if #available(macOS 14.0, *) {
            if status == .fullAccess {return true}
        } else if status == .authorized {return true}
        // EventKit can still report notDetermined after its access callback succeeds.
        // Preserve that session's result, but never override a denial or restriction.
        if status == .notDetermined && previouslyAllowed {return true}
        guard status != .denied && status != .restricted && request else {return false}
        do {return try await prompt()} catch {return false}
    }
}
