import Foundation

enum ProfileContentMapper {
    static func map(_ row: ProfileContentRowDTO) throws -> ProfileContent {
        ProfileContent(id: row.id, profileID: row.profileID, type: row.type, title: row.title,
                       value: row.value, unlockAfterSeconds: row.unlockAfterSeconds,
                       displayOrder: row.displayOrder, isPublic: row.isPublic,
                       createdAt: try ProfileMapper.date(row.createdAt), updatedAt: try ProfileMapper.date(row.updatedAt))
    }
    static func sorted(_ contents: [ProfileContent]) -> [ProfileContent] {
        contents.enumerated().sorted { a, b in
            if a.element.displayOrder != b.element.displayOrder { return a.element.displayOrder < b.element.displayOrder }
            if a.element.createdAt != b.element.createdAt { return a.element.createdAt < b.element.createdAt }
            return a.offset < b.offset
        }.map(\.element)
    }
}
