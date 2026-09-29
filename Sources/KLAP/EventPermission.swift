import EventKit

@MainActor enum EventPermission {
    static func allowed(status:EKAuthorizationStatus, request:Bool, prompt:() async throws -> Bool) async -> Bool {
        if #available(macOS 14.0, *) {
            if status == .fullAccess {return true}
        } else if status == .authorized {return true}
        guard status != .denied && status != .restricted && request else {return false}
        do {return try await prompt()} catch {return false}
    }
}
