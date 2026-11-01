import Core
import Foundation

public actor InMemoryPriceCache: PriceCache {
    private var series: [String: (observations: [Date: PriceObservation], savedAt: Date)] = [:]

    public init() {}

    public func load(seriesID: String) -> CachedSeries? {
        guard let stored = series[seriesID] else { return nil }
        return CachedSeries(
            observations: stored.observations.values.sorted { $0.date < $1.date },
            savedAt: stored.savedAt
        )
    }

    public func save(_ observations: [PriceObservation], seriesID: String, at date: Date) {
        var merged = series[seriesID]?.observations ?? [:]
        for observation in observations {
            merged[observation.date] = observation
        }
        series[seriesID] = (merged, date)
    }
}
