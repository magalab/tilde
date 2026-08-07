public enum ExternalChangeState: Equatable, Sendable {
    case unchanged
    case changedOnDisk
    case deletedOnDisk
    case becameReadOnly
    case conflict
}

