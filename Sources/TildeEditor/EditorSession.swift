import Foundation
import Observation
import SwiftUI
import TildeCore

public enum DocumentViewMode: String, CaseIterable, Sendable {
    case edit
    case preview
    case split
}

@MainActor
@Observable
public final class EditorSession {
    public var selection = NSRange(location: 0, length: 0)
    public var selectedRanges: [NSRange] = [NSRange(location: 0, length: 0)]
    public var scrollPosition = CGPoint.zero
    public var previewScrollPosition = ScrollPosition()
    public var mode: DocumentViewMode = .edit
    public var textPosition = TextPosition(line: 1, column: 1)

    private var backLocations: [NSRange] = []
    private var forwardLocations: [NSRange] = []

    private let persistenceKey: String?
    private let legacyPersistenceKey: String?
    private var pendingPersistence: Task<Void, Never>?

    public init(documentURL: URL? = nil, defaults: UserDefaults = .standard) {
        persistenceKey = documentURL.map(Self.persistenceKey(for:))
        legacyPersistenceKey = documentURL.map {
            "document-session:\($0.standardizedFileURL.path)"
        }
        guard let persistenceKey else { return }
        let values = defaults.dictionary(forKey: persistenceKey)
            ?? legacyPersistenceKey.flatMap { defaults.dictionary(forKey: $0) }
        guard let values else { return }

        if persistenceKey != legacyPersistenceKey, let legacyPersistenceKey {
            defaults.removeObject(forKey: legacyPersistenceKey)
        }

        if let location = values["selectionLocation"] as? Int,
           let length = values["selectionLength"] as? Int {
            selection = NSRange(location: location, length: length)
        }
        if let x = values["scrollX"] as? Double, let y = values["scrollY"] as? Double {
            scrollPosition = CGPoint(x: x, y: y)
        }
        if let rawMode = values["mode"] as? String,
           let restoredMode = DocumentViewMode(rawValue: rawMode) {
            mode = restoredMode
        }
        selectedRanges = [selection]
    }

    public func schedulePersist(defaults: UserDefaults = .standard) {
        pendingPersistence?.cancel()
        pendingPersistence = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.persist(defaults: defaults)
        }
    }

    public func persist(defaults: UserDefaults = .standard) {
        pendingPersistence?.cancel()
        pendingPersistence = nil
        guard let persistenceKey else { return }
        defaults.set([
            "selectionLocation": selection.location,
            "selectionLength": selection.length,
            "scrollX": Double(scrollPosition.x),
            "scrollY": Double(scrollPosition.y),
            "mode": mode.rawValue,
        ], forKey: persistenceKey)
        if persistenceKey != legacyPersistenceKey, let legacyPersistenceKey {
            defaults.removeObject(forKey: legacyPersistenceKey)
        }
    }

    public var canNavigateBack: Bool { !backLocations.isEmpty }
    public var canNavigateForward: Bool { !forwardLocations.isEmpty }

    public func recordNavigationLocation(_ range: NSRange, beforeNavigatingTo destination: NSRange) {
        guard range != destination else { return }
        if backLocations.last != range {
            backLocations.append(range)
        }
        if backLocations.count > 100 { backLocations.removeFirst() }
        forwardLocations.removeAll()
    }

    public func navigateBack(from current: NSRange, maximumLength: Int) -> NSRange? {
        guard let destination = backLocations.popLast() else { return nil }
        let safeDestination = Self.clamped(destination, maximumLength: maximumLength)
        forwardLocations.append(Self.clamped(current, maximumLength: maximumLength))
        return safeDestination
    }

    public func navigateForward(from current: NSRange, maximumLength: Int) -> NSRange? {
        guard let destination = forwardLocations.popLast() else { return nil }
        let safeDestination = Self.clamped(destination, maximumLength: maximumLength)
        backLocations.append(Self.clamped(current, maximumLength: maximumLength))
        return safeDestination
    }

    public func clearNavigationHistory() {
        backLocations.removeAll()
        forwardLocations.removeAll()
    }

    private static func clamped(_ range: NSRange, maximumLength: Int) -> NSRange {
        let length = max(0, maximumLength)
        let location = min(max(0, range.location), length)
        let safeLength = min(max(0, range.length), length - location)
        return NSRange(location: location, length: safeLength)
    }

    private static func persistenceKey(for url: URL) -> String {
        if let identifier = try? url.resourceValues(
            forKeys: [.fileResourceIdentifierKey]
        ).fileResourceIdentifier {
            return "document-session:resource:\(String(describing: identifier))"
        }
        return "document-session:\(url.standardizedFileURL.path)"
    }
}
