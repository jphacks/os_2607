import Foundation

struct ProfileCreateInput: Codable {
    let displayName: String
    let affiliation: String
    let bio: String
    let avatarPath: String?
    let isDiscoverable: Bool
}

enum ProfileContentType: String, Codable {
    case text
}

struct ProfileContentCreateInput: Codable {
    let type: ProfileContentType
    let title: String
    let value: String
    let unlockAfterSeconds: Int
    let displayOrder: Int
    let isPublic: Bool
}

protocol ProfileRepository {
    func createProfile(_ input: ProfileCreateInput) async throws
    func createContent(_ input: ProfileContentCreateInput) async throws
}

/// Local adapter for the first-run flow until Supabase profile APIs are wired in.
struct LocalProfileRepository: ProfileRepository {
    func createProfile(_ input: ProfileCreateInput) async throws {
        UserDefaults.standard.set(input.displayName, forKey: "profileName")
        UserDefaults.standard.set(input.affiliation, forKey: "profileAffiliation")
        UserDefaults.standard.set(input.bio, forKey: "profileBio")
        UserDefaults.standard.set(input.isDiscoverable, forKey: "profileIsDiscoverable")
    }

    func createContent(_ input: ProfileContentCreateInput) async throws {
        var contents = (UserDefaults.standard.data(forKey: "profileContents")
            .flatMap { try? JSONDecoder().decode([ProfileContentCreateInput].self, from: $0) }) ?? []
        contents.append(input)
        UserDefaults.standard.set(try JSONEncoder().encode(contents), forKey: "profileContents")
    }
}
