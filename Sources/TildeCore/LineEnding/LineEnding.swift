import Foundation

public enum LineEnding: String, CaseIterable, Codable, Sendable {
    case lf
    case crlf
    case cr

    public var sequence: String {
        switch self {
        case .lf: "\n"
        case .crlf: "\r\n"
        case .cr: "\r"
        }
    }

    public var localizedName: String {
        switch self {
        case .lf: "LF"
        case .crlf: "CRLF"
        case .cr: "CR"
        }
    }

    public func apply(toNormalizedText text: String) -> String {
        guard self != .lf else { return text }
        return text.replacingOccurrences(of: "\n", with: sequence)
    }
}

public enum LineEndingKind: Equatable, Sendable {
    case none
    case uniform(LineEnding)
    case mixed
}

public struct LineEndingProfile: Equatable, Codable, Sendable {
    public var lfCount: Int
    public var crlfCount: Int
    public var crCount: Int

    public init(lfCount: Int = 0, crlfCount: Int = 0, crCount: Int = 0) {
        self.lfCount = lfCount
        self.crlfCount = crlfCount
        self.crCount = crCount
    }

    public var totalCount: Int { lfCount + crlfCount + crCount }

    public var kind: LineEndingKind {
        let present = LineEnding.allCases.filter { count(for: $0) > 0 }
        return switch present.count {
        case 0: .none
        case 1: .uniform(present[0])
        default: .mixed
        }
    }

    public var dominant: LineEnding {
        LineEnding.allCases.max { lhs, rhs in
            let left = count(for: lhs)
            let right = count(for: rhs)
            if left == right {
                return tieBreakRank(lhs) > tieBreakRank(rhs)
            }
            return left < right
        } ?? .lf
    }

    public func count(for ending: LineEnding) -> Int {
        switch ending {
        case .lf: lfCount
        case .crlf: crlfCount
        case .cr: crCount
        }
    }

    private func tieBreakRank(_ ending: LineEnding) -> Int {
        switch ending {
        case .lf: 0
        case .crlf: 1
        case .cr: 2
        }
    }
}

public struct NormalizedText: Equatable, Sendable {
    public let text: String
    public let profile: LineEndingProfile
}
