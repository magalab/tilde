import Foundation
import Observation
import SwiftUI
import TildeCore

public enum DocumentViewMode: String, CaseIterable, Sendable {
    case edit
    case preview
}

@MainActor
@Observable
public final class EditorSession {
    public var selection = NSRange(location: 0, length: 0)
    public var scrollPosition = CGPoint.zero
    public var previewScrollPosition = ScrollPosition()
    public var mode: DocumentViewMode = .edit
    public var textPosition = TextPosition(line: 1, column: 1)

    public init() {}
}
