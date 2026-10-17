import Foundation

enum LocalPersonIdentity {
    private static let storageKey = "Bloom.personID"

    /// Installation-local identity for the UWB slice. Account restoration is a later phase.
    static func load(defaults: UserDefaults = .standard) -> UUID {
        if let value = defaults.string(forKey: storageKey),
           let id = UUID(uuidString: value) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: storageKey)
        return id
    }
}
