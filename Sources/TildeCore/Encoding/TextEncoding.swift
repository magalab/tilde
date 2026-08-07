import Foundation

public enum TextEncoding: String, CaseIterable, Codable, Sendable {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian

    public var localizedName: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf16LittleEndian: "UTF-16 LE"
        case .utf16BigEndian: "UTF-16 BE"
        }
    }
}

public enum ByteOrder: String, Codable, Sendable {
    case none
    case littleEndian
    case bigEndian
}

public enum BOMPolicy: String, Codable, Sendable {
    case absent
    case present
}

public enum EncodingConfidence: String, Codable, Sendable {
    case certain
    case high
    case heuristic
}

public struct DetectedEncoding: Equatable, Codable, Sendable {
    public var encoding: TextEncoding
    public var byteOrder: ByteOrder
    public var bomPolicy: BOMPolicy
    public var confidence: EncodingConfidence

    public init(
        encoding: TextEncoding,
        byteOrder: ByteOrder,
        bomPolicy: BOMPolicy,
        confidence: EncodingConfidence
    ) {
        self.encoding = encoding
        self.byteOrder = byteOrder
        self.bomPolicy = bomPolicy
        self.confidence = confidence
    }

    public static let newDocumentUTF8 = DetectedEncoding(
        encoding: .utf8,
        byteOrder: .none,
        bomPolicy: .absent,
        confidence: .certain
    )
}

