import Foundation

enum LicenseState: Equatable {
    case trialAvailable
    case trialUsed
    case licensed

    var canInstall: Bool {
        switch self {
        case .trialAvailable, .licensed: return true
        case .trialUsed:                 return false
        }
    }

    var statusLabel: String {
        switch self {
        case .trialAvailable: return "1 free trial available"
        case .trialUsed:      return "Trial used — activate license"
        case .licensed:       return "Licensed"
        }
    }
}
