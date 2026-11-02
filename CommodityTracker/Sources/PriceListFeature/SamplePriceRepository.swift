#if DEBUG
import Core
import Foundation
import Repository

/// Made-up prices for previews and for running the app without an API key.
/// Soybeans comes back as cached so the saved-price label is visible too.
public struct SamplePriceRepository: PriceRepository {
    private static let sampleYears = 10

    private let failure: PriceServiceError?

    public init(failure: PriceServiceError? = nil) {
        self.failure = failure
    }

    public func latest(for commodity: Commodity) async throws -> Sourced<PriceObservation> {
        if let failure {
            throw failure
        }
        let observation = PriceObservation(date: Self.latestDate(for: commodity), value: Self.basePrice(for: commodity))
        return Sourced(value: observation, source: Self.source(for: commodity))
    }

    public func history(for commodity: Commodity, range: TimeRange) async throws -> Sourced<[PriceObservation]> {
        if let failure {
            throw failure
        }
        return Sourced(value: Self.series(for: commodity, range: range), source: Self.source(for: commodity))
    }

    private static func source<Value>(for commodity: Commodity) -> Sourced<Value>.Source {
        commodity == .soybeans ? .cached(savedAt: Date.now.addingTimeInterval(-2 * 60 * 60)) : .live
    }

    /// A smooth repeating wave that ends exactly on the base price.
    private static func series(for commodity: Commodity, range: TimeRange) -> [PriceObservation] {
        let calendar = Calendar.utc
        let latest = latestDate(for: commodity)
        let base = NSDecimalNumber(decimal: basePrice(for: commodity)).doubleValue
        let component: Calendar.Component = commodity.frequency == .daily ? .day : .month
        let count = commodity.frequency == .daily ? sampleYears * 365 : sampleYears * 12
        let start = range.start(endingAt: latest)

        return (0..<count).reversed().compactMap { stepsBack in
            guard let date = calendar.date(byAdding: component, value: -stepsBack, to: latest),
                  start.map({ date >= $0 }) ?? true
            else { return nil }
            // Measured in months so daily and monthly series have the same shape.
            let months = Double(stepsBack) / (commodity.frequency == .daily ? 30 : 1)
            let wave = sin(months * 0.5) * 0.12 + sin(months * 1.7) * 0.03
            let value = Decimal(((base * (1 + wave)) * 100).rounded() / 100)
            return PriceObservation(date: date, value: value)
        }
    }

    private static func latestDate(for commodity: Commodity) -> Date {
        let components = commodity.frequency == .daily
            ? DateComponents(year: 2026, month: 10, day: 27)
            : DateComponents(year: 2026, month: 9, day: 1)
        return Calendar.utc.date(from: components) ?? .now
    }

    private static func basePrice(for commodity: Commodity) -> Decimal {
        switch commodity {
        case .wti: 80
        case .corn: 200
        case .wheat: 250
        default: 400
        }
    }
}
#endif
