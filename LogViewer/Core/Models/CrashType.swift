import SwiftUI

enum CrashType: String, CaseIterable, Codable, Sendable {
    case dyldError
    case exception
    case signal
    case resourceLimit
    case unknown

    var displayName: String {
        switch self {
        case .dyldError: return "Library Error"
        case .exception: return "Exception"
        case .signal: return "Signal"
        case .resourceLimit: return "Resource Limit"
        case .unknown: return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .dyldError: return "shippingbox"
        case .exception: return "exclamationmark.octagon"
        case .signal: return "bolt.horizontal"
        case .resourceLimit: return "memorychip"
        case .unknown: return "questionmark.diamond"
        }
    }

    var color: Color {
        switch self {
        case .dyldError: return .orange
        case .exception: return .red
        case .signal: return .yellow
        case .resourceLimit: return .purple
        case .unknown: return .secondary
        }
    }
}
