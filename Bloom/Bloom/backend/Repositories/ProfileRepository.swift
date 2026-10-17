import Foundation

@MainActor
protocol ProfileRepository {
    func fetchMyProfile() async throws -> Profile
    func fetchProfile(personID: UUID) async throws -> PublicProfile
    func createProfile(_ input: ProfileCreateInput) async throws -> Profile
    func updateProfile(_ input: ProfileUpdateInput) async throws -> Profile
    func fetchContents(personID: UUID) async throws -> [ProfileContent]
    func createContent(_ input: ProfileContentCreateInput) async throws -> ProfileContent
    func updateContent(id: UUID, input: ProfileContentUpdateInput) async throws -> ProfileContent
    func deleteContent(id: UUID) async throws
}
