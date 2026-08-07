import AppKit
import Darwin
import Foundation
import TildeCore
import TildeDocument
import TildeMarkdown
import TildeQuickLook

@main
struct TildeBenchmark {
    @MainActor
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsageAndExit()
        }

        switch command {
        case "environment":
            printEnvironment()
        case "editor":
            guard arguments.count == 2, let byteCount = Int(arguments[1]), byteCount > 0 else {
                printUsageAndExit()
            }
            try benchmarkEditor(byteCount: byteCount)
        case "markdown":
            guard arguments.count == 2, let byteCount = Int(arguments[1]), byteCount > 0 else {
                printUsageAndExit()
            }
            try await benchmarkMarkdown(byteCount: byteCount)
        default:
            printUsageAndExit()
        }
    }

    private static func printEnvironment() {
        let processInfo = ProcessInfo.processInfo
        print("hardware_model,\(sysctlString("hw.model"))")
        print("processor_count,\(processInfo.processorCount)")
        print("physical_memory_bytes,\(processInfo.physicalMemory)")
        print("macos,\(processInfo.operatingSystemVersionString.replacingOccurrences(of: ",", with: ";"))")
        print("swift,6")
    }

    @MainActor
    private static func benchmarkEditor(byteCount: Int) throws {
        let source = BenchmarkCorpus.editor(byteCount: byteCount)
        var document: TextDocument!

        let openMilliseconds = try measureMilliseconds {
            let openedDocument = TextDocument()
            try openedDocument.read(from: source, ofType: TildeDocumentType.plainText)
            document = openedDocument
        }
        let openResidentMemory = residentMemoryBytes()

        let (lineCount, longestLine) = lineStatistics(in: document.textStorage.mutableString)
        let editingLine = max(1, lineCount * 3 / 4)
        let lineOffset = document.lineIndex.offset(forLine: editingLine) ?? 0
        let editOffset = min(lineOffset + 3, max(0, document.textStorage.length - 1))
        var typingSamples: [Double] = []
        typingSamples.reserveCapacity(250)
        for iteration in 0..<250 {
            let replacement = iteration.isMultiple(of: 2) ? "x" : "y"
            typingSamples.append(measureMilliseconds {
                document.textStorage.replaceCharacters(
                    in: NSRange(location: editOffset, length: 1),
                    with: replacement
                )
                document.noteTextChange(TextEdit(
                    range: NSRange(location: editOffset, length: 1),
                    replacement: replacement,
                    removedUTF8Length: 1
                ))
            })
        }

        var cursorSamples: [Double] = []
        cursorSamples.reserveCapacity(250)
        for iteration in 0..<250 {
            let offset = document.textStorage.length * iteration / 249
            cursorSamples.append(measureMilliseconds {
                _ = document.lineIndex.position(
                    forUTF16Offset: offset,
                    in: document.textStorage.mutableString
                )
            })
        }

        let findMilliseconds = measureMilliseconds {
            _ = document.textStorage.mutableString.range(
                of: BenchmarkCorpus.endMarker,
                options: .backwards
            )
        }

        var encodedByteCount = 0
        let saveMilliseconds = try measureMilliseconds {
            encodedByteCount = try document.data(ofType: TildeDocumentType.plainText).count
        }

        let values: [String] = [
            String(byteCount),
            "utf8",
            String(lineCount),
            String(longestLine),
            decimal(openMilliseconds),
            decimal(percentile(typingSamples, fraction: 0.50)),
            decimal(percentile(typingSamples, fraction: 0.95)),
            decimal(percentile(cursorSamples, fraction: 0.95)),
            decimal(findMilliseconds),
            decimal(saveMilliseconds),
            decimal(megabytes(openResidentMemory)),
            decimal(megabytes(peakResidentMemoryBytes())),
            String(encodedByteCount),
        ]
        print(values.joined(separator: ","))
    }

    @MainActor
    private static func benchmarkMarkdown(byteCount: Int) async throws {
        let data = BenchmarkCorpus.markdown(byteCount: byteCount)
        guard let source = String(data: data, encoding: .utf8) else {
            throw BenchmarkError.invalidCorpus
        }
        var policy = MarkdownPolicy.default
        policy.maximumSourceBytes = max(policy.maximumSourceBytes, byteCount + 1)
        policy.maximumOutputBytes = max(policy.maximumOutputBytes, byteCount * 8)

        let snapshot = DocumentSnapshot(
            text: source,
            revision: 1,
            encoding: .newDocumentUTF8,
            lineEnding: .lf,
            documentType: TildeDocumentType.markdown,
            fileURL: nil,
            utf8ByteCount: byteCount
        )
        let previewModel = MarkdownPreviewModel()
        let appMilliseconds = try await measureMilliseconds {
            await previewModel.render(snapshot: snapshot, policy: policy)
            if let errorMessage = previewModel.errorMessage {
                throw BenchmarkError.renderFailed(errorMessage)
            }
        }

        var quickLookOutputBytes = 0
        let quickLookMilliseconds = try measureMilliseconds {
            quickLookOutputBytes = try QuickLookHTMLRenderer.render(
                markdown: source,
                policy: policy
            ).data.count
        }

        let values: [String] = [
            String(byteCount),
            decimal(appMilliseconds),
            decimal(quickLookMilliseconds),
            String(quickLookOutputBytes),
            decimal(megabytes(peakResidentMemoryBytes())),
        ]
        print(values.joined(separator: ","))
    }

    private static func lineStatistics(in text: NSString) -> (count: Int, longest: Int) {
        var count = 1
        var longest = 0
        var current = 0
        for offset in 0..<text.length {
            if text.character(at: offset) == 0x0A {
                count += 1
                longest = max(longest, current)
                current = 0
            } else {
                current += 1
            }
        }
        return (count, max(longest, current))
    }

    private static func measureMilliseconds<T>(_ body: () throws -> T) rethrows -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        _ = try body()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        return Double(elapsed) / 1_000_000
    }

    @MainActor
    private static func measureMilliseconds(
        _ body: @MainActor () async throws -> Void
    ) async rethrows -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        try await body()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        return Double(elapsed) / 1_000_000
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * fraction)) - 1))
        return sorted[index]
    }

    private static func residentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    rebound,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private static func peakResidentMemoryBytes() -> UInt64 {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return UInt64(max(0, usage.ru_maxrss))
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return "unknown" }
        let bytes = value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func megabytes(_ bytes: UInt64) -> Double {
        Double(bytes) / 1_048_576
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func printUsageAndExit() -> Never {
        FileHandle.standardError.write(Data(
            "Usage: TildeBenchmark environment | editor <bytes> | markdown <bytes>\n".utf8
        ))
        exit(2)
    }
}

