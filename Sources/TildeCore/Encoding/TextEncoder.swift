import Foundation

public enum TextEncoder {
    public static func encode(
        _ text: String,
        encoding: DetectedEncoding,
        lineEnding: LineEnding
    ) throws -> Data {
        let normalized = LineEndingDetector.normalize(text).text
        let output = lineEnding.apply(toNormalizedText: normalized)

        var result: Data
        switch encoding.encoding {
        case .utf8:
            result = Data(output.utf8)
        case .utf16LittleEndian:
            result = encodeUTF16(output, littleEndian: true)
        case .utf16BigEndian:
            result = encodeUTF16(output, littleEndian: false)
        }

        if encoding.bomPolicy == .present {
            result.insert(contentsOf: bom(for: encoding.encoding), at: 0)
        }
        return result
    }

    private static func encodeUTF16(_ text: String, littleEndian: Bool) -> Data {
        var data = Data()
        data.reserveCapacity(text.utf16.count * 2)
        for unit in text.utf16 {
            let high = UInt8((unit >> 8) & 0xFF)
            let low = UInt8(unit & 0xFF)
            if littleEndian {
                data.append(low)
                data.append(high)
            } else {
                data.append(high)
                data.append(low)
            }
        }
        return data
    }

    private static func bom(for encoding: TextEncoding) -> [UInt8] {
        switch encoding {
        case .utf8: [0xEF, 0xBB, 0xBF]
        case .utf16LittleEndian: [0xFF, 0xFE]
        case .utf16BigEndian: [0xFE, 0xFF]
        }
    }
}

