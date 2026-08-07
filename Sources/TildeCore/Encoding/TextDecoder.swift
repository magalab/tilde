import Foundation

public struct DecodedTextFile: Equatable, Sendable {
    public let text: String
    public let encoding: DetectedEncoding
    public let lineEndings: LineEndingProfile
    public let originalData: Data

    public init(
        text: String,
        encoding: DetectedEncoding,
        lineEndings: LineEndingProfile,
        originalData: Data
    ) {
        self.text = text
        self.encoding = encoding
        self.lineEndings = lineEndings
        self.originalData = originalData
    }
}

public enum TextDecoder {
    private static let utf8BOM = Data([0xEF, 0xBB, 0xBF])
    private static let utf16LEBOM = Data([0xFF, 0xFE])
    private static let utf16BEBOM = Data([0xFE, 0xFF])

    public static func decode(_ data: Data) throws -> DecodedTextFile {
        let decoded = try decodeString(data)
        guard !looksBinary(decoded.text) else {
            throw TextCodecError.suspectedBinaryFile
        }

        let normalized = LineEndingDetector.normalize(decoded.text)
        return DecodedTextFile(
            text: normalized.text,
            encoding: decoded.encoding,
            lineEndings: normalized.profile,
            originalData: data
        )
    }

    public static func decode(
        _ data: Data,
        using encoding: TextEncoding,
        bomPolicy: BOMPolicy = .absent
    ) throws -> DecodedTextFile {
        var body = data
        if bomPolicy == .present {
            body = removeExpectedBOM(from: body, encoding: encoding)
        }

        let text = try strictDecode(body, as: encoding)
        guard !looksBinary(text) else {
            throw TextCodecError.suspectedBinaryFile
        }

        let normalized = LineEndingDetector.normalize(text)
        return DecodedTextFile(
            text: normalized.text,
            encoding: DetectedEncoding(
                encoding: encoding,
                byteOrder: byteOrder(for: encoding),
                bomPolicy: bomPolicy,
                confidence: .certain
            ),
            lineEndings: normalized.profile,
            originalData: data
        )
    }

    public static func decode(
        _ data: Data,
        reopeningUsing encoding: TextEncoding
    ) throws -> DecodedTextFile {
        let bomPolicy: BOMPolicy = hasExpectedBOM(in: data, encoding: encoding) ? .present : .absent
        return try decode(data, using: encoding, bomPolicy: bomPolicy)
    }

    private static func decodeString(_ data: Data) throws -> (text: String, encoding: DetectedEncoding) {
        if data.starts(with: utf8BOM) {
            return (
                try strictUTF8(data.dropFirst(utf8BOM.count)),
                DetectedEncoding(
                    encoding: .utf8,
                    byteOrder: .none,
                    bomPolicy: .present,
                    confidence: .certain
                )
            )
        }

        if data.starts(with: utf16LEBOM) {
            return (
                try strictUTF16(data.dropFirst(utf16LEBOM.count), littleEndian: true),
                DetectedEncoding(
                    encoding: .utf16LittleEndian,
                    byteOrder: .littleEndian,
                    bomPolicy: .present,
                    confidence: .certain
                )
            )
        }

        if data.starts(with: utf16BEBOM) {
            return (
                try strictUTF16(data.dropFirst(utf16BEBOM.count), littleEndian: false),
                DetectedEncoding(
                    encoding: .utf16BigEndian,
                    byteOrder: .bigEndian,
                    bomPolicy: .present,
                    confidence: .certain
                )
            )
        }

        if let heuristicEncoding = likelyUTF16Encoding(for: data) {
            return (
                try strictDecode(data, as: heuristicEncoding),
                DetectedEncoding(
                    encoding: heuristicEncoding,
                    byteOrder: byteOrder(for: heuristicEncoding),
                    bomPolicy: .absent,
                    confidence: .heuristic
                )
            )
        }

        do {
            return (
                try strictUTF8(data),
                DetectedEncoding(
                    encoding: .utf8,
                    byteOrder: .none,
                    bomPolicy: .absent,
                    confidence: .high
                )
            )
        } catch {
            throw TextCodecError.unsupportedOrInvalidEncoding
        }
    }