private enum BenchmarkCorpus {
    static let endMarker = "TILDE-BENCHMARK-END"

    static func editor(byteCount: Int) -> Data {
        let longLine = "long=" + String(repeating: "x", count: min(4_096, max(0, byteCount / 3))) + "\n"
        let preamble = """
        Tilde benchmark corpus
        中文文本、Emoji 🐈、组合字符 é
        # Markdown heading
        ```swift
        print("hello")
        ```
        \(longLine)
        """
        let repeated = "2026-08-07T16:00:00+08:00 [INFO] request=123 status=200 plain text line\n"
        return exactUTF8Data(byteCount: byteCount, preamble: preamble, repeated: repeated)
    }

    static func markdown(byteCount: Int) -> Data {
        let preamble = """
        # Tilde Markdown Benchmark

        中文段落与 Emoji 🐈，包含 **粗体**、*强调* 和 [链接](https://example.com)。

        | Name | Value |
        | --- | ---: |
        | Tilde | 1 |

        """
        let repeated = "## Section\n\n- [x] item\n- another item with `code`\n\n```swift\nlet value = 42\n```\n\n"
        return exactUTF8Data(byteCount: byteCount, preamble: preamble, repeated: repeated)
    }

    private static func exactUTF8Data(byteCount: Int, preamble: String, repeated: String) -> Data {
        var result = Data()
        let preambleData = Data(preamble.utf8)
        if preambleData.count <= byteCount {
            result.append(preambleData)
        }

        let repeatedData = Data(repeated.utf8)
        while result.count + repeatedData.count + endMarker.utf8.count <= byteCount {
            result.append(repeatedData)
        }

        let markerData = Data(endMarker.utf8)
        let fillerCount = max(0, byteCount - result.count - markerData.count)
        result.append(Data(repeating: Character("z").asciiValue!, count: fillerCount))
        if result.count + markerData.count <= byteCount {
            result.append(markerData)
        }
        if result.count < byteCount {
            result.append(Data(repeating: Character("z").asciiValue!, count: byteCount - result.count))
        }
        return result
    }
}

private enum BenchmarkError: LocalizedError {
    case invalidCorpus
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCorpus:
            "Benchmark corpus was not valid UTF-8."
        case let .renderFailed(message):
            "Markdown benchmark failed: \(message)"
        }
    }
}
