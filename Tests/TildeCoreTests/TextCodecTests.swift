import Foundation
import XCTest
@testable import TildeCore

final class TextCodecTests: XCTestCase {
    func testUTF8RoundTripWithoutBOM() throws {
        let source = Data("Hello, 世界\nEmoji: 🐈\n".utf8)
        let decoded = try TextDecoder.decode(source)

        XCTAssertEqual(decoded.text, "Hello, 世界\nEmoji: 🐈\n")
        XCTAssertEqual(decoded.encoding, .newDocumentUTF8.withConfidence(.high))
        XCTAssertEqual(decoded.lineEndings.kind, .uniform(.lf))
        XCTAssertEqual(
            try TextEncoder.encode(decoded.text, encoding: decoded.encoding, lineEnding: .lf),
            source
        )
    }

    func testUTF8BOMIsPreserved() throws {
        let source = Data([0xEF, 0xBB, 0xBF]) + Data("hello".utf8)
        let decoded = try TextDecoder.decode(source)

        XCTAssertEqual(decoded.encoding.bomPolicy, .present)
        XCTAssertEqual(decoded.encoding.encoding, .utf8)
        XCTAssertEqual(
            try TextEncoder.encode(decoded.text, encoding: decoded.encoding, lineEnding: .lf),
            source
        )
    }

    func testUTF16LittleEndianRoundTripWithSurrogatePair() throws {
        let encoding = DetectedEncoding(
            encoding: .utf16LittleEndian,
            byteOrder: .littleEndian,
            bomPolicy: .present,
            confidence: .certain
        )
        let source = try TextEncoder.encode("A🐈B\r\n", encoding: encoding, lineEnding: .crlf)
        let decoded = try TextDecoder.decode(source)

        XCTAssertEqual(decoded.text, "A🐈B\n")
        XCTAssertEqual(decoded.encoding, encoding)
        XCTAssertEqual(decoded.lineEndings.kind, .uniform(.crlf))
        XCTAssertEqual(
            try TextEncoder.encode(decoded.text, encoding: decoded.encoding, lineEnding: .crlf),
            source
        )
    }

    func testUTF16BigEndianRoundTrip() throws {
        let encoding = DetectedEncoding(
            encoding: .utf16BigEndian,
            byteOrder: .bigEndian,
            bomPolicy: .present,
            confidence: .certain
        )
        let source = try TextEncoder.encode("中文\r", encoding: encoding, lineEnding: .cr)
        let decoded = try TextDecoder.decode(source)

        XCTAssertEqual(decoded.text, "中文\n")
        XCTAssertEqual(decoded.encoding, encoding)
        XCTAssertEqual(decoded.lineEndings.kind, .uniform(.cr))
    }

    func testDetectsASCIILikeUTF16WithoutBOM() throws {
        let littleEndian = DetectedEncoding(
            encoding: .utf16LittleEndian,
            byteOrder: .littleEndian,
            bomPolicy: .absent,
            confidence: .certain
        )
        let source = try TextEncoder.encode("hello\n", encoding: littleEndian, lineEnding: .lf)
        let decoded = try TextDecoder.decode(source)

        XCTAssertEqual(decoded.text, "hello\n")
        XCTAssertEqual(decoded.encoding.encoding, .utf16LittleEndian)
        XCTAssertEqual(decoded.encoding.confidence, .heuristic)
    }

    func testRejectsInvalidUTF8() {
        XCTAssertThrowsError(try TextDecoder.decode(Data([0xC3, 0x28]))) { error in
            XCTAssertEqual(error as? TextCodecError, .unsupportedOrInvalidEncoding)
        }
    }

    func testRejectsMalformedUTF16Surrogate() {
        let data = Data([0xFF, 0xFE, 0x00, 0xD8])
        XCTAssertThrowsError(try TextDecoder.decode(data)) { error in
            XCTAssertEqual(error as? TextCodecError, .malformedUTF16)
        }
    }

    func testRejectsNULContainingUTF8AsBinary() {
        XCTAssertThrowsError(try TextDecoder.decode(Data([0x41, 0x00, 0x42]))) { error in
            XCTAssertEqual(error as? TextCodecError, .suspectedBinaryFile)
        }
    }

    func testFuzzStyleValidUnicodeRoundTripsAcrossEncodings() throws {
        var generator = DeterministicGenerator(seed: 0x5449_4C44_45)
        let tokens = ["a", "Z", "0", " ", "\t", "你", "🐈", "é"]

        for _ in 0..<200 {
            var normalized = ""
            for _ in 0..<generator.nextInt(upperBound: 80) {
                if generator.nextInt(upperBound: 9) == 0 {
                    normalized.append("\n")
                } else {
                    normalized.append(tokens[generator.nextInt(upperBound: tokens.count)])
                }
            }

            for encoding in TextEncoding.allCases {
                for bomPolicy in [BOMPolicy.absent, .present] {
                    let detected = DetectedEncoding(
                        encoding: encoding,
                        byteOrder: encoding == .utf16LittleEndian
                            ? .littleEndian
                            : encoding == .utf16BigEndian ? .bigEndian : .none,
                        bomPolicy: bomPolicy,
                        confidence: .certain
                    )
                    let lineEnding = LineEnding.allCases[generator.nextInt(
                        upperBound: LineEnding.allCases.count
                    )]
                    let encoded = try TextEncoder.encode(
                        normalized,
                        encoding: detected,
                        lineEnding: lineEnding
                    )
                    let decoded = try TextDecoder.decode(
                        encoded,
                        using: encoding,
                        bomPolicy: bomPolicy
                    )

                    XCTAssertEqual(decoded.text, normalized)
                    XCTAssertEqual(decoded.encoding.encoding, encoding)
                    XCTAssertEqual(decoded.encoding.bomPolicy, bomPolicy)
                }
            }
        }
    }

    func testFuzzStyleArbitraryBytesNeverProduceUnnormalizedText() {
        var generator = DeterministicGenerator(seed: 0xC0DE_CAFE)

        for _ in 0..<1_000 {
            let length = generator.nextInt(upperBound: 128)
            let data = Data((0..<length).map { _ in UInt8(truncatingIfNeeded: generator.next()) })
            if let decoded = try? TextDecoder.decode(data) {
                XCTAssertFalse(decoded.text.unicodeScalars.contains { $0.value == 0x0D })
                XCTAssertEqual(LineEndingDetector.normalize(decoded.text).text, decoded.text)
            }
        }
    }

    func testTruncatedBOMAndUnicodeSequencesAreRejected() {
        let malformed: [Data] = [
            Data([0xEF]),
            Data([0xEF, 0xBB]),
            Data([0xEF, 0xBB, 0xBF, 0xF0, 0x9F]),
            Data([0xFF]),
            Data([0xFF, 0xFE, 0x00, 0xD8]),
            Data([0xFE, 0xFF, 0xD8, 0x00]),
        ]

        for data in malformed {
            XCTAssertThrowsError(try TextDecoder.decode(data))
        }
    }
}

private struct DeterministicGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

private extension DetectedEncoding {
    func withConfidence(_ confidence: EncodingConfidence) -> DetectedEncoding {
        var copy = self
        copy.confidence = confidence
        return copy
    }
}