    private static func strictDecode(_ data: Data, as encoding: TextEncoding) throws -> String {
        switch encoding {
        case .utf8:
            try strictUTF8(data)
        case .utf16LittleEndian:
            try strictUTF16(data, littleEndian: true)
        case .utf16BigEndian:
            try strictUTF16(data, littleEndian: false)
        }
    }

    private static func strictUTF8<D: DataProtocol>(_ bytes: D) throws -> String {
        let data = Data(bytes)
        guard let value = String(data: data, encoding: .utf8),
              value.data(using: .utf8) == data
        else {
            throw TextCodecError.unsupportedOrInvalidEncoding
        }
        return value
    }

    private static func strictUTF16<D: DataProtocol>(_ bytes: D, littleEndian: Bool) throws -> String {
        let data = Data(bytes)
        guard data.count.isMultiple(of: 2) else {
            throw TextCodecError.malformedUTF16
        }

        var units: [UInt16] = []
        units.reserveCapacity(data.count / 2)
        var index = data.startIndex
        while index < data.endIndex {
            let next = data.index(after: index)
            let first = UInt16(data[index])
            let second = UInt16(data[next])
            units.append(littleEndian ? first | (second << 8) : (first << 8) | second)
            index = data.index(next, offsetBy: 1)
        }

        try validateUTF16(units)
        return String(decoding: units, as: UTF16.self)
    }

    private static func validateUTF16(_ units: [UInt16]) throws {
        var index = 0
        while index < units.count {
            let unit = units[index]
            if (0xD800...0xDBFF).contains(unit) {
                guard index + 1 < units.count,
                      (0xDC00...0xDFFF).contains(units[index + 1])
                else {
                    throw TextCodecError.malformedUTF16
                }
                index += 2
            } else if (0xDC00...0xDFFF).contains(unit) {
                throw TextCodecError.malformedUTF16
            } else {
                index += 1
            }
        }
    }

    private static func likelyUTF16Encoding(for data: Data) -> TextEncoding? {
        guard data.count >= 4, data.count.isMultiple(of: 2) else { return nil }

        var evenZeroes = 0
        var oddZeroes = 0
        let pairs = data.count / 2
        for pair in 0..<pairs {
            if data[pair * 2] == 0 { evenZeroes += 1 }
            if data[pair * 2 + 1] == 0 { oddZeroes += 1 }
        }

        let evenRatio = Double(evenZeroes) / Double(pairs)
        let oddRatio = Double(oddZeroes) / Double(pairs)
        if oddRatio >= 0.3, evenRatio <= 0.1 { return .utf16LittleEndian }
        if evenRatio >= 0.3, oddRatio <= 0.1 { return .utf16BigEndian }
        return nil
    }

    private static func looksBinary(_ text: String) -> Bool {
        if text.unicodeScalars.contains(where: { $0.value == 0 }) {
            return true
        }

        let scalars = text.unicodeScalars.prefix(4_096)
        var disallowedControls = 0
        var total = 0
        for scalar in scalars {
            total += 1
            let value = scalar.value
            if value < 0x20, value != 0x09, value != 0x0A, value != 0x0C, value != 0x0D {
                disallowedControls += 1
            }
        }
        return total > 0 && Double(disallowedControls) / Double(total) > 0.02
    }

    private static func removeExpectedBOM(from data: Data, encoding: TextEncoding) -> Data {
        switch encoding {
        case .utf8 where data.starts(with: utf8BOM):
            Data(data.dropFirst(utf8BOM.count))
        case .utf16LittleEndian where data.starts(with: utf16LEBOM):
            Data(data.dropFirst(utf16LEBOM.count))
        case .utf16BigEndian where data.starts(with: utf16BEBOM):
            Data(data.dropFirst(utf16BEBOM.count))
        default:
            data
        }
    }

    private static func hasExpectedBOM(in data: Data, encoding: TextEncoding) -> Bool {
        switch encoding {
        case .utf8:
            data.starts(with: utf8BOM)
        case .utf16LittleEndian:
            data.starts(with: utf16LEBOM)
        case .utf16BigEndian:
            data.starts(with: utf16BEBOM)
        }
    }

    private static func byteOrder(for encoding: TextEncoding) -> ByteOrder {
        switch encoding {
        case .utf8: .none
        case .utf16LittleEndian: .littleEndian
        case .utf16BigEndian: .bigEndian
        }
    }
}
