import Foundation

@MainActor
struct SupabaseProfileRepository: ProfileRepository {
    let profileAPI: any ProfileAPIProtocol
    let contentAPI: any ProfileContentAPIProtocol
    let auth: any AuthRepository

    private func personID() async throws -> UUID {
        guard let user = try await auth.currentUser() else { throw BackendError.unauthenticated }
        return user.id
    }
    func fetchMyProfile() async throws -> Profile {
        do { return try ProfileMapper.map(await profileAPI.getMyProfile()) }
        catch { throw BackendError.map(error) }
    }
    func fetchProfile(personID: UUID) async throws -> PublicProfile {
        do { return try ProfileMapper.publicProfile(ProfileMapper.map(await profileAPI.getProfile(personID: personID))) }
        catch { throw BackendError.map(error) }
    }
    func createProfile(_ input: ProfileCreateInput) async throws -> Profile {
        do {
            let dto = try ProfileInsertDTO(id: await personID(),
                displayName: ProfileValidation.required(input.displayName, field: "displayName", max: 50),
                affiliation: ProfileValidation.optional(input.affiliation, field: "affiliation", max: 100),
                bio: ProfileValidation.optional(input.bio, field: "bio", max: 500),
                avatarPath: ProfileValidation.optional(input.avatarPath, field: "avatarPath", max: Int.max),
                isDiscoverable: input.isDiscoverable)
            return try ProfileMapper.map(await profileAPI.postProfile(dto))
        } catch { throw BackendError.map(error) }
    }
    func updateProfile(_ input: ProfileUpdateInput) async throws -> Profile {
        do {
            let dto = try ProfileUpdateDTO(
                displayName: ProfileValidation.required(input.displayName, field: "displayName", max: 50),
                affiliation: ProfileValidation.optional(input.affiliation, field: "affiliation", max: 100),
                bio: ProfileValidation.optional(input.bio, field: "bio", max: 500),
                avatarPath: ProfileValidation.optional(input.avatarPath, field: "avatarPath", max: Int.max),
                isDiscoverable: input.isDiscoverable)
            return try ProfileMapper.map(await profileAPI.patchProfile(dto))
        } catch { throw BackendError.map(error) }
    }
    func fetchContents(personID: UUID) async throws -> [ProfileContent] {
        do { return try ProfileContentMapper.sorted(await contentAPI.getContents(personID: personID).map(ProfileContentMapper.map)) }
        catch { throw BackendError.map(error) }
    }
    func createContent(_ input: ProfileContentCreateInput) async throws -> ProfileContent {
        do {
            let dto = try ProfileContentInsertDTO(profileID: await personID(), type: input.type,
                title: ProfileValidation.required(input.title, field: "title", max: 100),
                value: ProfileValidation.contentValue(input.value, type: input.type),
                unlockAfterSeconds: ProfileValidation.number(input.unlockAfterSeconds, field: "unlockAfterSeconds"),
                displayOrder: ProfileValidation.number(input.displayOrder, field: "displayOrder"), isPublic: input.isPublic)
            return try ProfileContentMapper.map(await contentAPI.postContent(dto))
        } catch { throw BackendError.map(error) }
    }
    func updateContent(id: UUID, input: ProfileContentUpdateInput) async throws -> ProfileContent {
        do {
            let dto = try ProfileContentUpdateDTO(type: input.type,
                title: ProfileValidation.required(input.title, field: "title", max: 100),
                value: ProfileValidation.contentValue(input.value, type: input.type),
                unlockAfterSeconds: ProfileValidation.number(input.unlockAfterSeconds, field: "unlockAfterSeconds"),
                displayOrder: ProfileValidation.number(input.displayOrder, field: "displayOrder"), isPublic: input.isPublic)
            return try ProfileContentMapper.map(await contentAPI.patchContent(id: id, input: dto))
        } catch { throw BackendError.map(error) }
    }
    func deleteContent(id: UUID) async throws {
        do { try await contentAPI.deleteContent(id: id) }
        catch { throw BackendError.map(error) }
    }
}
