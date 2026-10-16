import CoreLocation
import Foundation

public struct Store: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }

    public let name: String
    public let address: String
    public let phone: String
    public let lat: Double
    public let lng: Double
    /// Wi-Fi password candidates derived from the phone number, most likely first.
    public let passwords: [String]

    public var city: String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstWord = String(trimmed.split(separator: " ").first ?? "其他")
        let standardized = firstWord.replacingOccurrences(of: "臺", with: "台")
        // Check for 3-character city prefix like 台北市, 新北市, etc.
        if standardized.count >= 3 {
            return String(standardized.prefix(3))
        }
        return standardized
    }

    public var location: CLLocation? {
        (lat == 0 || lng == 0) ? nil : CLLocation(latitude: lat, longitude: lng)
    }

    public func distance(from userLocation: CLLocation?) -> Double? {
        guard let location, let userLocation else { return nil }
        return location.distance(from: userLocation)
    }

    public func formattedDistance(from userLocation: CLLocation?) -> String {
        guard let meters = distance(from: userLocation) else { return "未知距離" }
        if meters < 1000 {
            return "\(Int(meters)) 公尺"
        } else {
            return String(format: "%.1f 公里", meters / 1000.0)
        }
    }
}
