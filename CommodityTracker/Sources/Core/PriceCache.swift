import Foundation

public struct CachedSeries: Equatable, Sendable {
    /// Oldest first, one per date.
    public let observations: [PriceObservation]
    public let savedAt: Date

    public init(observations: [PriceObservation], savedAt: Date) {
        self.observations = observations
        self.savedAt = savedAt
    }
}

public protocol PriceCache: Sendable {
    func load(seriesID: String) async throws -> CachedSeries?

    /// Merges into what's stored, so saving one latest price keeps the saved history.
    /// A new value for an existing date replaces the old one.
    func save(_ observations: [PriceObservation], seriesID: String, at date: Date) async throws
}
