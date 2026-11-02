import Core

/// What screens depend on, so they can run against sample data in previews and tests.
public protocol PriceRepository: Sendable {
    func latest(for commodity: Commodity) async throws -> Sourced<PriceObservation>
    func history(for commodity: Commodity, range: TimeRange) async throws -> Sourced<[PriceObservation]>
}
