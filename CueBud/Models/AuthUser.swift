import Foundation

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let pictureURL: URL?
    var joinedAt: Date?
}
