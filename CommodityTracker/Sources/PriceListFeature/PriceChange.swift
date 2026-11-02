import Core
import Foundation

/// How much a price moved from the first to the last observation in a range.
struct PriceChange: Equatable, Sendable {
    let fraction: Double

    var isUp: Bool { fraction >= 0 }

    init?(observations: [PriceObservation]) {
        guard observations.count > 1,
              let first = observations.first?.value,
              let last = observations.last?.value,
              first != 0
        else { return nil }
        fraction = NSDecimalNumber(decimal: (last - first) / first).doubleValue
    }
}
