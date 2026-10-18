import Foundation

enum RichContentKind: String, Sendable {
    case text, image, video, url
}

enum MediaAddress {
    static func httpsURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
}

