import Foundation

public struct PriceObservation: Hashable, Sendable {
    /// Midnight UTC on the observation's date. Monthly series use the first of the month.
    public let date: Date
    public let value: Decimal

    public init(date: Date, value: Decimal) {
        self.date = date
        self.value = value
    }
}
