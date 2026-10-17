import Foundation

enum LocalPersonIdentity {
    /// Installation-local identity for the UWB slice. Account restoration is a later phase.
    static func load(defaults: UserDefaults = .standard) -> UUID {
        let key = "Bloom.personID"
        if let value = defaults.string(forKey: key), let id = UUID(uuidString: value) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return id
    }
}
