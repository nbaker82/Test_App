import Core
import Foundation

public struct Sourced<Value: Sendable>: Sendable {
    public enum Source: Equatable, Sendable {
        case live
        case cached(savedAt: Date)
    }

    public let value: Value
    public let source: Source

    public init(value: Value, source: Source) {
        self.value = value
        self.source = source
    }
}

extension Sourced: Equatable where Value: Equatable {}

public struct CachingPriceRepository: Sendable {
    private let service: any PriceService
    private let cache: any PriceCache
    private let now: @Sendable () -> Date

    public init(
        service: any PriceService,
        cache: any PriceCache,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.cache = cache
        self.now = now
    }

    public func latest(for commodity: Commodity) async throws -> Sourced<PriceObservation> {
        let seriesID = commodity.seriesID
        do {
            let observation = try await service.latest(seriesID: seriesID)
            await save([observation], seriesID: seriesID)
            return Sourced(value: observation, source: .live)
        } catch let error as PriceServiceError where error.allowsStaleFallback {
            guard let cached = await loadCached(seriesID: seriesID),
                  let newest = cached.observations.last
            else { throw error }
            return Sourced(value: newest, source: .cached(savedAt: cached.savedAt))
        }
    }

    public func history(for commodity: Commodity, range: TimeRange) async throws -> Sourced<[PriceObservation]> {
        let seriesID = commodity.seriesID
        let start = range.start(endingAt: now())
        do {
            let observations = try await service.observations(seriesID: seriesID, start: start)
            await save(observations, seriesID: seriesID)
            return Sourced(value: observations, source: .live)
        } catch let error as PriceServiceError where error.allowsStaleFallback {
            guard let cached = await loadCached(seriesID: seriesID) else { throw error }
            let inRange = cached.observations.filter { observation in
                start.map { observation.date >= $0 } ?? true
            }
            guard !inRange.isEmpty else { throw error }
            return Sourced(value: inRange, source: .cached(savedAt: cached.savedAt))
        }
    }

    /// A failed write shouldn't cost the caller a price the network already delivered.
    private func save(_ observations: [PriceObservation], seriesID: String) async {
        try? await cache.save(observations, seriesID: seriesID, at: now())
    }

    /// A failed read falls through to the original network error, which is the one worth showing.
    private func loadCached(seriesID: String) async -> CachedSeries? {
        (try? await cache.load(seriesID: seriesID)) ?? nil
    }
}
