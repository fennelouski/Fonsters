import Foundation

/// Versioned product boundary, independent of appearance, care and CloudKit IDs.
/// No age/DOB/country is requested or persisted in the protected release.
nonisolated enum ProtectedPlayPolicy {
    static let version = 1
    static let experience = "Protected play"
    static let allowsThirdPartyRequests = false
    static let allowsAccounts = false
    static let allowsExternalAgents = false
    static let allowsPublicSocialProfiles = false

    enum AgeBoundary: Equatable {
        case protectedPlay
        case requiresCountryReview
        case requiresAccountReleaseReview
    }

    /// US COPPA boundary only, NOT an international signup permission. The
    /// future account release must establish audience classification, regional
    /// requirements and age assurance before enabling any account capability.
    static func boundary(age: Int?, country: String?) -> AgeBoundary {
        guard let age, (0...120).contains(age) else { return .protectedPlay }
        guard country?.uppercased() == "US" else { return .requiresCountryReview }
        return age < 13 ? .protectedPlay : .requiresAccountReleaseReview
    }
}

/// An adult-level UI task reduces accidental entry. It is never age assurance
/// or verifiable parental consent, and cannot enable accounts/third-party data.
nonisolated struct ParentChallenge: Identifiable, Equatable {
    let id = UUID()
    let first: Int
    let second: Int
    init(first: Int? = nil, second: Int? = nil) {
        let a = first ?? Int.random(in: 2...10)
        let b = second ?? Int.random(in: 2...10)
        self.first = a; self.second = b
    }
    var question: String { "What is \(first) × \(second)?" }
    func accepts(_ answer: String) -> Bool {
        Int(answer.trimmingCharacters(in: .whitespacesAndNewlines)) == first * second
    }
}
