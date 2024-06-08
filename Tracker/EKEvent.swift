import EventKit

extension EKEvent: Identifiable {
    public var id: String {
        eventIdentifier
    }
}
