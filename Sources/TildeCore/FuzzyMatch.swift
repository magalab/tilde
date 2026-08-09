import Foundation

public struct FuzzyMatch: Equatable, Sendable {
    public let score: Int
    public let matchedIndexes: [Int]

    public init(score: Int, matchedIndexes: [Int]) {
        self.score = score
        self.matchedIndexes = matchedIndexes
    }
}

public enum FuzzyMatcher {
    /// Returns a subsequence match. Higher scores represent better matches.
    public static func match(query: String, in candidate: String) -> FuzzyMatch? {
        let query = Array(query.lowercased())
        let candidate = Array(candidate.lowercased())
        guard !query.isEmpty else { return FuzzyMatch(score: 0, matchedIndexes: []) }
        guard !candidate.isEmpty else { return nil }

        var indexes: [Int] = []
        var candidateIndex = 0
        for queryCharacter in query {
            guard let index = candidate[candidateIndex...].firstIndex(of: queryCharacter) else {
                return nil
            }
            indexes.append(index)
            candidateIndex = index + 1
        }

        var score = 0
        for (offset, index) in indexes.enumerated() {
            if offset > 0, indexes[offset - 1] + 1 == index {
                score += 12
            }
            if index == 0 || isBoundary(candidate, at: index) {
                score += 10
            }
        }
        score -= max(0, candidate.count - query.count)
        score -= indexes.last ?? 0

        return FuzzyMatch(score: score, matchedIndexes: indexes)
    }

    private static func isBoundary(_ candidate: [Character], at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = candidate[index - 1]
        return previous == "/" || previous == "\\" || previous == "_" || previous == "-" || previous == " " || previous == "."
    }
}
