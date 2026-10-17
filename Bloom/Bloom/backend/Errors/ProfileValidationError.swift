import Foundation

enum ProfileValidationError: Error, Equatable, Sendable {
    case required(String)
    case tooLong(String, Int)
    case invalidURL
    case negativeNumber(String)
    case numberTooLarge(String)
}

enum ProfileValidation {
    static func required(_ value: String, field: String, max: Int) throws -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ProfileValidationError.required(field) }
        guard value.unicodeScalars.count <= max else { throw ProfileValidationError.tooLong(field, max) }
        return value
    }
    static func optional(_ value: String?, field: String, max: Int) throws -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        guard value.unicodeScalars.count <= max else { throw ProfileValidationError.tooLong(field, max) }
        return value
    }
    static func contentValue(_ value: String, type: ProfileContentType) throws -> String {
        let value = try required(value, field: "value", max: 2000)
        if type != .text {
            guard let url = URLComponents(string: value),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty,
                  url.user == nil, url.password == nil,
                  !value.contains(where: { $0.isWhitespace }) else { throw ProfileValidationError.invalidURL }
        }
        return value
    }
    static func number(_ value: Int, field: String) throws -> Int {
        guard value >= 0 else { throw ProfileValidationError.negativeNumber(field) }
        guard value <= Int32.max else { throw ProfileValidationError.numberTooLarge(field) }
        return value
    }
}
